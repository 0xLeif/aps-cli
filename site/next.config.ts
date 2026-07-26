import type { NextConfig } from "next";

const isGitHubPages = process.env.GITHUB_PAGES === "true";

const nextConfig: NextConfig = isGitHubPages
  ? {
      output: "export",
      basePath: "/aps-cli",
      trailingSlash: true,
      images: {
        unoptimized: true,
      },
    }
  : {};

export default nextConfig;
