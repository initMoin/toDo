import { createClient } from 'npm:@supabase/supabase-js@2'
import { authorizeWebhookRequest } from './webhook_auth.ts'

interface SyncPushEventRecord {
  id: string
  user_id: string
  source_table: string
  record_id: string | null
  mutation_type: 'INSERT' | 'UPDATE' | 'DELETE'
  created_at: string
}

interface DatabaseWebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE'
  table: string
  schema: 'public'
  record: SyncPushEventRecord | null
  old_record: SyncPushEventRecord | null
}

interface DeviceTokenRecord {
  id: string
  installation_id: string | null
  token: string
  environment: string | null
  app_bundle_id: string | null
  last_seen_at: string
}

interface LiveActivityTokenRecord {
  id: string
  installation_id: string | null
  token: string
  token_type: 'push_to_start' | 'update'
  activity_id: string | null
  todo_id: string | null
  todo_identifier: string | null
  environment: string | null
  app_bundle_id: string | null
  last_seen_at: string
}

interface ToDoRecord {
  id: string
  user_id: string
  task: string | null
  due_at: string | null
  reminder_intent: string | null
  lifecycle_state: string | null
  updated_at: string | null
  created_at: string | null
}

interface APNsCredentials {
  teamID: string
  keyID: string
  privateKey: string
}

interface SendResult {
  tokenID: string
  sent: boolean
  shouldDeactivate: boolean
}

interface CachedAPNsAuthToken {
  token: string
  issuedAt: number
  expiresAt: number
}

interface APNsProviderAuthTokenRecord {
  cache_key: string
  token: string
  issued_at: string
  expires_at: string
}

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  { auth: { persistSession: false } },
)
const debugLogsEnabled = (Deno.env.get('TODO_SYNC_PUSH_DEBUG_LOGS') ?? '').toLowerCase() === 'true'
const apnsAuthTokenCache = new Map<string, CachedAPNsAuthToken>()
const apnsAuthTokenPromises = new Map<string, Promise<CachedAPNsAuthToken>>()
const apnsAuthTokenTTLSeconds = 50 * 60

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405)
  }

  const authFailure = authorizeWebhookRequest(req, [
    Deno.env.get('TODO_SYNC_PUSH_WEBHOOK_SECRET'),
    Deno.env.get('TODO_SYNC_PUSH_WEBHOOK_SECRET_ROTATION'),
  ])
  if (authFailure) {
    console.error(authFailure.message)
    return json({ error: authFailure.responseMessage }, authFailure.status)
  }

  const payload = await req.json() as DatabaseWebhookPayload
  const event = payload.record

  if (payload.type !== 'INSERT' || payload.table !== 'sync_push_events' || !event) {
    return json({ skipped: true, reason: 'Not a sync push event insert' })
  }

  const syncSummary = await sendBackgroundSyncPushes(event)
  const liveActivitySummary = await handleLiveActivityPushes(event)

  const { error: processedError } = await supabase
    .from('sync_push_events')
    .update({ processed_at: new Date().toISOString() })
    .eq('id', event.id)

  if (processedError) {
    console.error('Failed to mark sync push event processed', processedError)
  }
  await cleanupOldSyncPushEvents()

  return json({ sync: syncSummary, liveActivity: liveActivitySummary })
})

