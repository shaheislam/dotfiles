/**
 * linkedin-helpers.mjs
 *
 * Shared Playwright helpers for LinkedIn automation.
 * Handles session loading, connection request sending, and scrolling.
 */

import { chromium } from "playwright";
import { existsSync } from "node:fs";
import { CONFIG, humanDelay } from "./config.mjs";

/**
 * Launches a browser with a saved LinkedIn session.
 * Returns { context, page }.
 */
export async function launchWithSession() {
  if (!existsSync(CONFIG.sessionDir)) {
    console.error(
      "No saved session found. Run 'node save-session.mjs' first."
    );
    process.exit(1);
  }

  const context = await chromium.launchPersistentContext(CONFIG.sessionDir, {
    headless: CONFIG.browser.headless,
    slowMo: CONFIG.browser.slowMo,
    viewport: { width: 1280, height: 900 },
    userAgent:
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  });

  const page = context.pages()[0] || (await context.newPage());
  return { context, page };
}

/**
 * Verifies we are logged into LinkedIn by checking for the feed or nav.
 */
export async function verifyLoggedIn(page) {
  await page.goto("https://www.linkedin.com/feed/", {
    waitUntil: "domcontentloaded",
  });
  await humanDelay(page, CONFIG.delays.afterPageLoad);

  const isLoggedIn = await page
    .locator('nav[aria-label="Primary"]')
    .isVisible()
    .catch(() => false);

  if (!isLoggedIn) {
    const onLoginPage = page.url().includes("/login");
    if (onLoginPage) {
      console.error("Session expired. Run 'node save-session.mjs' to re-login.");
      process.exit(1);
    }
  }

  console.log("Logged in to LinkedIn.");
}

/**
 * Scrolls the page to load more content (infinite scroll).
 * Returns true if new content was loaded.
 */
export async function scrollToLoadMore(page) {
  const prevHeight = await page.evaluate("document.body.scrollHeight");
  await page.evaluate("window.scrollTo(0, document.body.scrollHeight)");
  await humanDelay(page, CONFIG.delays.scrollPause);
  const newHeight = await page.evaluate("document.body.scrollHeight");
  return newHeight > prevHeight;
}

/**
 * Sends a connection request to a LinkedIn profile URL.
 * Returns { success, name, reason }.
 */
