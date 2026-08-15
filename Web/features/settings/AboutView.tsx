import Image from "next/image";
import Link from "next/link";
import { Icon } from "@/components/Icon";

const releasePreview = [
  "Added toDō+ membership and expanded personal Collab options.",
  "Added custom reminder sounds and improved completion feedback.",
  "Improved voice entry, NanoDo reminders, onboarding, and accessibility.",
  "Unified the experience across iPhone, iPad, Apple Watch, and Mac.",
  "And much more, shaped around the way you work.",
];

export function AboutView() {
  return (
    <article className="settings-detail-shell about-shell" aria-labelledby="about-title">
      <h1 className="sr-only" id="about-title">about toDō</h1>

      <div className="about-copy">
        <p>toDō is a productivity system built for the user to help you stay organized without getting in your way. From everyday tasks and shopping lists to bigger plans and everything beyond, it’s designed to work the way you do.</p>
        <p>Take a little time to explore. Try different ways of organizing your tasks, make the app your own, and see what works best for you. Visit yourtodo.today to learn more about toDō, and follow my Substack for release notes, engineering talk, and the thinking behind each update.</p>
        <p><strong>Hi, I’m moin.</strong> I built toDō because I wanted a productivity app that felt simple, thoughtful, and enjoyable to use every day. It’s been a long journey, and I’m still making it better with every release. If you’d like to learn more about my work, you’ll find me at iamshift.dev.</p>
      </div>

      <p className="about-signature">shift beneath the view</p>

      <div className="about-block" aria-labelledby="release-notes-title">
        <h2 className="about-plain-heading" id="release-notes-title">Release Notes</h2>
        <div className="about-release-preview">
          <div className="about-release-version">
            <Icon name="alert" size={18} />
            <strong>Version</strong>
            <span>3.1</span>
          </div>
          <ul>
            {releasePreview.map((note, index) => (
              <li className={index < 2 ? "about-release-highlight" : undefined} key={note}>
                <span aria-hidden="true" />
                <span>{note}</span>
              </li>
            ))}
          </ul>
          <Link className="about-release-link" href="/settings/releases">
            <span>All Release History</span>
            <Icon name="arrow-up-right" size={15} />
          </Link>
        </div>
      </div>

      <div className="about-block" aria-labelledby="made-with-intention-title">
        <h2 className="about-plain-heading" id="made-with-intention-title">Made with Intention</h2>
        <div className="about-brand-links">
          <a className="about-brand-card" href="https://iamshift.dev" target="_blank" rel="noreferrer" aria-label="moin.shift()">
            <span className="about-external-mark"><Icon name="arrow-up-right" size={16} /></span>
            <Image src="/brand/shift-logomark.png" width={50} height={50} alt="" />
            <strong>moin.shift()</strong>
          </a>
          <a className="about-brand-card" href="https://yourtodo.today" target="_blank" rel="noreferrer" aria-label="toDō today">
            <span className="about-external-mark"><Icon name="arrow-up-right" size={16} /></span>
            <Image src="/brand/todo-today-logo.png" width={50} height={50} alt="" />
            <strong className="about-todo-brand">toDō today</strong>
          </a>
        </div>
        <a className="about-support-link" href="mailto:support@iamshift.dev">
          <span>support@iamshift.dev</span>
          <Icon name="arrow-up-right" size={15} />
        </a>
      </div>

      <div className="about-block" aria-labelledby="about-legal-title">
        <h2 className="about-plain-heading" id="about-legal-title">Legal</h2>
        <div className="about-legal-links">
          <a className="about-inline-link" href="/legal/privacy" target="_blank" rel="noreferrer">
            <span>Privacy Policy</span>
            <Icon name="arrow-up-right" size={13} />
          </a>
          <a className="about-inline-link" href="/legal/terms" target="_blank" rel="noreferrer">
            <span>Terms of Use</span>
            <Icon name="arrow-up-right" size={13} />
          </a>
        </div>
      </div>
    </article>
  );
}
