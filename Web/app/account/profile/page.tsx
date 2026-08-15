import { AppFrame } from "@/components/AppFrame";
import { ProfileView } from "@/features/account/ProfileView";

export default async function ProfilePage({
  searchParams,
}: {
  searchParams?: Promise<{ from?: string }> | { from?: string };
}) {
  const params = await searchParams;
  const fromSettings = params?.from === "settings";

  return (
    <AppFrame mode={fromSettings ? "account-profile-settings" : "account-profile"}>
      <ProfileView />
    </AppFrame>
  );
}
