package dev.iamshift.todo.android.ui

import android.Manifest
import android.os.Build
import android.content.Context
import android.content.Intent
import android.provider.Settings as AndroidSettings
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.core.snap
import androidx.compose.animation.togetherWith
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.TextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.app.NotificationManagerCompat
import dev.iamshift.todo.android.BuildConfig
import dev.iamshift.todo.android.core.auth.AccountAuthenticationIntent
import dev.iamshift.todo.android.core.auth.AccountResolutionState
import dev.iamshift.todo.android.core.auth.AndroidUsernamePolicy
import dev.iamshift.todo.android.core.auth.AuthenticatedAccount
import dev.iamshift.todo.android.core.auth.SupabaseAuthSessionProvider
import dev.iamshift.todo.android.core.auth.SupabaseOAuthProvider
import dev.iamshift.todo.android.core.model.ToDo
import dev.iamshift.todo.android.core.model.ToDoState
import dev.iamshift.todo.android.core.settings.ToDoSettingsStore
import dev.iamshift.todo.android.core.settings.GuidedTourStore
import dev.iamshift.todo.android.core.supabase.SupabaseConfig
import dev.iamshift.todo.android.ui.theme.AppSurfaceMutedDark
import dev.iamshift.todo.android.ui.theme.AppSurfaceMutedLight
import dev.iamshift.todo.android.ui.theme.AppSurfaceDark
import dev.iamshift.todo.android.ui.theme.BrandPrimary
import dev.iamshift.todo.android.ui.theme.BrandSecondary
import dev.iamshift.todo.android.ui.theme.BrandTertiary
import dev.iamshift.todo.android.ui.theme.ToDoShapes
import dev.iamshift.todo.android.ui.theme.ToDoSpacing
import dev.iamshift.todo.android.ui.theme.ToDoTextStyles
import dev.iamshift.todo.android.ui.theme.ToDoTypography
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlinx.coroutines.launch

private enum class SettingsRoute(val title: String) {
    ACCOUNT("Account"),
    PLUS("toDō+"),
    SYNC("Sync"),
    APPEARANCE("Appearance"),
    TAGS("Tags"),
    BEHAVIOR("Behavior"),
    GUIDED_TOUR("Guided Tour"),
    NOTIFICATIONS("Notifications"),
    DATA_CONTROLS("Data Controls"),
    ARCHIVES("Archives"),
    TRASH("Trash"),
    ABOUT("About toDō")
}

@Composable
internal fun SettingsScreen(
    authSessionProvider: SupabaseAuthSessionProvider,
    settingsStore: ToDoSettingsStore,
    guidedTourStore: GuidedTourStore,
    toDos: List<ToDo>,
    onUpdateToDo: (ToDo) -> Unit,
    onRequestSync: () -> Unit,
    onStartGuidedTour: () -> Unit,
    onBackToHome: () -> Unit,
    modifier: Modifier = Modifier
) {
    val account by authSessionProvider.account.collectAsState()
    var selectedRouteRaw by rememberSaveable { mutableStateOf<String?>(null) }
    var syncQueued by remember { mutableStateOf(false) }
    val selectedRoute = selectedRouteRaw?.let { raw ->
        SettingsRoute.entries.firstOrNull { it.name == raw }
    }

    Column(modifier = modifier.fillMaxSize()) {
        AndroidDestinationHeader(
            title = selectedRoute?.title ?: "Settings",
            onBack = if (selectedRoute == null) onBackToHome else { { selectedRouteRaw = null } },
            backContentDescription = if (selectedRoute == null) "Back to Home" else "Back to Settings"
        )
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
        ) {
        val usesDetailPanel = maxWidth >= 820.dp
        BackHandler(enabled = selectedRoute != null && !usesDetailPanel) {
            selectedRouteRaw = null
        }

        if (usesDetailPanel) {
            Row(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = ToDoSpacing.screen, vertical = 14.dp),
                horizontalArrangement = Arrangement.spacedBy(ToDoSpacing.section),
                verticalAlignment = Alignment.Top
            ) {
                SettingsList(
                    account = account,
                    toDos = toDos,
                    settingsStore = settingsStore,
                    syncQueued = syncQueued,
                    onRequestSync = {
                        syncQueued = true
                        onRequestSync()
                    },
                    onSelect = { selectedRouteRaw = it.name },
                    modifier = Modifier
                        .weight(1f)
                        .widthIn(max = 560.dp)
                )
                selectedRoute?.let { route ->
                    SettingsDetail(
                        route = route,
                        account = account,
                        authSessionProvider = authSessionProvider,
                        settingsStore = settingsStore,
                        guidedTourStore = guidedTourStore,
                        toDos = toDos,
                        onUpdateToDo = onUpdateToDo,
                        onRequestSync = {
                            syncQueued = true
                            onRequestSync()
                        },
                        syncQueued = syncQueued,
                        onStartGuidedTour = onStartGuidedTour,
                        modifier = Modifier
                            .weight(1f)
                            .widthIn(max = 520.dp)
                    )
                }
            }
        } else {
            AnimatedContent(
                targetState = selectedRoute,
                modifier = Modifier.fillMaxSize(),
                transitionSpec = {
                    val openingDetail = targetState != null && initialState == null
                    val enterOffset = if (openingDetail) { width: Int -> width / 10 } else { width: Int -> -width / 10 }
                    val exitOffset = if (openingDetail) { width: Int -> -width / 10 } else { width: Int -> width / 10 }
                    (slideInHorizontally(tween(240), enterOffset) + fadeIn(tween(180))) togetherWith
                        (slideOutHorizontally(tween(220), exitOffset) + fadeOut(tween(160))) using
                        SizeTransform(clip = false, sizeAnimationSpec = { _, _ -> snap() })
                },
                label = "Settings detail transition"
            ) { route ->
                if (route == null) {
                    SettingsList(
                        account = account,
                        toDos = toDos,
                        settingsStore = settingsStore,
                        syncQueued = syncQueued,
                        onRequestSync = {
                            syncQueued = true
                            onRequestSync()
                        },
                        onSelect = { selectedRouteRaw = it.name },
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(horizontal = ToDoSpacing.screen)
                    )
                } else {
                    SettingsDetail(
                        route = route,
                        account = account,
                        authSessionProvider = authSessionProvider,
                        settingsStore = settingsStore,
                        guidedTourStore = guidedTourStore,
                        toDos = toDos,
                        onUpdateToDo = onUpdateToDo,
                        onRequestSync = {
                            syncQueued = true
                            onRequestSync()
                        },
                        syncQueued = syncQueued,
                        onStartGuidedTour = onStartGuidedTour,
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(horizontal = ToDoSpacing.screen)
                    )
                }
            }
        }
        }
    }
}

