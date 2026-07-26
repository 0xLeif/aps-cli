import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import test from "node:test";

const outputRoot = new URL("../out/", import.meta.url);

test("exports a GitHub Pages artifact under the aps-cli base path", async () => {
  const [html] = await Promise.all([
    readFile(new URL("index.html", outputRoot), "utf8"),
    access(new URL("og.png", outputRoot)),
  ]);

  assert.match(html, /<title>aps \| Swift state in your terminal<\/title>/i);
  assert.match(html, /\/aps-cli\/_next\//);
  assert.match(html, /https:\/\/0xleif\.github\.io\/aps-cli\/og\.png/);
  assert.doesNotMatch(html, /localhost:3000|chatgpt\.site/);
});
