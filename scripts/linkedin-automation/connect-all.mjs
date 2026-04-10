#!/usr/bin/env node
/**
 * connect-all.mjs
 *
 * Runs all LinkedIn automation workflows in sequence:
 * 1. Connect with post commenters and likers
 * 2. Connect with profile viewers
 *
 * Usage:
 *   node connect-all.mjs
 *   DRY_RUN=1 node connect-all.mjs
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

async function getRecentPostUrls(page, maxPosts = 5) {
  await page.goto("https://www.linkedin.com/in/me/recent-activity/all/", {
    waitUntil: "domcontentloaded",
  });
  await humanDelay(page, CONFIG.delays.afterPageLoad);

  for (let i = 0; i < 3; i++) {
    const loaded = await scrollToLoadMore(page);
    if (!loaded) break;
  }

  const postLinks = await page.locator('a[href*="/feed/update/"]').all();
  const urls = [];

  for (const link of postLinks) {
    const href = await link.getAttribute("href").catch(() => null);
    if (href && href.includes("/feed/update/")) {
      const url = new URL(href, "https://www.linkedin.com");
      const clean = `${url.origin}${url.pathname}`.replace(/\/$/, "");
      if (!urls.includes(clean)) urls.push(clean);
    }
  }

  return urls.slice(0, maxPosts);
}

async function getCommentersFromPost(page, postUrl) {
  await page.goto(postUrl, { waitUntil: "domcontentloaded" });
  await humanDelay(page, CONFIG.delays.afterPageLoad);

  for (let i = 0; i < 5; i++) {
    const loadMore = page
      .locator('button:has-text("Load more comments"), button:has-text("Show more comments")')
      .first();
    const visible = await loadMore.isVisible().catch(() => false);
    if (!visible) break;
    await loadMore.click();
    await humanDelay(page, CONFIG.delays.scrollPause);
  }

  return extractProfileUrls(
    page,
    '.comments-comment-item a[href*="/in/"], .feed-shared-update-v2__comments-container a[href*="/in/"]'
  );
}

async function getLikersFromPost(page, postUrl) {
  await page.goto(postUrl, { waitUntil: "domcontentloaded" });
  await humanDelay(page, CONFIG.delays.afterPageLoad);

  const reactionsBtn = page
    .locator(
      'button[aria-label*="reaction"], span.social-details-social-counts__reactions-count, button.social-details-social-counts__count-value'
    )
    .first();
  const reactionsVisible = await reactionsBtn.isVisible().catch(() => false);

  if (!reactionsVisible) return [];

  await humanDelay(page, CONFIG.delays.beforeClick);
  await reactionsBtn.click();
  await humanDelay(page, CONFIG.delays.afterPageLoad);

  await page
    .waitForSelector('div[role="dialog"]', { timeout: 5000 })
    .catch(() => null);

  const modal = page.locator('div[role="dialog"]').first();
  for (let i = 0; i < 5; i++) {
    await modal.evaluate("el => el.scrollTop = el.scrollHeight").catch(() => {});
    await humanDelay(page, CONFIG.delays.scrollPause);
  }

  const urls = await extractProfileUrls(page, 'div[role="dialog"] a[href*="/in/"]');

  const closeBtn = page
    .locator('div[role="dialog"] button[aria-label="Dismiss"], div[role="dialog"] button[aria-label="Close"]')
    .first();
  await closeBtn.click().catch(() => {});

  return urls;
}

async function getProfileViewers(page) {
  await page.goto("https://www.linkedin.com/me/profile-views/", {
    waitUntil: "domcontentloaded",
  });
  await humanDelay(page, CONFIG.delays.afterPageLoad);

  for (let i = 0; i < 5; i++) {
    const loaded = await scrollToLoadMore(page);
    if (!loaded) break;
  }

  return extractProfileUrls(page, 'a[href*="/in/"]');
}

async function main() {
  const { context, page } = await launchWithSession();
  const allProfiles = new Set();

  try {
    await verifyLoggedIn(page);

    // Phase 1: Post engagers (commenters + likers)
    console.log("\n=== Phase 1: Post Engagers ===");
    const postUrls = await getRecentPostUrls(page, 5);
    console.log(`Found ${postUrls.length} recent posts.`);

    for (const postUrl of postUrls) {
      console.log(`\nProcessing: ${postUrl}`);

      const commenters = await getCommentersFromPost(page, postUrl);
      console.log(`  Commenters: ${commenters.length}`);
      commenters.forEach((url) => allProfiles.add(url));

      const likers = await getLikersFromPost(page, postUrl);
      console.log(`  Likers: ${likers.length}`);
      likers.forEach((url) => allProfiles.add(url));
    }

    // Phase 2: Profile viewers
    console.log("\n=== Phase 2: Profile Viewers ===");
    const viewers = await getProfileViewers(page);
    console.log(`Profile viewers: ${viewers.length}`);
    viewers.forEach((url) => allProfiles.add(url));

    // Phase 3: Send connection requests
    const profileUrls = [...allProfiles];
    console.log(`\n=== Phase 3: Sending Connections ===`);
    console.log(`Total unique profiles: ${profileUrls.length}`);

    if (profileUrls.length === 0) {
      console.log("No profiles to connect with.");
      return;
    }

    await processProfiles(page, profileUrls, "all-sources");
  } finally {
    await context.close();
  }
}

main().catch((err) => {
  console.error("Error:", err.message);
  process.exit(1);
});
