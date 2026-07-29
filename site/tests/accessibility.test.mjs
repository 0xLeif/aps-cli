import assert from "node:assert/strict";
import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import { createServer } from "node:http";
import { extname, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import AxeBuilder from "@axe-core/playwright";
import { chromium } from "playwright";

const outputRoot = fileURLToPath(new URL("../out/", import.meta.url));
const contentTypes = new Map([
  [".css", "text/css"],
  [".html", "text/html; charset=utf-8"],
  [".js", "text/javascript"],
  [".png", "image/png"],
  [".svg", "image/svg+xml"],
]);

function serveExport() {
  return createServer(async (request, response) => {
    const url = new URL(request.url ?? "/", "http://127.0.0.1");
    let pathname = decodeURIComponent(url.pathname);
    if (pathname.startsWith("/aps-cli")) {
      pathname = pathname.slice("/aps-cli".length);
    }
    if (pathname === "/" || pathname === "") {
      pathname = "/index.html";
    }

    const file = resolve(outputRoot, `.${pathname}`);
    if (!file.startsWith(`${resolve(outputRoot)}${sep}`)) {
      response.writeHead(403).end();
      return;
    }

    try {
      const metadata = await stat(file);
      if (!metadata.isFile()) {
        throw new Error("not a file");
      }
      response.writeHead(200, {
        "content-type": contentTypes.get(extname(file)) ?? "application/octet-stream",
      });
      createReadStream(file).pipe(response);
    } catch {
      response.writeHead(404).end();
    }
  });
}

test("passes WCAG AA AXE checks in supported themes and viewports", async () => {
  const server = serveExport();
  await new Promise((resolveListen) => server.listen(0, "127.0.0.1", resolveListen));
  const address = server.address();
  assert.ok(address && typeof address === "object");

  const browser = await chromium.launch({ headless: true });
  try {
    const scenarios = [
      { name: "dark desktop", theme: "dark", width: 1440, height: 1000 },
      { name: "light desktop", theme: "light", width: 1440, height: 1000 },
      { name: "dark mobile", theme: "dark", width: 390, height: 844 },
    ];

    for (const scenario of scenarios) {
      const context = await browser.newContext({
        viewport: { width: scenario.width, height: scenario.height },
      });
      const page = await context.newPage();
      await page.goto(
        `http://127.0.0.1:${address.port}/aps-cli/?theme=${scenario.theme}`,
        { waitUntil: "networkidle" },
      );
      const results = await new AxeBuilder({ page })
        .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
        .analyze();
      assert.deepEqual(
        results.violations,
        [],
        `${scenario.name}: ${results.violations
          .map((violation) => `${violation.id}: ${violation.help}`)
          .join("; ")}`,
      );
      await context.close();
    }
  } finally {
    await browser.close();
    await new Promise((resolveClose, rejectClose) =>
      server.close((error) => (error ? rejectClose(error) : resolveClose())),
    );
  }
});
