#!/usr/bin/env node
// Headless render + JS-error check for any local viz HTML.
// Uses the locally-pinned Playwright (devDependency), so it survives nvm churn.
//
//   node render.mjs <input.html> [output.png] [--wait=900] [--w=1280] [--h=900]
//
// Exit code is non-zero if the page logged any console error or threw, so this
// doubles as a CI smoke test for visualizations.
import { chromium } from "playwright";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const argv = process.argv.slice(2);
const flags = Object.fromEntries(
  argv.filter(a => a.startsWith("--")).map(a => {
    const [k, v = "true"] = a.replace(/^--/, "").split("=");
    return [k, v];
  })
);
const pos = argv.filter(a => !a.startsWith("--"));
const input = pos[0];
if (!input) {
  console.error("usage: node render.mjs <input.html> [output.png] [--wait=ms] [--w=px] [--h=px]");
  process.exit(2);
}
const output = pos[1] || input.replace(/\.html?$/i, "") + ".png";
const wait = Number(flags.wait ?? 900);
const width = Number(flags.w ?? 1280);
const height = Number(flags.h ?? 900);

const errs = [];
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width, height } });
page.on("console", m => { if (m.type() === "error") errs.push(m.text()); });
page.on("pageerror", e => errs.push("PAGEERR: " + e.message));

await page.goto(pathToFileURL(resolve(input)).href);
await page.waitForTimeout(wait);
await page.screenshot({ path: resolve(output) });
await browser.close();

console.log("input:   ", input);
console.log("output:  ", output);
console.log("errors:  ", JSON.stringify(errs));
console.log(errs.length ? "RENDERED WITH ERRORS" : "rendered (clean)");
process.exit(errs.length ? 1 : 0);
