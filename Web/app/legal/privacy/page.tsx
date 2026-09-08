import { LegalShell } from "../LegalShell";

export default function PrivacyPage() {
  return (
    <LegalShell eyebrow="Privacy" title="Your work stays yours.">
      <p>toDō stores the account and task information needed to provide sync, shared lists, and account access. We do not sell personal information.</p>
      <h2>Account and sign-in</h2>
      <p>Your username is a public toDō locator, not proof of ownership. A verified private email supports account setup and recovery. Depending on the platform, you may use a passkey, a password for that verified email, Apple, or Google to authenticate. A time-based authenticator factor and an optional SMS fallback may be available from Account Security.</p>
      <p>Apple and Google remain optional identities. They are connected only when you are already signed in to the intended account and explicitly start linking the provider. We never merge accounts because usernames, email addresses, or provider metadata match.</p>
      <h2>What we collect</h2>
      <p>Supabase Auth receives the identity and verification information required by the sign-in method you choose. Your username and optional profile information, including a profile image, are stored in your toDō profile. Tasks, NanoDos, tags, Collabs, invitations, shared-task permissions, purchases, entitlements, and sync metadata are stored in Supabase so your devices can stay in step.</p>
      <h2>Web notifications and calendar feeds</h2>
      <p>When you enable browser notifications, toDō stores the browser’s Web Push endpoint and encryption keys for your account so authorized reminder and shared-list deliveries can reach that browser. You can disable the subscription from Notifications or your browser settings. If you enable the calendar option, toDō creates a private, revocable calendar-feed token; anyone with that feed URL may be able to view the due ToDos it contains, so treat it like a private link.</p>
      <h2>Your choices</h2>
      <p>You can export your account data, delete personal ToDos, manage shared access, and request account deletion from Data Controls. Signing out does not transfer or expose the account&apos;s records to an unsigned session. Account deletion is a server-authorized action and is separate from signing out.</p>
      <h2>Service providers</h2>
      <p>Supabase provides authentication, database, realtime, storage, and server-side functions. Apple and Google provide the sign-in services you choose. We retain only what is needed to operate the service and protect it with row-level access controls.</p>
      <h2>Contact</h2>
      <p>Questions or deletion requests can be sent to <a href="mailto:support@yourtodo.today">support@yourtodo.today</a>.</p>
    </LegalShell>
  );
}
