import { AppFrame } from "@/components/AppFrame";
import { SettingsSubmenuView } from "@/features/settings/SettingsSubmenuView";

export default function SyncPage() {
  return <AppFrame mode="settings-detail" title="sync"><SettingsSubmenuView kind="sync" /></AppFrame>;
}