export async function sendConnectionRequest(page, profileUrl) {
  const result = { success: false, name: "", reason: "" };

  try {
    await page.goto(profileUrl, { waitUntil: "domcontentloaded" });
    await humanDelay(page, CONFIG.delays.afterPageLoad);

    // Extract the person's name
    const nameEl = page.locator("h1.text-heading-xlarge").first();
    result.name = (await nameEl.textContent().catch(() => "Unknown")).trim();

    if (CONFIG.dryRun) {
      result.success = true;
      result.reason = "dry-run";
      return result;
    }

    // Look for the Connect button in the main profile actions
    const connectButton = page.locator('button:has-text("Connect")').first();
    const connectVisible = await connectButton.isVisible().catch(() => false);

    if (!connectVisible) {
      // Try the "More" dropdown — Connect might be hidden there
      const moreButton = page
        .locator('button[aria-label="More actions"], button:has-text("More")')
        .first();
      const moreVisible = await moreButton.isVisible().catch(() => false);

      if (moreVisible) {
        await humanDelay(page, CONFIG.delays.beforeClick);
        await moreButton.click();
        await humanDelay(page, CONFIG.delays.beforeClick);

        const dropdownConnect = page
          .locator('div[data-test-icon="connect"] span, span:has-text("Connect")')
          .first();
        const dropdownConnectVisible = await dropdownConnect
          .isVisible()
          .catch(() => false);

        if (!dropdownConnectVisible) {
          result.reason = "no-connect-button";
          return result;
        }

        await dropdownConnect.click();
      } else {
        // Check if already connected or pending
        const isPending = await page
          .locator('button:has-text("Pending")')
          .first()
          .isVisible()
          .catch(() => false);

        if (isPending) {
          result.reason = "already-pending";
          return result;
        }

        const isConnected = await page
          .locator('button:has-text("Message")')
          .first()
          .isVisible()
          .catch(() => false);

        if (isConnected) {
          result.reason = "already-connected";
          return result;
        }

        result.reason = "no-connect-button";
        return result;
      }
    } else {
      await humanDelay(page, CONFIG.delays.beforeClick);
      await connectButton.click();
    }

    // Handle the "Add a note" dialog if it appears
    await page.waitForTimeout(1000);

    const dialogVisible = await page
      .locator('div[role="dialog"], div[data-test-modal]')
      .isVisible()
      .catch(() => false);

    if (dialogVisible) {
      if (CONFIG.connectionNote) {
        const addNoteBtn = page.locator('button:has-text("Add a note")').first();
        const addNoteVisible = await addNoteBtn.isVisible().catch(() => false);

        if (addNoteVisible) {
          await addNoteBtn.click();
          await humanDelay(page, CONFIG.delays.beforeClick);

          const noteTextarea = page.locator(
            'textarea[name="message"], textarea#custom-message'
          );
          await noteTextarea.fill(CONFIG.connectionNote);
          await humanDelay(page, CONFIG.delays.beforeClick);
        }
      }

      // Click Send
      const sendBtn = page
        .locator(
          'button[aria-label="Send invitation"], button[aria-label="Send now"], button:has-text("Send")'
        )
        .first();
      const sendVisible = await sendBtn.isVisible().catch(() => false);

      if (sendVisible) {
        await sendBtn.click();
      }
    }

    result.success = true;
    result.reason = "sent";
    return result;
  } catch (err) {
    result.reason = `error: ${err.message}`;
    return result;
  }
}

/**
 * Extracts profile URLs from a list of LinkedIn profile links on the current page.
 */
export async function extractProfileUrls(page, selector) {
  const links = await page.locator(selector).all();
  const hrefs = [];

  for (const link of links) {
    const href = await link.getAttribute("href").catch(() => null);
    if (href && href.includes("linkedin.com/in/") && !href.includes("/in/ACo")) {
      const url = new URL(href, "https://www.linkedin.com");
      hrefs.push(`${url.origin}${url.pathname}`.replace(/\/$/, ""));
    }
  }

  return [...new Set(hrefs)];
}

/**
 * Processes a list of profile URLs and sends connection requests.
 * Respects rate limits and provides a summary.
 */
export async function processProfiles(page, profileUrls, source) {
  const limit = CONFIG.maxConnectionsPerRun;
  const toProcess = profileUrls.slice(0, limit);
  const results = { sent: 0, skipped: 0, errors: 0, details: [] };

  console.log(
    `\nProcessing ${toProcess.length} profiles from ${source}${
      CONFIG.dryRun ? " (DRY RUN)" : ""
    }...`
  );

  for (let i = 0; i < toProcess.length; i++) {
    const url = toProcess[i];
    console.log(`  [${i + 1}/${toProcess.length}] ${url}`);

    const result = await sendConnectionRequest(page, url);
    results.details.push({ url, ...result });

    if (result.success) {
      results.sent++;
      console.log(`    -> ${result.name}: ${result.reason}`);
    } else {
      if (
        result.reason === "already-connected" ||
        result.reason === "already-pending"
      ) {
        results.skipped++;
      } else {
        results.errors++;
      }
      console.log(`    -> SKIP: ${result.reason}`);
    }

    if (i < toProcess.length - 1) {
      await humanDelay(page, CONFIG.delays.betweenConnections);
    }
  }

  console.log(`\n--- ${source} Summary ---`);
  console.log(`  Sent: ${results.sent}`);
  console.log(`  Skipped: ${results.skipped}`);
  console.log(`  Errors: ${results.errors}`);

  return results;
}
