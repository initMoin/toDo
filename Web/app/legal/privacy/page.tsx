import { LegalShell } from "../LegalShell";

export default function PrivacyPage() {
  return (
    <LegalShell eyebrow="Privacy" title="Your work stays yours.">
      <p>toDō stores the account and task information needed to provide sync, shared lists, and account access. We do not sell personal information.</p>
      <h2>What we collect</h2>
      <p>When you sign in, Supabase Auth receives the identity information supplied by Apple or Google. Your username and optional profile information are stored in your toDō profile. Tasks, NanoDos, tags, Collabs, invitations, and sync metadata are stored in Supabase so your devices can stay in step.</p>
      <h2>Web notifications and calendar feeds</h2>
      <p>When you enable browser notifications, toDō stores the browser’s Web Push endpoint and encryption keys for your account so authorized reminder and shared-list deliveries can reach that browser. You can disable the subscription from Notifications or your browser settings. If you enable the calendar option, toDō creates a private, revocable calendar-feed token; anyone with that feed URL may be able to view the due ToDos it contains, so treat it like a private link.</p>
      <h2>Your choices</h2>
      <p>You can export your account data, delete personal ToDos, and request account deletion from Data Controls. Apple and Google identities remain separate authentication proofs unless you explicitly connect both from your resolved toDō account. We never connect accounts by matching an email address or username.</p>
      <h2>Service providers</h2>
      <p>Supabase provides authentication, database, realtime, storage, and server-side functions. Apple and Google provide the sign-in services you choose. We retain only what is needed to operate the service and protect it with row-level access controls.</p>
      <h2>Contact</h2>
      <p>Questions or deletion requests can be sent to <a href="mailto:support@yourtodo.today">support@yourtodo.today</a>.</p>
    </LegalShell>
  );
}
