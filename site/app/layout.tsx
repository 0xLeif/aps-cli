/* eslint-disable @next/next/no-page-custom-font */
import type { Metadata } from "next";
import "./globals.css";

const themePrePaint = `
(() => {
  try {
    const query = new URLSearchParams(location.search).get("theme");
    const theme = query || localStorage.getItem("0x-theme");
    if (theme === "light" || theme === "dark") {
      document.documentElement.dataset.theme = theme;
    }
  } catch {}
})();
`;

const siteOrigin = (
  process.env.NEXT_PUBLIC_SITE_ORIGIN ??
  "https://aps-swift-state.goofy-bat-3251.chatgpt.site"
).replace(/\/$/, "");

const title = "aps | Swift state in your terminal";
const description =
  "A tiny Swift CLI for declaring, reading, changing, and watching AppState outside SwiftUI.";

export const metadata: Metadata = {
  metadataBase: new URL(siteOrigin),
  title,
  description,
  alternates: {
    canonical: siteOrigin,
  },
  openGraph: {
    title,
    description:
      "State you can see. Contracts you can trust. A Swift CLI powered by AppState.",
    type: "website",
    url: siteOrigin,
    images: [
      {
        url: `${siteOrigin}/og-0x.png`,
        width: 1734,
        height: 907,
        alt: "aps: State you can see. Contracts you can trust.",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title,
    description:
      "State you can see. Contracts you can trust. A Swift CLI powered by AppState.",
    images: [`${siteOrigin}/og-0x.png`],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themePrePaint }} />
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="" />
        <link
          href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600&family=Righteous&display=swap"
          rel="stylesheet"
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
