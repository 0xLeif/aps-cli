"use client";

import { useEffect, useState } from "react";

type Theme = "dark" | "light";

const storageKey = "0x-theme";

function currentTheme(): Theme {
  if (document.documentElement.dataset.theme === "light") {
    return "light";
  }
  if (document.documentElement.dataset.theme === "dark") {
    return "dark";
  }
  return window.matchMedia("(prefers-color-scheme: light)").matches
    ? "light"
    : "dark";
}

export function ThemeToggle() {
  const [theme, setTheme] = useState<Theme>("dark");

  useEffect(() => {
    const media = window.matchMedia("(prefers-color-scheme: light)");
    const reflect = () => setTheme(currentTheme());

    reflect();
    media.addEventListener("change", reflect);
    return () => media.removeEventListener("change", reflect);
  }, []);

  const toggle = () => {
    const nextTheme = currentTheme() === "dark" ? "light" : "dark";
    document.documentElement.dataset.theme = nextTheme;
    try {
      window.localStorage.setItem(storageKey, nextTheme);
    } catch {
      // The visible choice still applies when storage is unavailable.
    }
    setTheme(nextTheme);
  };

  const dark = theme === "dark";

  return (
    <button
      type="button"
      className="ox-theme-toggle"
      data-ox-theme-toggle
      aria-pressed={dark}
      aria-label={dark ? "Switch to light theme" : "Switch to dark theme"}
      title="Switch theme"
      onClick={toggle}
      suppressHydrationWarning
    >
      <svg
        className="sun"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden="true"
      >
        <circle cx="12" cy="12" r="4.2" />
        <path d="M12 2.6v2.4M12 19v2.4M4.2 4.2l1.7 1.7M18.1 18.1l1.7 1.7M2.6 12h2.4M19 12h2.4M4.2 19.8l1.7-1.7M18.1 5.9l1.7-1.7" />
      </svg>
      <svg
        className="moon"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden="true"
      >
        <path d="M21 12.8A8.6 8.6 0 1 1 11.2 3a6.7 6.7 0 0 0 9.8 9.8z" />
      </svg>
    </button>
  );
}
