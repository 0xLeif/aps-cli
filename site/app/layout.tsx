import type { Metadata } from "next";
import { headers } from "next/headers";
import "./globals.css";

export async function generateMetadata(): Promise<Metadata> {
  const incomingHeaders = await headers();
  const host =
    incomingHeaders.get("x-forwarded-host") ??
    incomingHeaders.get("host") ??
    "localhost:3000";
  const protocol =
    incomingHeaders.get("x-forwarded-proto") ??
    (host.startsWith("localhost") ? "http" : "https");
  const origin = `${protocol}://${host}`;
  const title = "aps | Swift state in your terminal";
  const description =
    "A tiny Swift CLI for declaring, reading, changing, and watching AppState outside SwiftUI.";

  return {
    title,
    description,
    openGraph: {
      title,
      description:
        "State you can see. Contracts you can trust. A Swift CLI powered by AppState.",
      type: "website",
      images: [
        {
          url: `${origin}/og.png`,
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
      images: [`${origin}/og.png`],
    },
  };
}

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
