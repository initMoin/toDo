import { AppFrame } from "@/components/AppFrame";
import { SettingsSubmenuView } from "@/features/settings/SettingsSubmenuView";

export default function ArchivesPage() {
  return <AppFrame mode="settings-detail" title="archives"><SettingsSubmenuView kind="archives" /></AppFrame>;
}
