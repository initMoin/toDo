import type { Metadata } from "next";
import { RouteTransition } from "@/components/RouteTransition";
import "./globals.css";

export const metadata: Metadata = {
  title: "toDō Web — Keep what matters in step",
  description:
    "A focused web companion for your synced toDōs, NanoDos, tags, and Collabs.",
  metadataBase: new URL("https://do.yourtodo.today"),
  openGraph: {
    title: "toDō Web — Keep what matters in step",
    description:
      "Your synced toDōs, NanoDos, tags, and Collabs in a focused web view.",
    url: "https://do.yourtodo.today",
    siteName: "toDō Web",
    type: "website",
  },
  twitter: {
    card: "summary",
    title: "toDō Web",
    description: "Keep what matters in step.",
  },
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
  manifest: "/manifest.webmanifest",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body><RouteTransition>{children}</RouteTransition></body>
    </html>
  );
}
