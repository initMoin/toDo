import { AppFrame } from "@/components/AppFrame";
import { ReleaseHistoryView } from "@/features/settings/ReleaseHistoryView";

export default function ReleaseHistoryPage() {
  return (
    <AppFrame mode="settings-releases">
      <ReleaseHistoryView />
    </AppFrame>
  );
}
