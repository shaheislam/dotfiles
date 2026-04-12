#!/usr/bin/env node
/**
 * connect-profile-viewers.mjs
 *
 * Finds people who have viewed your LinkedIn profile,
 * then sends them connection requests.
 *
 * Usage:
 *   node connect-profile-viewers.mjs
 *   DRY_RUN=1 node connect-profile-viewers.mjs
 *
 * Note: LinkedIn only shows profile viewers to Premium members
 * or allows limited views for free accounts.
 *
 * Requires: Run save-session.mjs first to authenticate.
 */

import { CONFIG, humanDelay } from "./config.mjs";
import {
  launchWithSession,
  verifyLoggedIn,
  scrollToLoadMore,
  extractProfileUrls,
  processProfiles,
} from "./linkedin-helpers.mjs";

async function getProfileViewers(page) {
  // Navigate to the "Who viewed your profile" page
  await page.goto(
    "https://www.linkedin.com/me/profile-views/",
    { waitUntil: "domcontentloaded" }
  );
  await humanDelay(page, CONFIG.delays.afterPageLoad);

  // Check if we have access (Premium feature for full list)
  const noAccess = await page
    .locator('text="Upgrade to Premium"')
    .isVisible()
    .catch(() => false);

  if (noAccess) {
    console.log(
      "Note: Full profile viewer list requires LinkedIn Premium."
    );
    console.log("Extracting available viewers...");
  }

  // Scroll to load more viewers
  for (let i = 0; i < 5; i++) {
    const loaded = await scrollToLoadMore(page);
    if (!loaded) break;
  }

  // Extract viewer profile links
  // LinkedIn shows viewers in a list with profile links
  const profileUrls = await extractProfileUrls(
    page,
    'a[href*="/in/"]'
  );

  // Filter out our own profile and navigation links
  const myProfileUrl = await page
    .locator('a[href*="/in/"][data-test-app-aware-link]')
    .first()
    .getAttribute("href")
    .catch(() => "");

  const mySlug = myProfileUrl
    ? new URL(myProfileUrl, "https://www.linkedin.com").pathname
    : "";

  return profileUrls.filter(
    (url) => !url.includes(mySlug) || mySlug === ""
  );
}

async function main() {
  const { context, page } = await launchWithSession();

  try {
    await verifyLoggedIn(page);

    console.log("Finding people who viewed your profile...");
    const viewerUrls = await getProfileViewers(page);
    console.log(`Found ${viewerUrls.length} profile viewers.`);

    if (viewerUrls.length === 0) {
      console.log("No profile viewers found (or all are already connected).");
      return;
    }

    const viewerProfiles = viewerUrls.map((url) => ({
      url,
      source: "profileViewer",
    }));

    await processProfiles(context, page, viewerProfiles, "profile-viewers");
  } finally {
    await context.close();
  }
}

main().catch((err) => {
  console.error("Error:", err.message);
  process.exit(1);
});
