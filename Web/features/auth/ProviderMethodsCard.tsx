"use client";

import { Icon } from "@/components/Icon";
import { useAuth } from "@/features/auth/AuthProvider";

export function ProviderMethodsCard({
  connectedProviders,
}: {
  connectedProviders: Set<string>;
}) {
  const { connectProvider, isLoading } = useAuth();
  const providers = ["apple", "google"] as const;

  return (
    <section className="account-section" aria-labelledby="account-methods-title">
      <h2 className="account-section-title" id="account-methods-title">Sign-In Methods</h2>
      <div className="account-section-card account-methods-card">
        <div className="account-provider-list">
          {providers.map((provider) => {
            const isConnected = connectedProviders.has(provider);
            const label = provider === "apple" ? "Apple" : "Google";
            return isConnected ? (
              <div className="account-list-row account-provider-row" key={provider}>
                <Icon name={provider} size={19} />
                <span><strong>{label}</strong><small>Connected to this account</small></span>
                <Icon name="check" size={18} />
              </div>
            ) : (
              <button
                className="account-list-row account-provider-row"
                key={provider}
                type="button"
                onClick={() => void connectProvider(provider)}
                disabled={isLoading}
                aria-label={`Connect ${label}`}
              >
                <Icon name={provider} size={19} />
                <span><strong>{label}</strong><small>Connect to this account</small></span>
                <Icon name="arrow-right" size={18} />
              </button>
            );
          })}
        </div>
      </div>
    </section>
  );
}
