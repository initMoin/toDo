import { LegalShell } from "../LegalShell";

export default function TermsPage() {
  return (
    <LegalShell eyebrow="Terms of Use" title="A little structure for doing.">
      <p>These Terms govern your use of toDō Web, the web companion for the toDō service. By using the service, you agree to use it lawfully and to keep your sign-in account secure.</p>
      <h2>toDō+ access</h2>
      <p>Web access is a toDō+ capability. Active and grace-period entitlements provide access to the Web workspace. If an entitlement expires, Web access may pause without deleting your data. Native app access and locally stored data are governed by their respective platform behavior.</p>
      <h2>Authentication and account ownership</h2>
      <p>Your username identifies you publicly inside toDō, while authentication proves control of the account. Passkeys, passwords, Apple, and Google are account sign-in methods where supported. Provider linking must be explicitly started from the already authenticated account; usernames and email addresses are never used to merge accounts automatically.</p>
      <h2>Your content</h2>
      <p>You keep ownership of the tasks, notes, and shared-list content you create. You are responsible for the content you add and for inviting only people who should have access to a Collab. Collab permissions are enforced by the service.</p>
      <h2>Availability</h2>
      <p>Browser notifications depend on browser permission, device settings, network connectivity, and the notification provider. Calendar feeds depend on the calendar client refreshing the private feed URL. Notifications and calendar feeds are conveniences and are not guaranteed. The service may change as toDō evolves.</p>
      <h2>Account actions</h2>
      <p>Account export and deletion controls are available in Data Controls. Deletion of a Collab owner account may affect shared lists and the people who use them; review the consequences before confirming the request. Store subscriptions and in-app purchases are processed by the applicable platform store, and entitlement access follows the transaction state associated with the authenticated account.</p>
      <h2>Contact</h2>
      <p>For support, account questions, or a report about shared content, contact <a href="mailto:support@yourtodo.today">support@yourtodo.today</a>.</p>
    </LegalShell>
  );
}