async function sendBackgroundSyncPushes(event: SyncPushEventRecord) {
  const { data: devices, error } = await supabase
    .from('device_tokens')
    .select('id, installation_id, token, environment, app_bundle_id, last_seen_at')
    .eq('user_id', event.user_id)
    .eq('platform', 'ios')
    .eq('push_provider', 'apns')
    .eq('is_active', true)
    .order('last_seen_at', { ascending: false })

  if (error) {
    console.error('Failed to load device tokens', error)
    return { sent: 0, failed: 1, inactive: 0, error: error.message }
  }

  const activeDevices = dedupeDeviceTokens((devices ?? []) as DeviceTokenRecord[])
  if (activeDevices.length === 0) {
    return { sent: 0, failed: 0, inactive: 0 }
  }

  debugLog('Preparing APNs sync push batch', {
    deviceCount: activeDevices.length,
    environments: [...new Set(activeDevices.map((device) => normalizedEnvironment(device.environment)))],
  })
  const results = await Promise.allSettled(
    activeDevices.map((device) => sendSyncPush(device, event)),
  )

  const inactiveDeviceIDs: string[] = []
  let sent = 0
  let failed = 0

  for (const result of results) {
    if (result.status === 'fulfilled') {
      if (result.value.sent) sent += 1
      if (result.value.shouldDeactivate) inactiveDeviceIDs.push(result.value.tokenID)
      if (!result.value.sent) failed += 1
    } else {
      failed += 1
      console.error('APNs sync push failed', result.reason)
    }
  }

  if (inactiveDeviceIDs.length > 0) {
    const { error: deactivateError } = await supabase
      .from('device_tokens')
      .update({ is_active: false, updated_at: new Date().toISOString() })
      .in('id', inactiveDeviceIDs)

    if (deactivateError) {
      console.error('Failed to deactivate invalid device tokens', deactivateError)
    }
  }

  return { sent, failed, inactive: inactiveDeviceIDs.length }
}

async function handleLiveActivityPushes(event: SyncPushEventRecord) {
  if (event.source_table !== 'todos' || !event.record_id) {
    return { sent: 0, failed: 0, inactive: 0, skipped: true }
  }

  const todo = await loadToDo(event)
  const eligible = todo ? isLiveActivityEligible(todo) : false
  const tokens = await loadLiveActivityTokens(event)
  const updateTokens = dedupeLiveActivityTokens(tokens.filter((token) => token.token_type === 'update' && token.todo_id === event.record_id))
  const pushToStartTokens = dedupeLiveActivityTokens(tokens.filter((token) => token.token_type === 'push_to_start'))

  console.log('Live Activity push evaluation', {
    eventID: event.id,
    recordID: event.record_id,
    mutationType: event.mutation_type,
    todoFound: Boolean(todo),
    eligible,
    reminderIntent: todo?.reminder_intent ?? null,
    lifecycleState: todo?.lifecycle_state ?? null,
    dueAt: todo?.due_at ?? null,
    activeUpdateTokens: updateTokens.length,
    activePushToStartTokens: pushToStartTokens.length,
  })

  if (!eligible) {
    const endResults = await settleSendResults(updateTokens.map((token) => sendLiveActivityPush(token, 'end', todo)))
    await deactivateLiveActivityTokens(endResults.inactiveIDs.concat(updateTokens.map((token) => token.id)))
    return { sent: endResults.sent, failed: endResults.failed, inactive: endResults.inactiveIDs.length, ended: updateTokens.length }
  }

  const targetTokens = updateTokens.length > 0 ? updateTokens : pushToStartTokens
  if (targetTokens.length === 0) {
    return { sent: 0, failed: 0, inactive: 0, skipped: true, reason: 'No Live Activity tokens' }
  }

  const eventType = updateTokens.length > 0 ? 'update' : 'start'
  const results = await settleSendResults(targetTokens.map((token) => sendLiveActivityPush(token, eventType, todo)))
  await deactivateLiveActivityTokens(results.inactiveIDs)

  return {
    sent: results.sent,
    failed: results.failed,
    inactive: results.inactiveIDs.length,
    eventType,
  }
}

async function loadToDo(event: SyncPushEventRecord): Promise<ToDoRecord | null> {
  if (event.mutation_type === 'DELETE' || !event.record_id) return null

  const { data, error } = await supabase
    .from('todos')
    .select('id, user_id, task, due_at, reminder_intent, lifecycle_state, updated_at, created_at')
    .eq('id', event.record_id)
    .eq('user_id', event.user_id)
    .maybeSingle()

  if (error) {
    console.error('Failed to load todo for Live Activity push', error)
    return null
  }

  return data as ToDoRecord | null
}

