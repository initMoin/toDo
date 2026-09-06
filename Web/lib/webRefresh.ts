export function subscribeToWebRefresh(onRefresh: () => void): () => void {
  if (typeof window === "undefined") return () => {};

  const refreshWhenActive = () => {
    if (document.visibilityState === "hidden") return;
    onRefresh();
  };

  window.addEventListener("focus", refreshWhenActive);
  window.addEventListener("online", refreshWhenActive);
  document.addEventListener("visibilitychange", refreshWhenActive);
  window.addEventListener("pageshow", refreshWhenActive);

  return () => {
    window.removeEventListener("focus", refreshWhenActive);
    window.removeEventListener("online", refreshWhenActive);
    document.removeEventListener("visibilitychange", refreshWhenActive);
    window.removeEventListener("pageshow", refreshWhenActive);
  };
}
