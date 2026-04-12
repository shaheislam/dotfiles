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
 *   node connect-post-engagers.mjs --type=all --days=30
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
    days: { type: "string", default: "30" },
  },
});

function parseLinkedInAgeLabel(label) {
  const text = (label || "").trim().toLowerCase();
  const match = text.match(/(\d+)\s*(mo|m(?:in)?|h(?:r)?|d|w(?:k)?|yr|y)/);

  if (!match) return Number.POSITIVE_INFINITY;

  const value = Number.parseInt(match[1], 10);
  const unit = match[2];

  if (unit.startsWith("m") && unit !== "mo") return value / (24 * 60);
  if (unit.startsWith("h")) return value / 24;
  if (unit === "d") return value;
  if (unit.startsWith("w")) return value * 7;
  if (unit === "mo") return value * 30;
  if (unit === "yr" || unit === "y") return value * 365;

  return Number.POSITIVE_INFINITY;
}

function parseAbsoluteDateLabel(label) {
  const text = (label || "").trim();

  if (!text) return Number.POSITIVE_INFINITY;

  const parsed = Date.parse(text);
  if (Number.isNaN(parsed)) return Number.POSITIVE_INFINITY;

  const ageMs = Date.now() - parsed;
  return ageMs / (24 * 60 * 60 * 1000);
}

function parseAgeDays(label) {
  const relativeDays = parseLinkedInAgeLabel(label);
  if (relativeDays !== Number.POSITIVE_INFINITY) return relativeDays;

  return parseAbsoluteDateLabel(label);
}

function normalizeLinkedInPath(href) {
  if (!href) return null;

  try {
    const url = new URL(href, "https://www.linkedin.com");
    return url.pathname.replace(/\/$/, "");
  } catch {
    return null;
  }
}

async function getOwnProfilePath(page) {
  await page.goto("https://www.linkedin.com/in/me/", {
    waitUntil: "domcontentloaded",
  });
  await humanDelay(page, CONFIG.delays.afterPageLoad);
  return normalizeLinkedInPath(page.url());
}

async function getRecentPostUrls(page, maxPosts, maxAgeDays) {
  // Navigate to your own posts page, not the broader activity feed.
  await page.goto("https://www.linkedin.com/in/me/recent-activity/shares/", {
    waitUntil: "domcontentloaded",
  });
  await humanDelay(page, CONFIG.delays.afterPageLoad);

  const ownProfilePath = await getOwnProfilePath(page);

  await page.goto("https://www.linkedin.com/in/me/recent-activity/shares/", {
    waitUntil: "domcontentloaded",
  });
  await humanDelay(page, CONFIG.delays.afterPageLoad);

  // Scroll to load enough posts within the requested date window.
  for (let i = 0; i < 8; i++) {
    const loaded = await scrollToLoadMore(page);
    if (!loaded) break;

    const ageLabels = await page.locator('span[aria-hidden="true"]').allTextContents();
    const oldestLoadedDays = ageLabels.reduce((oldest, label) => {
      return Math.max(oldest, parseAgeDays(label));
    }, 0);

    if (oldestLoadedDays >= maxAgeDays) break;
  }

  const candidatePosts = await page.locator('div.feed-shared-update-v2[data-urn]').evaluateAll(
    (nodes) => {
      return nodes.map((node) => {
        const urn = node.getAttribute("data-urn");
        const actorLink = node.querySelector(
          'a.update-components-actor__meta-link[href*="/in/"], a.feed-shared-actor__container-link[href*="/in/"]'
        );
        const ageCandidates = Array.from(
          node.querySelectorAll(
            '.update-components-actor__sub-description span[aria-hidden="true"], .feed-shared-actor__sub-description span[aria-hidden="true"]'
          )
        ).map((element) => (element.textContent || "").trim());

        return {
          urn,
          actorHref: actorLink?.getAttribute("href") || null,
          ageLabel: ageCandidates.find((candidate) => candidate) || null,
        };
      });
    }
  );

  const recentOwnUrls = [];

  for (const candidatePost of candidatePosts) {
    if (!candidatePost.urn?.includes("urn:li:activity:")) {
      continue;
    }

    const authorPath = normalizeLinkedInPath(candidatePost.actorHref);
    const ageDays = parseAgeDays(candidatePost.ageLabel);

    if (authorPath && authorPath !== ownProfilePath) {
      continue;
    }

    if (ageDays > maxAgeDays) {
      continue;
    }

    const activityId = candidatePost.urn.split(":").pop();
    const postUrl = `https://www.linkedin.com/feed/update/urn:li:activity:${activityId}`;
    recentOwnUrls.push(postUrl);

    if (recentOwnUrls.length >= maxPosts) {
      break;
    }
  }

  return recentOwnUrls;
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
      'button.social-details-social-counts__count-value[aria-label*=" and "], button.social-details-social-counts__count-value[aria-label*="others"], button[aria-label*="reaction"]'
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

  const modalContent = page
    .locator('div[role="dialog"] .artdeco-modal__content, div[role="dialog"] .social-details-reactors-modal__content')
    .first();

  // Scroll the actual modal content and accumulate liker profiles as more rows load.
  const seenUrls = new Set();
  let previousCount = 0;
  let stableIterations = 0;
  for (let i = 0; i < 20; i++) {
    const urls = await extractProfileUrls(
      page,
      'div[role="dialog"] a[href*="/in/"]'
    );
    for (const url of urls) {
      seenUrls.add(url);
    }

    await modalContent
      .evaluate(
        "el => { el.scrollTop = Math.min(el.scrollTop + el.clientHeight, el.scrollHeight); }"
      )
      .catch(() => {});
    await humanDelay(page, CONFIG.delays.scrollPause);

    const currentCount = seenUrls.size;
    if (currentCount === previousCount) {
      stableIterations += 1;
      if (stableIterations >= 2) {
        break;
      }
      continue;
    }

    stableIterations = 0;
    previousCount = currentCount;

    const reachedBottom = await modalContent
      .evaluate(
        "el => el.scrollTop + el.clientHeight >= el.scrollHeight - 5"
      )
      .catch(() => false);
    if (reachedBottom && stableIterations >= 1) {
      break;
    }
  }

  // Extract liker profile links from the modal
  const finalUrls = await extractProfileUrls(
    page,
    'div[role="dialog"] a[href*="/in/"]'
  );
  for (const url of finalUrls) {
    seenUrls.add(url);
  }

  // Close the modal
  const closeBtn = page
    .locator('div[role="dialog"] button[aria-label="Dismiss"], div[role="dialog"] button[aria-label="Close"]')
    .first();
  await closeBtn.click().catch(() => {});

  return [...seenUrls];
}

async function main() {
  const { context, page } = await launchWithSession();

  try {
    await verifyLoggedIn(page);

    const type = args.type || "all";
    const maxPosts = parseInt(args["max-posts"], 10);
    const maxAgeDays = parseInt(args.days, 10);

    // Get post URLs
    let postUrls;
    if (args["post-url"]) {
      postUrls = [args["post-url"]];
      console.log(`Using provided post URL.`);
    } else {
      console.log(
        `Finding up to ${maxPosts} posts from the last ${maxAgeDays} days...`
      );
      postUrls = await getRecentPostUrls(page, maxPosts, maxAgeDays);
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

    await processProfiles(context, page, profiles, `post-engagers (${type})`);
  } finally {
    await context.close();
  }
}

main().catch((err) => {
  console.error("Error:", err.message);
  process.exit(1);
});