async function loadLiveActivityTokens(event: SyncPushEventRecord): Promise<LiveActivityTokenRecord[]> {
  const { data, error } = await supabase
    .from('live_activity_tokens')
    .select('id, installation_id, token, token_type, activity_id, todo_id, todo_identifier, environment, app_bundle_id, last_seen_at')
    .eq('user_id', event.user_id)
    .eq('platform', 'ios')
    .eq('is_active', true)
    .order('last_seen_at', { ascending: false })

  if (error) {
    console.error('Failed to load Live Activity tokens', error)
    return []
  }

  return (data ?? []) as LiveActivityTokenRecord[]
}

function dedupeDeviceTokens(tokens: DeviceTokenRecord[]): DeviceTokenRecord[] {
  const dedupedTokens = new Map<string, DeviceTokenRecord>()

  for (const token of tokens) {
    const key = token.installation_id || token.token
    if (!dedupedTokens.has(key)) {
      dedupedTokens.set(key, token)
    }
  }

  return [...dedupedTokens.values()]
}

function dedupeLiveActivityTokens(tokens: LiveActivityTokenRecord[]): LiveActivityTokenRecord[] {
  const dedupedTokens = new Map<string, LiveActivityTokenRecord>()

  for (const token of tokens) {
    const key = [
      token.installation_id || token.token,
      token.token_type,
      token.activity_id || token.todo_id || token.todo_identifier || 'global',
    ].join(':')

    if (!dedupedTokens.has(key)) {
      dedupedTokens.set(key, token)
    }
  }

  return [...dedupedTokens.values()]
}

function isLiveActivityEligible(todo: ToDoRecord): boolean {
  if (todo.lifecycle_state !== 'active') return false
  if (todo.reminder_intent !== 'timeSensitive') return false
  if (!todo.due_at) return false
  return new Date(todo.due_at).getTime() > Date.now()
}

async function settleSendResults(promises: Promise<SendResult>[]) {
  const results = await Promise.allSettled(promises)
  const inactiveIDs: string[] = []
  let sent = 0
  let failed = 0

  for (const result of results) {
    if (result.status === 'fulfilled') {
      if (result.value.sent) sent += 1
      if (result.value.shouldDeactivate) inactiveIDs.push(result.value.tokenID)
      if (!result.value.sent) failed += 1
    } else {
      failed += 1
      console.error('APNs Live Activity push failed', result.reason)
    }
  }

  return { sent, failed, inactiveIDs }
}

async function deactivateLiveActivityTokens(tokenIDs: string[]) {
  const uniqueIDs = [...new Set(tokenIDs)]
  if (uniqueIDs.length === 0) return

  const { error } = await supabase
    .from('live_activity_tokens')
    .update({ is_active: false, updated_at: new Date().toISOString() })
    .in('id', uniqueIDs)

  if (error) {
    console.error('Failed to deactivate Live Activity tokens', error)
  }
}

async function sendSyncPush(
  device: DeviceTokenRecord,
  event: SyncPushEventRecord,
): Promise<SendResult> {
  const bundleID = device.app_bundle_id || Deno.env.get('APNS_BUNDLE_ID')
  if (!bundleID) {
    throw new Error('Missing APNS_BUNDLE_ID and device app_bundle_id')
  }

  const environment = normalizedEnvironment(device.environment)
  const host = apnsHost(environment)
  const credentials = apnsCredentials(environment)
  const authToken = await createAPNsAuthToken(credentials)

  const response = await fetch(`${host}/3/device/${device.token}`, {
    method: 'POST',
    headers: {
      authorization: `bearer ${authToken}`,
      'apns-topic': bundleID,
      'apns-push-type': 'background',
      'apns-priority': '5',
      'apns-expiration': '0',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      aps: { 'content-available': 1 },
      todoSync: 'refresh',
      syncEvent: event.mutation_type.toLowerCase(),
      sourceTable: event.source_table,
      recordID: event.record_id,
    }),
  })

  return handleAPNsResponse(response, device.id, 'sync', environment, credentials)
}

