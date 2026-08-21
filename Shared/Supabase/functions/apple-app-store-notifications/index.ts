import {
  createServiceClient,
  errorMessage,
  persistVerifiedTransaction,
  resolveLinkedAccount,
  updateEntitlement,
  verifyNotification,
} from "../_shared/apple_iap.ts";

interface NotificationRequest {
  signedPayload?: string;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  let signedPayload: string;
  try {
    const body = await request.json() as NotificationRequest;
    if (!body.signedPayload) {
      return json({ error: "Missing signedPayload" }, 400);
    }
    signedPayload = body.signedPayload;
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const supabase = createServiceClient();
  let notificationUUID: string | undefined;

  try {
    const { decoded: notification, verifier } = await verifyNotification(
      signedPayload,
    );
    notificationUUID = notification.notificationUUID;
    if (
      !notificationUUID || !notification.notificationType ||
      !notification.data?.environment
    ) {
      throw new Error("Verified notification is missing required metadata");
    }

    const { data: existingEvent, error: existingEventError } = await supabase
      .from("apple_iap_notification_events")
      .select("processing_status")
      .eq("notification_uuid", notificationUUID)
      .maybeSingle();
    if (existingEventError) {
      throw new Error(
        `Could not check notification status: ${existingEventError.message}`,
      );
    }
    if (existingEvent?.processing_status === "processed") {
      return json({ received: true, duplicate: true });
    }

    const { error: eventError } = await supabase
      .from("apple_iap_notification_events")
      .upsert({
        notification_uuid: notificationUUID,
        notification_type: notification.notificationType,
        subtype: notification.subtype ?? null,
        environment: notification.data.environment,
        bundle_id: notification.data.bundleId ?? null,
        app_apple_id: notification.data.appAppleId ?? null,
        signed_payload: signedPayload,
        decoded_payload: notification,
        processing_status: "processing",
        processing_error: null,
        processed_at: null,
      }, { onConflict: "notification_uuid" });

    if (eventError) {
      throw new Error(`Could not record notification: ${eventError.message}`);
    }

    const signedTransaction = notification.data.signedTransactionInfo;
    if (signedTransaction) {
      const transaction = await verifier.verifyAndDecodeTransaction(
        signedTransaction,
      );
      const accountID = await resolveLinkedAccount(supabase, transaction);
      await persistVerifiedTransaction(
        supabase,
        transaction,
        signedTransaction,
        accountID,
      );

      if (accountID) {
        const renewalInfo = notification.data.signedRenewalInfo
          ? await verifier.verifyAndDecodeRenewalInfo(
            notification.data.signedRenewalInfo,
          )
          : undefined;
        await updateEntitlement(
          supabase,
          transaction,
          accountID,
          notification.notificationType,
          notification.subtype,
          renewalInfo,
        );
      }
    }

    const { error: processedError } = await supabase
      .from("apple_iap_notification_events")
      .update({
        processing_status: "processed",
        processed_at: new Date().toISOString(),
      })
      .eq("notification_uuid", notificationUUID);
    if (processedError) {
      throw new Error(
        `Could not mark notification processed: ${processedError.message}`,
      );
    }

    return json({ received: true });
  } catch (error) {
    const message = errorMessage(error);
    console.error("App Store notification processing failed", message);
    if (notificationUUID) {
      await supabase
        .from("apple_iap_notification_events")
        .update({
          processing_status: "failed",
          processing_error: message,
          processed_at: new Date().toISOString(),
        })
        .eq("notification_uuid", notificationUUID);
    }
    return json({ error: "Notification processing failed" }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
