import { AppFrame } from "@/components/AppFrame";
import { Home } from "@/features/home/Home";

export default function HomePage() {
  return (
    <AppFrame mode="home">
      <Home />
    </AppFrame>
  );
}