async function sendLiveActivityPush(
  token: LiveActivityTokenRecord,
  eventType: 'start' | 'update' | 'end',
  todo: ToDoRecord | null,
): Promise<SendResult> {
  const bundleID = token.app_bundle_id || Deno.env.get('APNS_BUNDLE_ID')
  if (!bundleID) {
    throw new Error('Missing APNS_BUNDLE_ID and Live Activity token app_bundle_id')
  }

  const environment = normalizedEnvironment(token.environment)
  const credentials = apnsCredentials(environment)
  const authToken = await createAPNsAuthToken(credentials)
  const body = liveActivityPayload(eventType, token, todo)

  const response = await fetch(`${apnsHost(environment)}/3/device/${token.token}`, {
    method: 'POST',
    headers: {
      authorization: `bearer ${authToken}`,
      'apns-topic': `${bundleID}.push-type.liveactivity`,
      'apns-push-type': 'liveactivity',
      'apns-priority': eventType === 'end' ? '5' : '10',
      'apns-expiration': '0',
      'content-type': 'application/json',
    },
    body: JSON.stringify(body),
  })

  return handleAPNsResponse(response, token.id, `liveactivity:${eventType}`, environment, credentials)
}

function liveActivityPayload(
  eventType: 'start' | 'update' | 'end',
  token: LiveActivityTokenRecord,
  todo: ToDoRecord | null,
) {
  const now = new Date()
  const nowUnix = unixSeconds(now)
  const fallbackTitle = 'toDo'
  const title = todo?.task?.trim() || fallbackTitle
  const dueDate = todo?.due_at ? new Date(todo.due_at) : null
  const contentState = {
    title,
    dueDate: dueDate ? appleReferenceSeconds(dueDate) : null,
    isOverdue: dueDate ? dueDate.getTime() < now.getTime() : false,
    isTimeSensitive: todo?.reminder_intent === 'timeSensitive',
    updatedAt: appleReferenceSeconds(todo?.updated_at ? new Date(todo.updated_at) : now),
  }

  if (eventType === 'start') {
    const createdAt = todo?.created_at ? new Date(todo.created_at) : now
    return {
      aps: {
        timestamp: nowUnix,
        event: 'start',
        'attributes-type': 'ToDoLiveActivityAttributes',
        attributes: {
          toDoIdentifier: todo?.id ?? token.todo_identifier ?? token.id,
          toDoLocalIdentifier: null,
          toDoCloudIdentifier: todo?.id ?? token.todo_id,
          createdAt: appleReferenceSeconds(createdAt),
        },
        'content-state': contentState,
        'stale-date': dueDate ? unixSeconds(dueDate) : nowUnix + 60,
      },
    }
  }

  if (eventType === 'end') {
    return {
      aps: {
        timestamp: nowUnix,
        event: 'end',
        'content-state': contentState,
        'dismissal-date': nowUnix,
      },
    }
  }

  return {
    aps: {
      timestamp: nowUnix,
      event: 'update',
      'content-state': contentState,
      'stale-date': dueDate ? unixSeconds(dueDate) : nowUnix + 60,
    },
  }
}

async function handleAPNsResponse(
  response: Response,
  tokenID: string,
  kind: string,
  environment: string,
  credentials: APNsCredentials,
): Promise<SendResult> {
  if (response.ok) {
    console.log(`APNs accepted ${kind} push`, {
      tokenID,
      environment,
      apnsID: response.headers.get('apns-id'),
      apnsUniqueID: response.headers.get('apns-unique-id'),
      keyID: maskSecret(credentials.keyID),
      teamID: maskSecret(credentials.teamID),
    })
    return { tokenID, sent: true, shouldDeactivate: false }
  }

  const responseText = await response.text()
  let reason = ''
  try {
    reason = JSON.parse(responseText).reason ?? ''
  } catch {
    reason = responseText
  }

  console.error(`APNs rejected ${kind} push`, {
    status: response.status,
    reason,
    tokenID,
    environment,
    apnsID: response.headers.get('apns-id'),
    apnsUniqueID: response.headers.get('apns-unique-id'),
    keyID: maskSecret(credentials.keyID),
    teamID: maskSecret(credentials.teamID),
  })

  return {
    tokenID,
    sent: false,
    shouldDeactivate: response.status === 410
      || reason === 'BadDeviceToken'
      || reason === 'Unregistered'
      || reason === 'DeviceTokenNotForTopic',
  }
}