@Composable
private fun SettingsList(
    account: AuthenticatedAccount?,
    toDos: List<ToDo>,
    settingsStore: ToDoSettingsStore,
    syncQueued: Boolean,
    onRequestSync: () -> Unit,
    onSelect: (SettingsRoute) -> Unit,
    modifier: Modifier = Modifier
) {
    val appearanceMode by settingsStore.appearanceMode.collectAsState()
    val doneSwipeAction by settingsStore.doneSwipeAction.collectAsState()
    val matchDeletesEverywhere by settingsStore.matchDeletesEverywhere.collectAsState()
    val archivedCount = toDos.count { it.lifecycleState == ToDoState.ARCHIVED }
    val trashCount = toDos.count { it.lifecycleState == ToDoState.TRASHED }
    val usedTagCount = toDos.flatMap { it.tagIds }.distinct().size

    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(bottom = ToDoSpacing.section),
        verticalArrangement = Arrangement.spacedBy(ToDoSpacing.section)
    ) {
        item {
            SettingsSection("Account") {
                SettingsNavigationRow(
                    title = if (account?.isResolved == true) "Account" else "Sign In",
                    detail = accountSummaryDetail(account),
                    onClick = { onSelect(SettingsRoute.ACCOUNT) },
                    leadingIcon = Icons.Default.Person
                )
            }
        }
        item {
            SettingsSection("toDō+") {
                SettingsNavigationRow(
                    title = "Membership",
                    detail = account?.membershipLabel ?: "Free",
                    detailColor = if (account?.hasToDoPlusAccess == true || account?.entitlements?.isFoundingSupporter == true) {
                        BrandSecondary
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
                    onClick = { onSelect(SettingsRoute.PLUS) },
                    leadingIcon = Icons.Default.Star
                )
            }
        }
        item {
            SettingsSection("Sync") {
                SyncStatusBlock(
                    account = account,
                    syncQueued = syncQueued,
                    onRequestSync = onRequestSync
                )
                SettingsNavigationRow(
                    title = "Where to Save",
                    detail = if (account?.isResolved == true) "toDō Sync" else "Local only",
                    onClick = { onSelect(SettingsRoute.SYNC) },
                    leadingIcon = Icons.Default.Settings
                )
                SettingsSwitchRow(
                    title = "Match Deletes Everywhere",
                    checked = matchDeletesEverywhere,
                    onCheckedChange = settingsStore::setMatchDeletesEverywhere,
                    leadingIcon = Icons.Default.Refresh
                )
            }
        }
        item {
            SettingsSection("Look & Feel") {
                SettingsNavigationRow(
                    title = "Appearance",
                    detail = appearanceMode.title,
                    detailColor = BrandSecondary,
                    onClick = { onSelect(SettingsRoute.APPEARANCE) },
                    leadingIcon = Icons.Default.Settings
                )
                SettingsNavigationRow(
                    title = "Tags",
                    detail = "$usedTagCount used",
                    onClick = { onSelect(SettingsRoute.TAGS) },
                    leadingIcon = Icons.Default.Info
                )
            }
        }
        item {
            SettingsSection("Workflow") {
                SettingsNavigationRow(
                    title = "Behavior",
                    detail = doneSwipeAction.title,
                    onClick = { onSelect(SettingsRoute.BEHAVIOR) },
                    leadingIcon = Icons.Default.Settings
                )
                SettingsNavigationRow(
                    title = "Notifications",
                    detail = notificationStatusLabel(LocalContext.current),
                    onClick = { onSelect(SettingsRoute.NOTIFICATIONS) },
                    leadingIcon = Icons.Default.Notifications
                )
            }
        }
        item {
            SettingsActionRow(
                icon = Icons.Default.Star,
                title = "Guided Tour",
                detail = "Replay the setup guide for creating a toDō, choosing sync, and enabling notifications.",
                onClick = { onSelect(SettingsRoute.GUIDED_TOUR) },
                tint = BrandSecondary,
                background = BrandSecondary.copy(alpha = 0.10f)
            )
        }
        item {
            SettingsSection("Manage Your Data") {
                SettingsNavigationRow(
                    title = "Data Controls",
                    detail = "Clean up",
                    onClick = { onSelect(SettingsRoute.DATA_CONTROLS) },
                    leadingIcon = Icons.Default.Settings
                )
                SettingsNavigationRow(
                    title = "Archives",
                    detail = countLabel(archivedCount, "toDō", "toDōs"),
                    onClick = { onSelect(SettingsRoute.ARCHIVES) },
                    leadingIcon = Icons.Default.Check
                )
                SettingsNavigationRow(
                    title = "Trash",
                    detail = countLabel(trashCount, "item", "items"),
                    detailColor = MaterialTheme.colorScheme.error,
                    onClick = { onSelect(SettingsRoute.TRASH) },
                    leadingIcon = Icons.Default.Delete
                )
            }
        }
        item {
            SettingsSection("About") {
                SettingsNavigationRow(
                    title = "About toDō",
                    detail = "Version ${BuildConfig.VERSION_NAME}",
                    onClick = { onSelect(SettingsRoute.ABOUT) },
                    leadingIcon = Icons.Default.Info
                )
            }
        }
        item {
            SettingsFooter()
        }
    }
}

