import { AppFrame } from "@/components/AppFrame";
import { SettingsSubmenuView } from "@/features/settings/SettingsSubmenuView";

export default function DataControlsPage() {
  return <AppFrame mode="settings-detail" title="data controls"><SettingsSubmenuView kind="data" /></AppFrame>;
}
