import { AppFrame } from "@/components/AppFrame";
import { SettingsSubmenuView } from "@/features/settings/SettingsSubmenuView";

export default function GuidedTourPage() {
  return <AppFrame mode="settings-detail" title="guided tour"><SettingsSubmenuView kind="tour" /></AppFrame>;
}
