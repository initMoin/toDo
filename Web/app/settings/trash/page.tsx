import { AppFrame } from "@/components/AppFrame";
import { SettingsSubmenuView } from "@/features/settings/SettingsSubmenuView";

export default function TrashPage() {
  return <AppFrame mode="settings-detail" title="trash"><SettingsSubmenuView kind="trash" /></AppFrame>;
}
