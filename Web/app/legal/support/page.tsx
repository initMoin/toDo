import { LegalShell } from "../LegalShell";

export default function SupportPage() {
  return (
    <LegalShell eyebrow="Support" title="We’ll help you find the next step.">
      <p>For account access, data deletion, future notification questions, or shared-list questions, email us and include the username associated with your toDō account.</p>
      <p><a className="support-email" href="mailto:support@yourtodo.today">support@yourtodo.today</a></p>
      <h2>Before you write</h2>
      <ul>
        <li>Tell us which username and provider you use. Apple and Google connect only when you explicitly link the second provider from your resolved account.</li>
        <li>For future browser notification problems, include your browser and whether notifications are allowed for do.yourtodo.today.</li>
        <li>Never send a password, authentication token, or private signing key.</li>
      </ul>
    </LegalShell>
  );
}
