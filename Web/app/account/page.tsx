import { AppFrame } from "@/components/AppFrame";
import { AccountView } from "@/features/account/AccountView";

export default async function AccountPage({
  searchParams,
}: {
  searchParams?: Promise<{ from?: string }> | { from?: string };
}) {
  const params = await searchParams;
  const fromSettings = params?.from === "settings";

  return (
    <AppFrame mode={fromSettings ? "account-settings" : "account"}>
      <AccountView fromSettings={fromSettings} />
    </AppFrame>
  );
}
