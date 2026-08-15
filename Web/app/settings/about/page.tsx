import { AppFrame } from "@/components/AppFrame";
import { AboutView } from "@/features/settings/AboutView";

export default function AboutPage() {
  return (
    <AppFrame mode="settings-detail">
      <AboutView />
    </AppFrame>
  );
}