@Composable
private fun SettingsDetail(
    route: SettingsRoute,
    account: AuthenticatedAccount?,
    authSessionProvider: SupabaseAuthSessionProvider,
    settingsStore: ToDoSettingsStore,
    guidedTourStore: GuidedTourStore,
    toDos: List<ToDo>,
    onUpdateToDo: (ToDo) -> Unit,
    onRequestSync: () -> Unit,
    syncQueued: Boolean,
    onStartGuidedTour: () -> Unit,
    modifier: Modifier = Modifier
) {
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(bottom = ToDoSpacing.section),
        verticalArrangement = Arrangement.spacedBy(ToDoSpacing.section)
    ) {
        item {
            when (route) {
                SettingsRoute.ACCOUNT -> AccountSettingsDetail(authSessionProvider, account)
                SettingsRoute.PLUS -> PlusSettingsDetail(account)
                SettingsRoute.SYNC -> SyncSettingsDetail(
                    account = account,
                    syncQueued = syncQueued,
                    matchDeletesEverywhere = settingsStore.matchDeletesEverywhere.collectAsState().value,
                    onMatchDeletesChanged = settingsStore::setMatchDeletesEverywhere,
                    onRequestSync = onRequestSync
                )
                SettingsRoute.APPEARANCE -> AppearanceSettingsDetail(settingsStore)
                SettingsRoute.TAGS -> TagsSettingsDetail(settingsStore, toDos)
                SettingsRoute.BEHAVIOR -> BehaviorSettingsDetail(settingsStore)
                SettingsRoute.GUIDED_TOUR -> GuidedTourSettingsDetail(
                    guidedTourStore = guidedTourStore,
                    onStartGuidedTour = onStartGuidedTour
                )
                SettingsRoute.NOTIFICATIONS -> NotificationSettingsDetail()
                SettingsRoute.DATA_CONTROLS -> DataControlsSettingsDetail(settingsStore)
                SettingsRoute.ARCHIVES -> ToDoArchiveSettingsDetail(toDos, onUpdateToDo)
                SettingsRoute.TRASH -> ToDoTrashSettingsDetail(toDos, onUpdateToDo)
                SettingsRoute.ABOUT -> AboutSettingsDetail()
            }
        }
    }
}

@Composable
private fun SettingsSection(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(title, style = ToDoTextStyles.sectionLabel, color = BrandSecondary)
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = ToDoShapes.card,
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
        ) {
            Column(
                modifier = Modifier.padding(horizontal = ToDoSpacing.card, vertical = 12.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                content()
            }
        }
    }
}

@Composable
private fun SettingsNavigationRow(
    title: String,
    detail: String,
    onClick: () -> Unit,
    leadingIcon: androidx.compose.ui.graphics.vector.ImageVector,
    detailColor: Color = MaterialTheme.colorScheme.onSurfaceVariant
) {
    ListItem(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 4.dp)
            .semantics { role = Role.Button },
        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
        leadingContent = {
            Icon(
                imageVector = leadingIcon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(20.dp)
            )
        },
        headlineContent = { Text(title, style = ToDoTextStyles.body) },
        trailingContent = {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    detail,
                    style = ToDoTextStyles.rowMetadata,
                    color = detailColor,
                    textAlign = TextAlign.End,
                    maxLines = 1,
                    modifier = Modifier.widthIn(max = 150.dp)
                )
                Icon(
                    Icons.AutoMirrored.Filled.ArrowForward,
                    contentDescription = "Open $title",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(18.dp)
                )
            }
        }
    )
}

