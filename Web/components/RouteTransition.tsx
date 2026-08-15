"use client";

import { usePathname } from "next/navigation";
import { useEffect, useRef, useState, type ReactNode } from "react";

type TransitionDirection = "initial" | "forward" | "back";

export function RouteTransition({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const previousPathname = useRef(pathname);
  const pendingDirection = useRef<Exclude<TransitionDirection, "initial"> | null>(null);
  const [transition, setTransition] = useState<{ pathname: string; direction: TransitionDirection }>({
    pathname,
    direction: "initial",
  });

  useEffect(() => {
    const handlePopState = () => {
      pendingDirection.current = "back";
    };

    window.addEventListener("popstate", handlePopState);
    return () => window.removeEventListener("popstate", handlePopState);
  }, []);

  useEffect(() => {
    const previous = previousPathname.current;
    if (previous === pathname) return;

    const direction =
      pendingDirection.current ?? (routeDepth(pathname) < routeDepth(previous) ? "back" : "forward");

    previousPathname.current = pathname;
    pendingDirection.current = null;
    setTransition({ pathname, direction });
  }, [pathname]);

  return (
    <div className={`route-transition route-transition-${transition.direction}`} key={transition.pathname}>
      {children}
    </div>
  );
}

function routeDepth(pathname: string) {
  if (pathname === "/") return 0;
  if (/^\/todos\/[^/]+/.test(pathname) || pathname === "/account/profile" || pathname.startsWith("/settings/")) {
    return 2;
  }
  return 1;
}
