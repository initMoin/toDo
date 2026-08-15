import { AppFrame } from "@/components/AppFrame";
import { Stats } from "@/features/stats/Stats";

export default function StatsPage() {
  return (
    <AppFrame mode="stats">
      <Stats />
    </AppFrame>
  );
}
