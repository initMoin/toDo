"use client";

import { Icon } from "@/components/Icon";

export function ProviderMethodsCard({
  connectedProviders,
}: {
  connectedProviders: Set<string>;
}) {
  const providers = (["apple", "google"] as const).filter((provider) => connectedProviders.has(provider));

  return (
    <section className="account-section" aria-labelledby="account-methods-title">
      <h2 className="account-section-title" id="account-methods-title">Sign-In Methods</h2>
      <div className="account-section-card account-methods-card">
        <div className="account-provider-list">
          {providers.map((provider) => (
            <div className="account-list-row account-provider-row" key={provider}>
              <Icon name={provider} size={19} />
              <span><strong>{provider === "apple" ? "Apple" : "Google"}</strong><small>Connected to this account</small></span>
              <Icon name="check" size={18} />
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
