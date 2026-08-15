import { AppFrame } from "@/components/AppFrame";
import { SettingsSubmenuView } from "@/features/settings/SettingsSubmenuView";

export default function BehaviorPage() {
  return <AppFrame mode="settings-detail" title="behavior"><SettingsSubmenuView kind="behavior" /></AppFrame>;
}
