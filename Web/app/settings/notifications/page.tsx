import { AppFrame } from "@/components/AppFrame";
import { SettingsSubmenuView } from "@/features/settings/SettingsSubmenuView";

export default function NotificationsPage() {
  return <AppFrame mode="settings-detail" title="notifications"><SettingsSubmenuView kind="notifications" /></AppFrame>;
}
