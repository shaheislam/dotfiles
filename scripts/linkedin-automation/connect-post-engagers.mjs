#!/usr/bin/env node
/**
 * connect-post-engagers.mjs
 *
 * Finds people who commented on or liked your LinkedIn posts,
 * then sends them connection requests.
 *
 * Usage:
 *   node connect-post-engagers.mjs --type=commenters
 *   node connect-post-engagers.mjs --type=likers
 *   node connect-post-engagers.mjs --type=all
 *   node connect-post-engagers.mjs --post-url=https://www.linkedin.com/feed/update/urn:li:activity:XXXXX
 *
 * Requires: Run save-session.mjs first to authenticate.
 */

import { parseArgs } from "node:util";
import { CONFIG, humanDelay } from "./config.mjs";
import {
  launchWithSession,
  verifyLoggedIn,
  scrollToLoadMore,
  extractProfileUrls,
  mergeProfiles,
  processProfiles,
} from "./linkedin-helpers.mjs";

function addProfiles(profileMap, urls, source) {
  for (const url of urls) {
    const nextProfile = { url, source };
    profileMap.set(url, mergeProfiles(profileMap.get(url), nextProfile));
  }
}

const { values: args } = parseArgs({
  options: {
    type: { type: "string", default: "all" },
    "post-url": { type: "string" },
    "max-posts": { type: "string", default: "5" },
  },
});

async function getRecentPostUrls(page, maxPosts) {
  // Navigate to your own profile's activity page
  await page.goto("https://www.linkedin.com/in/me/recent-activity/all/", {
    waitUntil: "domcontentloaded",
  });
  await humanDelay(page, CONFIG.delays.afterPageLoad);

  // Scroll to load enough posts
  for (let i = 0; i < 3; i++) {
    const loaded = await scrollToLoadMore(page);
    if (!loaded) break;
  }

  // Extract post activity URLs
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

  // Expand comments if there's a "Load more comments" button
  for (let i = 0; i < 5; i++) {
    const loadMore = page
      .locator(
        'button:has-text("Load more comments"), button:has-text("Show more comments")'
      )
      .first();
    const visible = await loadMore.isVisible().catch(() => false);
    if (!visible) break;
    await loadMore.click();
    await humanDelay(page, CONFIG.delays.scrollPause);
  }

  // Extract commenter profile links from the comment section
  return extractProfileUrls(
    page,
    '.comments-comment-item a[href*="/in/"], .feed-shared-update-v2__comments-container a[href*="/in/"]'
  );
}

async function getLikersFromPost(page, postUrl) {
  await page.goto(postUrl, { waitUntil: "domcontentloaded" });
  await humanDelay(page, CONFIG.delays.afterPageLoad);

  // Click the reactions/likes count to open the likers modal
  const reactionsBtn = page
    .locator(
      'button[aria-label*="reaction"], span.social-details-social-counts__reactions-count, button.social-details-social-counts__count-value'
    )
    .first();
  const reactionsVisible = await reactionsBtn.isVisible().catch(() => false);

  if (!reactionsVisible) {
    console.log("  No reactions found on this post.");
    return [];
  }

  await humanDelay(page, CONFIG.delays.beforeClick);
  await reactionsBtn.click();
  await humanDelay(page, CONFIG.delays.afterPageLoad);

  // Wait for the reactions modal to appear
  await page
    .waitForSelector('div[role="dialog"]', { timeout: 5000 })
    .catch(() => null);

  // Scroll the modal to load more likers
  const modal = page.locator('div[role="dialog"]').first();
  for (let i = 0; i < 5; i++) {
    await modal.evaluate("el => el.scrollTop = el.scrollHeight").catch(() => {});
    await humanDelay(page, CONFIG.delays.scrollPause);
  }

  // Extract liker profile links from the modal
  const urls = await extractProfileUrls(
    page,
    'div[role="dialog"] a[href*="/in/"]'
  );

  // Close the modal
  const closeBtn = page
    .locator('div[role="dialog"] button[aria-label="Dismiss"], div[role="dialog"] button[aria-label="Close"]')
    .first();
  await closeBtn.click().catch(() => {});

  return urls;
}

async function main() {
  const { context, page } = await launchWithSession();

  try {
    await verifyLoggedIn(page);

    const type = args.type || "all";
    const maxPosts = parseInt(args["max-posts"], 10);

    // Get post URLs
    let postUrls;
    if (args["post-url"]) {
      postUrls = [args["post-url"]];
      console.log(`Using provided post URL.`);
    } else {
      console.log(`Finding your ${maxPosts} most recent posts...`);
      postUrls = await getRecentPostUrls(page, maxPosts);
      console.log(`Found ${postUrls.length} posts.`);
    }

    if (postUrls.length === 0) {
      console.log("No posts found. Exiting.");
      return;
    }

    const allProfiles = new Map();

    for (const postUrl of postUrls) {
      console.log(`\nProcessing post: ${postUrl}`);

      if (type === "commenters" || type === "all") {
        const commenters = await getCommentersFromPost(page, postUrl);
        console.log(`  Found ${commenters.length} commenters.`);
        addProfiles(allProfiles, commenters, "commenter");
      }

      if (type === "likers" || type === "all") {
        const likers = await getLikersFromPost(page, postUrl);
        console.log(`  Found ${likers.length} likers.`);
        addProfiles(allProfiles, likers, "liker");
      }
    }

    const profiles = [...allProfiles.values()];
    console.log(`\nTotal unique profiles found: ${profiles.length}`);

    if (profiles.length === 0) {
      console.log("No profiles to connect with. Exiting.");
      return;
    }

    await processProfiles(page, profiles, `post-engagers (${type})`);
  } finally {
    await context.close();
  }
}

main().catch((err) => {
  console.error("Error:", err.message);
  process.exit(1);
});
