import { AppFrame } from "@/components/AppFrame";
import { Settings } from "@/features/settings/Settings";

export default async function SettingsPage({
  searchParams,
}: {
  searchParams?: Promise<{ onboarding?: string }> | { onboarding?: string };
}) {
  const params = await searchParams;

  return (
    <AppFrame mode="settings">
      <Settings onboarding={params?.onboarding === "settings"} />
    </AppFrame>
  );
}
