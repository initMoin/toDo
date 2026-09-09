"use client";

import { Icon } from "@/components/Icon";

export function ProviderMethodsCard({ connectedProviders }: { connectedProviders: Set<string> }) {
  const providers = ["apple", "google"] as const;

  return (
    <section className="account-section" aria-labelledby="account-methods-title">
      <h2 className="account-section-title" id="account-methods-title">Sign-In Methods</h2>
      <div className="account-section-card account-methods-card" aria-readonly="true">
        <div className="account-provider-list">
          {providers.map((provider) => {
            const isConnected = connectedProviders.has(provider);
            const label = provider === "apple" ? "Apple" : "Google";
            return (
              <div className="account-list-row account-provider-row" key={provider}>
                <Icon name={provider} size={19} />
                <span><strong>{label}</strong><small>{isConnected ? "Connected to this account" : "Not connected"}</small></span>
                <Icon name={isConnected ? "check" : "alert"} size={18} />
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
