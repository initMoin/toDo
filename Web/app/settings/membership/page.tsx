import { AppFrame } from "@/components/AppFrame";
import { SettingsSubmenuView } from "@/features/settings/SettingsSubmenuView";

export default function MembershipPage() {
  return <AppFrame mode="settings-detail" title="toDō+"><SettingsSubmenuView kind="membership" /></AppFrame>;
}
