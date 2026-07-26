import type { Metadata } from "next";
import "./globals.css";

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
        url: `${siteOrigin}/og.png`,
        width: 1731,
        height: 909,
        alt: "aps: State you can see. Contracts you can trust.",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title,
    description:
      "State you can see. Contracts you can trust. A Swift CLI powered by AppState.",
    images: [`${siteOrigin}/og.png`],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