@Composable
private fun SettingsSwitchRow(
    title: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    leadingIcon: androidx.compose.ui.graphics.vector.ImageVector
) {
    ListItem(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onCheckedChange(!checked) }
            .padding(vertical = 4.dp)
            .semantics { role = Role.Switch },
        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
        leadingContent = {
            Icon(
                leadingIcon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(20.dp)
            )
        },
        headlineContent = { Text(title, style = ToDoTextStyles.body) },
        trailingContent = { Switch(checked = checked, onCheckedChange = null) }
    )
}

@Composable
private fun SettingsActionRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    detail: String,
    onClick: () -> Unit,
    tint: Color,
    background: Color
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = ToDoShapes.card,
        colors = CardDefaults.cardColors(containerColor = background)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(22.dp))
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(title, style = ToDoTextStyles.button, color = tint)
                Text(detail, style = ToDoTextStyles.rowMetadata, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = "Open $title", tint = tint)
        }
    }
}

@Composable
private fun SyncStatusBlock(
    account: AuthenticatedAccount?,
    syncQueued: Boolean,
    onRequestSync: () -> Unit
) {
    val isConnected = account?.isResolved == true
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Current Sync", style = ToDoTextStyles.sectionLabel, modifier = Modifier.weight(1f))
            StatusPill(
                text = when {
                    syncQueued -> "Queued"
                    isConnected -> "Connected"
                    else -> "Local only"
                },
                active = isConnected
            )
        }
        Text(
            if (isConnected) {
                "Your signed-in account is connected and toDō Sync is active across your connected devices and platforms."
            } else {
                "Sign in to sync this Android device with the rest of your toDō account."
            },
            style = ToDoTextStyles.rowMetadata,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        FilledTonalButton(
            onClick = onRequestSync,
            enabled = isConnected
        ) {
            Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(Modifier.size(8.dp))
            Text("Sync now", style = ToDoTextStyles.button.copy(fontSize = 16.sp))
        }
    }
}

