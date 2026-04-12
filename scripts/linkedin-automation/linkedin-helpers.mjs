/**
 * linkedin-helpers.mjs
 *
 * Shared Playwright helpers for LinkedIn automation.
 * Handles session loading, connection request sending, and scrolling.
 */

import { chromium } from "playwright";
import { existsSync } from "node:fs";
import { CONFIG, humanDelay } from "./config.mjs";

const SOURCE_PRIORITY = {
  commenter: 3,
  profileViewer: 2,
  liker: 1,
  unknown: 0,
};

function getSourcePriority(source) {
  return SOURCE_PRIORITY[source] ?? SOURCE_PRIORITY.unknown;
}

function getFirstName(name) {
  const [firstName] = (name || "").trim().split(/\s+/);
  return firstName || "there";
}

function buildConnectionNote(source, name) {
  const templates = CONFIG.connectionNotes || {};
  const template = templates[source] ?? templates.default;

  if (!template) return null;

  return template.replaceAll("{firstName}", getFirstName(name));
}

function normalizeProfile(profile) {
  if (typeof profile === "string") {
    return { url: profile, source: "unknown" };
  }

  return {
    url: profile.url,
    source: profile.source || "unknown",
  };
}

function isPageClosedError(error) {
  return /Target page, context or browser has been closed/i.test(
    error?.message || ""
  );
}

async function ensureActivePage(context, currentPage) {
  if (currentPage && !currentPage.isClosed()) {
    return currentPage;
  }

  const availablePage = context.pages().find((page) => !page.isClosed());
  return availablePage || context.newPage();
}

async function clickFirstVisible(locator) {
  const count = await locator.count().catch(() => 0);

  for (let i = 0; i < count; i++) {
    const candidate = locator.nth(i);
    const visible = await candidate.isVisible().catch(() => false);
    if (!visible) continue;

    await candidate.click();
    return true;
  }

  return false;
}

async function getProfileName(page) {
  const selectors = [
    "h1.text-heading-xlarge",
    "main h1",
    ".pv-text-details__left-panel h1",
  ];

  for (const selector of selectors) {
    const text = await page.locator(selector).first().textContent().catch(() => null);
    if (text?.trim()) return text.trim();
  }

  return "Unknown";
}

async function hasVisibleAction(page, selectors) {
  for (const selector of selectors) {
    const visible = await page.locator(selector).first().isVisible().catch(() => false);
    if (visible) return true;
  }

  return false;
}