async function createAPNsAuthToken(credentials: APNsCredentials): Promise<string> {
  const cacheKey = `${credentials.teamID}:${credentials.keyID}`
  const now = Math.floor(Date.now() / 1000)
  const cachedToken = apnsAuthTokenCache.get(cacheKey)
  if (cachedToken && cachedToken.expiresAt > now + 60) {
    return cachedToken.token
  }

  const persistedToken = await loadPersistedAPNsAuthToken(cacheKey, now)
  if (persistedToken) {
    return persistedToken.token
  }

  await sleep(75 + Math.floor(Math.random() * 175))
  const delayedPersistedToken = await loadPersistedAPNsAuthToken(cacheKey, Math.floor(Date.now() / 1000))
  if (delayedPersistedToken) {
    return delayedPersistedToken.token
  }

  const pendingToken = apnsAuthTokenPromises.get(cacheKey)
  if (pendingToken) {
    return (await pendingToken).token
  }

  const tokenPromise = createAndCacheAPNsAuthToken(credentials, cacheKey, now)
  apnsAuthTokenPromises.set(cacheKey, tokenPromise)

  try {
    return (await tokenPromise).token
  } finally {
    apnsAuthTokenPromises.delete(cacheKey)
  }
}

async function loadPersistedAPNsAuthToken(
  cacheKey: string,
  nowUnixSeconds: number,
): Promise<CachedAPNsAuthToken | null> {
  const minimumExpiry = new Date((nowUnixSeconds + 60) * 1000).toISOString()
  const { data, error } = await supabase
    .from('apns_provider_auth_tokens')
    .select('cache_key, token, issued_at, expires_at')
    .eq('cache_key', cacheKey)
    .gt('expires_at', minimumExpiry)
    .maybeSingle()

  if (error) {
    console.error('Failed to load persisted APNs provider token', error)
    return null
  }

  if (!data) return null

  const record = data as APNsProviderAuthTokenRecord
  const cachedToken = {
    token: record.token,
    issuedAt: unixSeconds(new Date(record.issued_at)),
    expiresAt: unixSeconds(new Date(record.expires_at)),
  }
  apnsAuthTokenCache.set(cacheKey, cachedToken)
  return cachedToken
}

async function createAndCacheAPNsAuthToken(
  credentials: APNsCredentials,
  cacheKey: string,
  issuedAt: number,
): Promise<CachedAPNsAuthToken> {
  const header = base64URLJSON({ alg: 'ES256', kid: credentials.keyID })
  const claims = base64URLJSON({ iss: credentials.teamID, iat: issuedAt })
  const signingInput = `${header}.${claims}`
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(credentials.privateKey),
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    cryptoKey,
    new TextEncoder().encode(signingInput),
  )

  const cachedToken = {
    token: `${signingInput}.${base64URL(new Uint8Array(signature))}`,
    issuedAt,
    expiresAt: issuedAt + apnsAuthTokenTTLSeconds,
  }
  apnsAuthTokenCache.set(cacheKey, cachedToken)
  await persistAPNsAuthToken(cacheKey, cachedToken)
  return cachedToken
}

async function persistAPNsAuthToken(cacheKey: string, cachedToken: CachedAPNsAuthToken) {
  const { error } = await supabase
    .from('apns_provider_auth_tokens')
    .upsert({
      cache_key: cacheKey,
      token: cachedToken.token,
      issued_at: new Date(cachedToken.issuedAt * 1000).toISOString(),
      expires_at: new Date(cachedToken.expiresAt * 1000).toISOString(),
      updated_at: new Date().toISOString(),
    }, { onConflict: 'cache_key' })

  if (error) {
    console.error('Failed to persist APNs provider token', error)
  }
}

