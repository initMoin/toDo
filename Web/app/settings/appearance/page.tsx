import { AppFrame } from "@/components/AppFrame";
import { SettingsSubmenuView } from "@/features/settings/SettingsSubmenuView";

export default function AppearancePage() {
  return <AppFrame mode="settings-detail" title="appearance"><SettingsSubmenuView kind="appearance" /></AppFrame>;
}
