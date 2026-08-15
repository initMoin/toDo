import { AppFrame } from "@/components/AppFrame";
import { SettingsSubmenuView } from "@/features/settings/SettingsSubmenuView";

export default function TagsPage() {
  return <AppFrame mode="settings-detail" title="tags"><SettingsSubmenuView kind="tags" /></AppFrame>;
}