export function mergeProfiles(existingProfile, nextProfile) {
  if (!existingProfile) return nextProfile;

  return getSourcePriority(nextProfile.source) > getSourcePriority(existingProfile.source)
    ? nextProfile
    : existingProfile;
}

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
export async function sendConnectionRequest(page, profile) {
  const { url: profileUrl, source } = normalizeProfile(profile);
  const result = { success: false, name: "", reason: "", source };

  try {
    await page.goto(profileUrl, { waitUntil: "domcontentloaded" });
    await humanDelay(page, CONFIG.delays.afterPageLoad);

    // Extract the person's name
    result.name = await getProfileName(page);

    const isPending = await hasVisibleAction(page, [
      'button:has-text("Pending")',
      'button[aria-label*="Pending"]',
    ]);

    if (isPending) {
      result.reason = "already-pending";
      return result;
    }

    const hasConnectAction = await hasVisibleAction(page, [
      'main button:has-text("Connect")',
      'button[aria-label^="Invite "]',
      'button[aria-label*="invite"]',
    ]);

    const isConnected =
      !hasConnectAction &&
      (await hasVisibleAction(page, [
        'main button:has-text("Message")',
        'main a:has-text("Message")',
        'button[aria-label^="Message "]',
      ]));

    if (isConnected) {
      result.reason = "already-connected";
      return result;
    }

    const isFollowOnly =
      !hasConnectAction &&
      (await hasVisibleAction(page, [
        'main button:has-text("Follow")',
        'main button:has-text("Following")',
      ]));

    if (isFollowOnly) {
      result.reason = "follow-only";
      return result;
    }

    if (CONFIG.dryRun) {
      result.success = true;
      result.reason = "dry-run";
      return result;
    }

    // Look for the Connect button in the main profile actions
    const connectButton = page.locator(
      'main button:has-text("Connect"), button[aria-label^="Invite "], button[aria-label*="invite"]'
    );
    const connectVisible = await connectButton.first().isVisible().catch(() => false);

    if (!connectVisible) {
      // Try the "More" dropdown — Connect might be hidden there
      const moreButton = page
        .locator(
          'main button[aria-label="More actions"], main button[aria-label*="More actions for"], main button:has-text("More")'
        )
        .first();
      const moreVisible = await moreButton.isVisible().catch(() => false);

      if (moreVisible) {
        await humanDelay(page, CONFIG.delays.beforeClick);
        await moreButton.click();
        await humanDelay(page, CONFIG.delays.beforeClick);

        const clickedConnect = await clickFirstVisible(
          page.locator(
            '[role="menu"] div[role="button"]:has-text("Connect"), [role="menu"] span:has-text("Connect"), div.artdeco-dropdown__content-inner span:has-text("Connect")'
          )
        );

        if (!clickedConnect) {
          result.reason = "no-connect-button";
          return result;
        }
      } else {
        result.reason = "no-connect-button";
        return result;
      }
    } else {
      await humanDelay(page, CONFIG.delays.beforeClick);
      await connectButton.first().click();
    }

    // Handle the "Add a note" dialog if it appears
    await humanDelay(page, CONFIG.delays.beforeClick);

    const dialogVisible = await page
      .locator('div[role="dialog"], div[data-test-modal]')
      .isVisible()
      .catch(() => false);

    if (!dialogVisible) {
      result.reason = "invite-dialog-missing";
      return result;
    }

    const connectionNote = buildConnectionNote(source, result.name);

    if (connectionNote) {
      const addNoteBtn = page.locator('button:has-text("Add a note")').first();
      const addNoteVisible = await addNoteBtn.isVisible().catch(() => false);

      if (addNoteVisible) {
        await addNoteBtn.click();
        await humanDelay(page, CONFIG.delays.beforeClick);

        const noteTextarea = page.locator(
          'textarea[name="message"], textarea#custom-message'
        );
        const noteVisible = await noteTextarea.isVisible().catch(() => false);
        if (noteVisible) {
          await noteTextarea.fill(connectionNote);
          await humanDelay(page, CONFIG.delays.beforeClick);
        }
      }
    }

    const sendBtn = page
      .locator(
        'div[role="dialog"] button[aria-label="Send invitation"], div[role="dialog"] button[aria-label="Send now"], div[role="dialog"] button:has-text("Send")'
      )
      .first();
    const sendVisible = await sendBtn.isVisible().catch(() => false);

    if (!sendVisible) {
      result.reason = "send-button-missing";
      return result;
    }

    await sendBtn.click();
    await humanDelay(page, CONFIG.delays.beforeClick);

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
    if (href && href.includes("/in/")) {
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
export async function processProfiles(context, page, profileUrls, source) {
  const limit = CONFIG.maxConnectionsPerRun;
  const toProcess = profileUrls.slice(0, limit).map(normalizeProfile);
  const results = { sent: 0, skipped: 0, errors: 0, details: [] };

  console.log(
    `\nProcessing ${toProcess.length} profiles from ${source}${
      CONFIG.dryRun ? " (DRY RUN)" : ""
    }...`
  );

  for (let i = 0; i < toProcess.length; i++) {
    const profile = toProcess[i];
    page = await ensureActivePage(context, page);
    console.log(
      `  [${i + 1}/${toProcess.length}] ${profile.url} (${profile.source})`
    );

    const result = await sendConnectionRequest(page, profile);
    results.details.push({ url: profile.url, ...result });

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
      try {
        await humanDelay(page, CONFIG.delays.betweenConnections);
      } catch (error) {
        if (!isPageClosedError(error)) {
          throw error;
        }
      }
    }
  }

  console.log(`\n--- ${source} Summary ---`);
  console.log(`  Sent: ${results.sent}`);
  console.log(`  Skipped: ${results.skipped}`);
  console.log(`  Errors: ${results.errors}`);

  return results;
}