@Composable
private fun StatusPill(text: String, active: Boolean) {
    Row(
        modifier = Modifier
            .clip(CircleShape)
            .background(if (active) BrandTertiary else mutedSurface())
            .padding(horizontal = 11.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text,
            style = ToDoTextStyles.rowMetadata.copy(fontSize = 12.sp, lineHeight = 14.sp),
            color = if (active) Color.White else MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun AccountSettingsDetail(
    authSessionProvider: SupabaseAuthSessionProvider,
    account: AuthenticatedAccount?
) {
    val coroutineScope = rememberCoroutineScope()
    var isAuthenticating by remember { mutableStateOf(false) }
    var authError by remember { mutableStateOf<String?>(null) }
    var authenticationIntent by remember { mutableStateOf(AccountAuthenticationIntent.SIGN_IN) }
    var username by remember { mutableStateOf("") }
    val normalizedUsername = AndroidUsernamePolicy.normalize(username)
    val accountState = account?.resolutionState

    SettingsDetailCard {
        if (account == null) {
            Text("Account", style = ToDoTextStyles.detailTitle)
            Text(
                "Choose a username, then verify ownership with Apple or Google to sync your toDōs.",
                style = ToDoTextStyles.body,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            ChoiceRow(
                options = listOf("Sign in", "Create account"),
                selected = if (authenticationIntent == AccountAuthenticationIntent.SIGN_IN) "Sign in" else "Create account",
                onSelected = {
                    authenticationIntent = if (it == "Sign in") {
                        AccountAuthenticationIntent.SIGN_IN
                    } else {
                        AccountAuthenticationIntent.CREATE_ACCOUNT
                    }
                }
            )
            TextField(
                value = username,
                onValueChange = { username = it },
                label = { Text("Username") },
                supportingText = { Text("Shown publicly as @${normalizedUsername ?: "username"}.") },
                singleLine = true,
                enabled = !isAuthenticating,
                modifier = Modifier.fillMaxWidth(),
                shape = ToDoShapes.small,
                colors = ToDoTextFieldColors()
            )
            ProviderAuthButtons(
                enabled = SupabaseConfig.isConfigured && !isAuthenticating && normalizedUsername != null,
                onApple = {
                    coroutineScope.launch {
                        isAuthenticating = true
                        authError = runCatching {
                            authSessionProvider.signIn(SupabaseOAuthProvider.APPLE, authenticationIntent, normalizedUsername)
                        }.exceptionOrNull()?.message
                        isAuthenticating = false
                    }
                },
                onGoogle = {
                    coroutineScope.launch {
                        isAuthenticating = true
                        authError = runCatching {
                            authSessionProvider.signIn(SupabaseOAuthProvider.GOOGLE, authenticationIntent, normalizedUsername)
                        }.exceptionOrNull()?.message
                        isAuthenticating = false
                    }
                }
            )
        } else if (accountState != AccountResolutionState.RESOLVED) {
            Text("Finish account setup", style = ToDoTextStyles.detailTitle)
            Text(
                account.resolutionMessage ?: "Choose a username before sync can begin.",
                style = ToDoTextStyles.body,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            if (account.resolutionState == AccountResolutionState.ACCOUNT_MISMATCH) {
                Button(
                    onClick = {
                        coroutineScope.launch {
                            isAuthenticating = true
                            authError = runCatching {
                                authSessionProvider.continueWithAuthenticatedAccount()
                            }.exceptionOrNull()?.message
                            isAuthenticating = false
                        }
                    },
                    enabled = !isAuthenticating,
                ) { Text("Continue with this account", style = ToDoTextStyles.button) }
            } else {
                TextField(
                    value = username,
                    onValueChange = { username = it },
                    label = { Text("Username") },
                    singleLine = true,
                    enabled = !isAuthenticating,
                    modifier = Modifier.fillMaxWidth(),
                    shape = ToDoShapes.small,
                    colors = ToDoTextFieldColors()
                )
                Button(
                    onClick = {
                        coroutineScope.launch {
                            isAuthenticating = true
                            authError = if (authSessionProvider.completeAccountSetup(username)) null else {
                                "That username is unavailable or could not be saved."
                            }
                            isAuthenticating = false
                        }
                    },
                    enabled = !isAuthenticating && normalizedUsername != null
                ) { Text("Continue", style = ToDoTextStyles.button) }
            }
            AccountSignOutButton(authSessionProvider, isAuthenticating)
        } else {
            Text("Account", style = ToDoTextStyles.detailTitle)
            Text("@${account.username.orEmpty()}", style = ToDoTextStyles.body)
            Text(account.email.orEmpty(), style = ToDoTextStyles.rowMetadata, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text("Connected sign-in methods", style = ToDoTextStyles.sectionLabel, modifier = Modifier.padding(top = 8.dp))
            Text(
                account.linkedProviders.sorted().joinToString().ifBlank { "None reported" },
                style = ToDoTextStyles.body,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            AccountSignOutButton(authSessionProvider, isAuthenticating)
        }
        authError?.let { Text(it, style = ToDoTextStyles.rowMetadata, color = MaterialTheme.colorScheme.error) }
    }
}

@Composable
private fun ProviderAuthButtons(enabled: Boolean, onApple: () -> Unit, onGoogle: () -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        FilledTonalButton(onClick = onApple, enabled = enabled) {
            Text("Apple", style = ToDoTextStyles.button.copy(fontSize = 16.sp))
        }
        FilledTonalButton(onClick = onGoogle, enabled = enabled) {
            Text("Google", style = ToDoTextStyles.button.copy(fontSize = 16.sp))
        }
    }
}

@Composable
private fun AccountSignOutButton(
    authSessionProvider: SupabaseAuthSessionProvider,
    isAuthenticating: Boolean
) {
    val scope = rememberCoroutineScope()
    FilledTonalButton(
        onClick = { scope.launch { authSessionProvider.signOut() } },
        enabled = !isAuthenticating
    ) { Text("Sign out", style = ToDoTextStyles.button.copy(fontSize = 16.sp)) }
}

@Composable
private fun PlusSettingsDetail(account: AuthenticatedAccount?) {
    val entitlements = account?.entitlements
    val hasPlusAccess = account?.hasToDoPlusAccess == true
    val isRecognized = entitlements?.isFoundingSupporter == true || entitlements?.isPioneer == true
    SettingsDetailCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("toDō+", style = ToDoTextStyles.detailTitle, modifier = Modifier.weight(1f))
            StatusPill(
                text = account?.membershipLabel ?: "Free",
                active = hasPlusAccess || isRecognized
            )
        }
        when {
            account == null -> Text(
                "Sign in to connect membership access and recognition to your toDō account.",
                style = ToDoTextStyles.body,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            hasPlusAccess -> {
                Text(
                    "This account has toDō+ access. Features that use the shared capability model can be enabled for this account on Android.",
                    style = ToDoTextStyles.body,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                PlusCapabilityRow("Sync everywhere", "Available")
                PlusCapabilityRow("Expanded personal collaboration", "Available")
                if (entitlements?.includesFuturePaidFeatures == true) {
                    PlusCapabilityRow("Future paid capabilities", "Included")
                }
            }
            isRecognized -> Text(
                "This account carries membership recognition. Full toDō+ access is not active for the current entitlement state.",
                style = ToDoTextStyles.body,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            else -> Text(
                "No active toDō+ entitlement is connected to this account yet.",
                style = ToDoTextStyles.body,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        account?.accountRole?.takeIf { it != "user" }?.let { role ->
            Text(
                "Account permission: ${role.replaceFirstChar { it.titlecase(Locale.getDefault()) }}",
                style = ToDoTextStyles.rowMetadata,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun PlusCapabilityRow(title: String, detail: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(Icons.Default.CheckCircle, contentDescription = null, tint = BrandTertiary)
        Text(title, style = ToDoTextStyles.body, modifier = Modifier.weight(1f))
        Text(detail, style = ToDoTextStyles.rowMetadata, color = BrandSecondary)
    }
}

@Composable
private fun SyncSettingsDetail(
    account: AuthenticatedAccount?,
    syncQueued: Boolean,
    matchDeletesEverywhere: Boolean,
    onMatchDeletesChanged: (Boolean) -> Unit,
    onRequestSync: () -> Unit
) {
    SettingsDetailCard {
        Text("Current Sync", style = ToDoTextStyles.sectionLabel)
        StatusPill(if (account?.isResolved == true) "Connected" else "Local only", account?.isResolved == true)
        Text(
            if (account?.isResolved == true) {
                "Your signed-in account is connected. Changes can stay in sync across the devices and platforms where you use toDō."
            } else {
                "Sign in to use toDō Sync across your connected devices and platforms."
            },
            style = ToDoTextStyles.body,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Button(
            onClick = onRequestSync,
            enabled = account?.isResolved == true
        ) {
            Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(Modifier.size(8.dp))
            Text(if (syncQueued) "Sync queued" else "Sync now", style = ToDoTextStyles.button)
        }
        SettingsSwitchRow(
            title = "Match Deletes Everywhere",
            checked = matchDeletesEverywhere,
            onCheckedChange = onMatchDeletesChanged,
            leadingIcon = Icons.Default.Refresh
        )
    }
}

@Composable
private fun AppearanceSettingsDetail(settingsStore: ToDoSettingsStore) {
    val appearanceMode by settingsStore.appearanceMode.collectAsState()
    SettingsDetailCard {
        Text("Appearance", style = ToDoTextStyles.detailTitle)
        Text(
            "Choose whether Android follows the system or uses a fixed light or dark surface treatment.",
            style = ToDoTextStyles.body,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        ChoiceRow(
            options = ToDoSettingsStore.AppearanceMode.entries.map { it.title },
            selected = appearanceMode.title,
            onSelected = { selected ->
                ToDoSettingsStore.AppearanceMode.entries
                    .firstOrNull { it.title == selected }
                    ?.let(settingsStore::setAppearanceMode)
            }
        )
        Text(
            "The classic toDō palette remains the active Android theme; additional palette variants remain a later design slice.",
            style = ToDoTextStyles.rowMetadata,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun TagsSettingsDetail(settingsStore: ToDoSettingsStore, toDos: List<ToDo>) {
    val showTags by settingsStore.showTagsWhileCreating.collectAsState()
    SettingsDetailCard {
        Text("Tags", style = ToDoTextStyles.detailTitle)
        Text(
            "Tags stay attached to the shared toDō model and remain available wherever your account syncs.",
            style = ToDoTextStyles.body,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text("${toDos.flatMap { it.tagIds }.distinct().size} tag links currently loaded", style = ToDoTextStyles.rowMetadata)
        SettingsSwitchRow(
            title = "Show Tags While Creating",
            checked = showTags,
            onCheckedChange = settingsStore::setShowTagsWhileCreating,
            leadingIcon = Icons.Default.Info
        )
    }
}

@Composable
private fun BehaviorSettingsDetail(settingsStore: ToDoSettingsStore) {
    val doneSwipeAction by settingsStore.doneSwipeAction.collectAsState()
    SettingsDetailCard {
        Text("Behavior", style = ToDoTextStyles.detailTitle)
        Text("Configure the choices that shape everyday toDō handling.", style = ToDoTextStyles.body, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text("Remove from view", style = ToDoTextStyles.sectionLabel, modifier = Modifier.padding(top = 8.dp))
        ChoiceRow(
            options = ToDoSettingsStore.DoneSwipeAction.entries.map { it.title },
            selected = doneSwipeAction.title,
            onSelected = { selected ->
                ToDoSettingsStore.DoneSwipeAction.entries
                    .firstOrNull { it.title == selected }
                    ?.let(settingsStore::setDoneSwipeAction)
            }
        )
        Text(
            "Archive keeps completed work available in Archives. Move to Trash is reserved for deliberate cleanup.",
            style = ToDoTextStyles.rowMetadata,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun GuidedTourSettingsDetail(
    guidedTourStore: GuidedTourStore,
    onStartGuidedTour: () -> Unit
) {
    val isActive by guidedTourStore.isActive.collectAsState()
    val currentStep by guidedTourStore.currentStep.collectAsState()
    SettingsDetailCard {
        Text("Guided Tour", style = ToDoTextStyles.detailTitle)
        Text(
            "Replay the setup guide for creating a toDō, choosing sync, and enabling notifications. It uses Android surfaces and controls while following the same learning path as iOS and iPadOS.",
            style = ToDoTextStyles.body,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        if (isActive) {
            Text(
                "Current step: ${currentStep.title}",
                style = ToDoTextStyles.rowMetadata,
                color = BrandSecondary
            )
        }
        Button(onClick = {
            guidedTourStore.restart()
            onStartGuidedTour()
        }) {
            Text(if (isActive) "Restart Guided Tour" else "Start Guided Tour")
        }
    }
}

@Composable
private fun NotificationSettingsDetail() {
    val context = LocalContext.current
    var permissionVersion by remember { mutableStateOf(0) }
    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) {
        permissionVersion += 1
    }
    val enabled = remember(permissionVersion) {
        NotificationManagerCompat.from(context).areNotificationsEnabled()
    }
    SettingsDetailCard {
        Text("Notifications", style = ToDoTextStyles.detailTitle)
        StatusPill(if (enabled) "Allowed" else "Off", enabled)
        Text(
            if (enabled) {
                "Android allows toDō notifications. Reminder scheduling will use the native Android notification surface as it is implemented."
            } else {
                "Notifications are off. Enable them in Android system settings when you want reminder alerts."
            },
            style = ToDoTextStyles.body,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        FilledTonalButton(onClick = {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            } else {
                openNotificationSettings(context)
            }
        }) {
            Text(
                if (enabled) "Open Android notification settings" else "Allow notifications",
                style = ToDoTextStyles.button.copy(fontSize = 16.sp)
            )
        }
    }
}

@Composable
private fun DataControlsSettingsDetail(settingsStore: ToDoSettingsStore) {
    var showResetDialog by remember { mutableStateOf(false) }
    SettingsDetailCard {
        Text("Data Controls", style = ToDoTextStyles.detailTitle)
        Text(
            "Manage local choices without changing your account or synced toDō data.",
            style = ToDoTextStyles.body,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        SettingsActionRow(
            icon = Icons.Default.Refresh,
            title = "Reset Choices",
            detail = "Restore appearance-independent workflow preferences.",
            onClick = { showResetDialog = true },
            tint = MaterialTheme.colorScheme.onSurface,
            background = mutedSurface()
        )
        Text(
            "Account deletion and destructive remote-data reset require a dedicated authenticated flow and are not exposed from this first Android Settings slice.",
            style = ToDoTextStyles.rowMetadata,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
    if (showResetDialog) {
        AlertDialog(
            onDismissRequest = { showResetDialog = false },
            title = { Text("Reset choices?") },
            text = { Text("This restores workflow preferences but does not delete toDōs or your account.") },
            confirmButton = {
                TextButton(onClick = {
                    settingsStore.resetChoices()
                    showResetDialog = false
                }) { Text("Reset") }
            },
            dismissButton = { TextButton(onClick = { showResetDialog = false }) { Text("Cancel") } }
        )
    }
}

@Composable
private fun ToDoArchiveSettingsDetail(toDos: List<ToDo>, onUpdateToDo: (ToDo) -> Unit) {
    SettingsRecordList(
        title = "Archives",
        emptyMessage = "Archived toDōs will appear here.",
        records = toDos.filter { it.lifecycleState == ToDoState.ARCHIVED },
        onRestore = { onUpdateToDo(it.transition(ToDoState.ACTIVE)) }
    )
}

@Composable
private fun ToDoTrashSettingsDetail(toDos: List<ToDo>, onUpdateToDo: (ToDo) -> Unit) {
    SettingsRecordList(
        title = "Trash",
        emptyMessage = "Deleted toDōs will appear here.",
        records = toDos.filter { it.lifecycleState == ToDoState.TRASHED },
        onRestore = { onUpdateToDo(it.transition(ToDoState.ACTIVE)) }
    )
}

@Composable
private fun SettingsRecordList(
    title: String,
    emptyMessage: String,
    records: List<ToDo>,
    onRestore: (ToDo) -> Unit
) {
    SettingsDetailCard {
        Text(title, style = ToDoTextStyles.detailTitle)
        if (records.isEmpty()) {
            Text(emptyMessage, style = ToDoTextStyles.body, color = MaterialTheme.colorScheme.onSurfaceVariant)
        } else {
            records.sortedByDescending { it.updatedAt }.forEach { toDo ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        Text(toDo.task, style = ToDoTextStyles.rowTitle)
                        Text(
                            formatSettingsDate(toDo.updatedAt.toEpochMilli()),
                            style = ToDoTextStyles.rowMetadata,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    FilledTonalButton(onClick = { onRestore(toDo) }) {
                        Text("Restore", style = ToDoTextStyles.button.copy(fontSize = 15.sp))
                    }
                }
            }
        }
    }
}

@Composable
private fun AboutSettingsDetail() {
    val context = LocalContext.current
    var showReleaseHistory by remember { mutableStateOf(false) }
    SettingsDetailCard {
        Text("About toDō", style = ToDoTextStyles.detailTitle)
        Text(
            "toDō is a productivity system built to help you stay organized without getting in your way. From everyday tasks and shopping lists to bigger plans, it is designed to work the way you do.",
            style = ToDoTextStyles.body,
            color = MaterialTheme.colorScheme.onSurface
        )
        Text(
            "Take a little time to explore, try different ways of organizing your tasks, and make the app your own.",
            style = ToDoTextStyles.body,
            color = MaterialTheme.colorScheme.onSurface
        )
        Text("Version ${BuildConfig.VERSION_NAME}", style = ToDoTextStyles.sectionLabel, modifier = Modifier.padding(top = 8.dp))
        Text("Android 16 · API 36 minimum", style = ToDoTextStyles.rowMetadata, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text("Release Notes", style = ToDoTextStyles.sectionLabel, modifier = Modifier.padding(top = 8.dp))
        ReleaseNote("Added the adaptive Android Settings surface and account profile flow.", highlight = true)
        ReleaseNote("Added account sync and the first profile-image upload path.", highlight = true)
        ReleaseNote("Continued aligning Home, Momentum, filters, and typography with Apple platforms.")
        FilledTonalButton(onClick = { showReleaseHistory = true }) {
            Text("All release history", style = ToDoTextStyles.button.copy(fontSize = 16.sp))
            Spacer(Modifier.size(8.dp))
            Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = null, modifier = Modifier.size(16.dp))
        }
        Text("Made with Intention", style = ToDoTextStyles.sectionLabel, modifier = Modifier.padding(top = 8.dp))
        FilledTonalButton(
            onClick = {
                context.startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse("https://yourtodo.today")))
            }
        ) { Text("Visit yourtodo.today", style = ToDoTextStyles.button.copy(fontSize = 16.sp)) }
        FilledTonalButton(
            onClick = {
                context.startActivity(Intent(Intent.ACTION_SENDTO, android.net.Uri.parse("mailto:support@iamshift.dev")))
            }
        ) { Text("Contact support", style = ToDoTextStyles.button.copy(fontSize = 16.sp)) }
        Text("Legal", style = ToDoTextStyles.sectionLabel, modifier = Modifier.padding(top = 8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            TextButton(onClick = {
                context.startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse("https://yourtodo.today/legal/privacy.html")))
            }) { Text("Privacy") }
            TextButton(onClick = {
                context.startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse("https://yourtodo.today/legal/terms.html")))
            }) { Text("Terms") }
        }
    }
    if (showReleaseHistory) {
        AlertDialog(
            onDismissRequest = { showReleaseHistory = false },
            title = { Text("Release History") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("3.1.0 · Android", style = ToDoTextStyles.sectionLabel)
                    ReleaseNote("Initial Android foundation with native Kotlin, local persistence, and account sync.")
                    ReleaseNote("Added Apple/Google sign-in, cross-platform sync, and adaptive phone/tablet layout.")
                    Text("Earlier Android development builds are tracked in the project documentation.", style = ToDoTextStyles.rowMetadata, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            },
            confirmButton = { TextButton(onClick = { showReleaseHistory = false }) { Text("Close") } }
        )
    }
}

@Composable
private fun ReleaseNote(note: String, highlight: Boolean = false) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.Top) {
        Box(
            modifier = Modifier
                .padding(top = 6.dp)
                .size(6.dp)
                .clip(CircleShape)
                .background(BrandPrimary)
        )
        Text(
            note,
            style = ToDoTextStyles.rowMetadata.copy(
                fontFamily = ToDoTypography.ui,
                fontWeight = if (highlight) androidx.compose.ui.text.font.FontWeight.Bold else androidx.compose.ui.text.font.FontWeight.Normal
            ),
            color = MaterialTheme.colorScheme.onSurface
        )
    }
}

@Composable
private fun SettingsDetailCard(content: @Composable () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = ToDoShapes.card,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Column(
            modifier = Modifier.padding(ToDoSpacing.card),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) { content() }
    }
}

@Composable
private fun ChoiceRow(options: List<String>, selected: String, onSelected: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        options.forEach { option ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .selectable(
                        selected = option == selected,
                        onClick = { onSelected(option) },
                        role = Role.RadioButton
                    )
                    .padding(vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                RadioButton(selected = option == selected, onClick = null)
                Text(option, style = ToDoTextStyles.body)
            }
        }
    }
}

@Composable
private fun SettingsFooter() {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            "toDō · what matters",
            style = ToDoTextStyles.body.copy(fontFamily = ToDoTypography.brand),
            color = MaterialTheme.colorScheme.onSurface,
            textAlign = TextAlign.Center
        )
        Text(
            "Built with intention for the way you work.",
            style = ToDoTextStyles.rowMetadata,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
    }
}

private fun countLabel(count: Int, singular: String, plural: String): String =
    "$count ${if (count == 1) singular else plural}"

private fun accountSummaryDetail(account: AuthenticatedAccount?): String = when {
    account?.isResolved == true -> "toDō Sync"
    account?.resolutionState == AccountResolutionState.NEEDS_USERNAME -> "Setup needed"
    account?.resolutionState == AccountResolutionState.MIGRATION_REQUIRED -> "Finish setup"
    account?.resolutionState == AccountResolutionState.ACCOUNT_MISMATCH -> "Review account"
    account != null -> "Connecting"
    else -> "Local"
}

private fun formatSettingsDate(epochMillis: Long): String =
    java.time.Instant.ofEpochMilli(epochMillis)
        .atZone(ZoneId.systemDefault())
        .format(DateTimeFormatter.ofPattern("MMM d, yyyy", Locale.getDefault()))

private fun notificationStatusLabel(context: Context): String =
    if (NotificationManagerCompat.from(context).areNotificationsEnabled()) "Allowed" else "Off"

private fun openNotificationSettings(context: Context) {
    context.startActivity(
        Intent(AndroidSettings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(AndroidSettings.EXTRA_APP_PACKAGE, context.packageName)
        }
    )
}

@Composable
private fun mutedSurface(): Color =
    if (MaterialTheme.colorScheme.background == AppSurfaceDark) {
        AppSurfaceMutedDark
    } else {
        AppSurfaceMutedLight
    }