function apnsCredentials(environment: string): APNsCredentials {
  const prefix = environment === 'sandbox' ? 'APNS_SANDBOX' : 'APNS_PRODUCTION'
  const teamID = envWithFallback(`${prefix}_TEAM_ID`, 'APNS_TEAM_ID')
  const keyID = envWithFallback(`${prefix}_KEY_ID`, 'APNS_KEY_ID')
  const privateKey = apnsPrivateKey(prefix)

  return { teamID, keyID, privateKey }
}

function apnsPrivateKey(prefix: string): string {
  const base64Key = Deno.env.get(`${prefix}_PRIVATE_KEY_BASE64`) ?? Deno.env.get('APNS_PRIVATE_KEY_BASE64')
  if (base64Key && base64Key.trim().length > 0) {
    return new TextDecoder().decode(base64Decode(base64Key.trim()))
  }

  const key = Deno.env.get(`${prefix}_PRIVATE_KEY`) ?? Deno.env.get('APNS_PRIVATE_KEY')
  if (!key || key.trim().length === 0) {
    throw new Error(`Missing required APNs private key for ${prefix}`)
  }

  return key.replace(/\\n/g, '\n')
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')

  const bytes = base64Decode(base64)
  const buffer = new ArrayBuffer(bytes.byteLength)
  new Uint8Array(buffer).set(bytes)
  return buffer
}

function base64Decode(value: string): Uint8Array {
  const binary = atob(value)
  const bytes = new Uint8Array(binary.length)
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index)
  }
  return bytes
}

function base64URLJSON(value: unknown): string {
  return base64URL(new TextEncoder().encode(JSON.stringify(value)))
}

function base64URL(bytes: Uint8Array): string {
  let binary = ''
  for (const byte of bytes) {
    binary += String.fromCharCode(byte)
  }

  return btoa(binary)
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name)
  if (!value || value.trim().length === 0) {
    throw new Error(`Missing required environment variable: ${name}`)
  }
  return value
}

function envWithFallback(primary: string, fallback: string): string {
  const primaryValue = Deno.env.get(primary)
  if (primaryValue && primaryValue.trim().length > 0) {
    return primaryValue
  }

  return requiredEnv(fallback)
}

function normalizedEnvironment(value: string | null): string {
  const environment = (value || Deno.env.get('APNS_ENVIRONMENT') || 'production').toLowerCase()
  return environment === 'sandbox' ? 'sandbox' : 'production'
}

function apnsHost(environment: string): string {
  return environment === 'sandbox'
    ? 'https://api.sandbox.push.apple.com'
    : 'https://api.push.apple.com'
}

function unixSeconds(date: Date): number {
  return Math.floor(date.getTime() / 1000)
}

function appleReferenceSeconds(date: Date): number {
  return date.getTime() / 1000 - 978307200
}

function sleep(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds))
}

function debugLog(message: string, metadata: Record<string, unknown>) {
  if (!debugLogsEnabled) return
  console.log(message, metadata)
}

function maskSecret(value: string | undefined): string {
  if (!value || value.length <= 4) return value ?? 'missing'
  return `${value.slice(0, 2)}…${value.slice(-2)}`
}

async function cleanupOldSyncPushEvents() {
  const retentionDays = Number(Deno.env.get('SYNC_PUSH_EVENT_RETENTION_DAYS') ?? '7')
  const safeRetentionDays = Number.isFinite(retentionDays) && retentionDays >= 1 ? retentionDays : 7
  const { error } = await supabase.rpc('delete_old_sync_push_events_batch', {
    retention: `${safeRetentionDays} days`,
    batch_limit: 1000,
  })

  if (error) {
    console.error('Failed to clean old sync push events', error)
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  })
}
