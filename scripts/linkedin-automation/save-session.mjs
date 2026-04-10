#!/usr/bin/env node
/**
 * save-session.mjs
 *
 * Opens a browser so you can log in to LinkedIn manually.
 * Saves the authenticated session to disk for reuse by automation scripts.
 *
 * Usage: node save-session.mjs
 */

import { chromium } from "playwright";
import { mkdirSync } from "node:fs";
import { CONFIG } from "./config.mjs";

async function main() {
  mkdirSync(CONFIG.sessionDir, { recursive: true });

  console.log("Opening browser — please log in to LinkedIn...");
  console.log(`Session will be saved to: ${CONFIG.sessionDir}`);

  const context = await chromium.launchPersistentContext(CONFIG.sessionDir, {
    headless: false,
    viewport: { width: 1280, height: 900 },
    userAgent:
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  });

  const page = context.pages()[0] || (await context.newPage());
  await page.goto("https://www.linkedin.com/login");

  console.log("\n---");
  console.log("Log in to LinkedIn in the browser window.");
  console.log("Once you see your feed, press Ctrl+C here to save the session.");
  console.log("---\n");

  // Keep the browser open until the user closes it or presses Ctrl+C
  await new Promise((resolve) => {
    process.on("SIGINT", resolve);
    context.on("close", resolve);
  });

  await context.close();
  console.log("Session saved successfully.");
}

main().catch((err) => {
  console.error("Error:", err.message);
  process.exit(1);
});
