"use client";

import type { WebProvider } from "@/lib/supabase";
import { Icon } from "@/components/Icon";

export function ProviderMethodsCard({
  connectedProviders,
  linkingProvider,
  error,
  onConnect,
}: {
  connectedProviders: Set<string>;
  linkingProvider: WebProvider | null;
  error: string | null;
  onConnect: (provider: WebProvider) => Promise<void>;
}) {
  const availableProviders = (["apple", "google"] as const).filter(
    (provider) => !connectedProviders.has(provider),
  );

  return (
    <section className="account-section" aria-labelledby="account-methods-title">
      <h2 className="account-section-title" id="account-methods-title">Sign-In Methods</h2>
      <div className="account-section-card account-methods-card">
        <div>
          <p>Connect another provider only when you want both sign-ins to open this same account.</p>
        </div>
        <div>
          {availableProviders.length > 0 ? (
            <div className="account-method-actions">
              {availableProviders.map((provider) => (
                <button
                  className="secondary-button"
                  key={provider}
                  type="button"
                  onClick={() => void onConnect(provider)}
                  disabled={linkingProvider !== null}
                >
                  {linkingProvider === provider ? "Opening…" : <><Icon name={provider} size={16} /> Connect {provider === "apple" ? "Apple" : "Google"}</>}
                </button>
              ))}
            </div>
          ) : (
            <p className="account-methods-connected">Apple and Google are connected.</p>
          )}
          {error ? <p className="inline-error" role="alert">{error}</p> : null}
        </div>
      </div>
    </section>
  );
}
