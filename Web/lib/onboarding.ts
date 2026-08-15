export type OnboardingStep = "detail" | "settings";

export const onboardingStorageKey = "todo.web.onboarding.v1";

export function readOnboardingStep(): OnboardingStep | null {
  if (typeof window === "undefined") return null;
  const value = window.localStorage.getItem(onboardingStorageKey);
  return value === "detail" || value === "settings" ? value : null;
}

export function saveOnboardingStep(step: OnboardingStep) {
  if (typeof window !== "undefined") {
    window.localStorage.setItem(onboardingStorageKey, step);
  }
}

export function clearOnboarding() {
  if (typeof window !== "undefined") {
    window.localStorage.removeItem(onboardingStorageKey);
  }
}

export function subscribeToOnboarding(listener: () => void) {
  if (typeof window === "undefined") return () => {};
  const handleStorage = (event: StorageEvent) => {
    if (event.key === onboardingStorageKey) listener();
  };
  window.addEventListener("storage", handleStorage);
  return () => window.removeEventListener("storage", handleStorage);
}
