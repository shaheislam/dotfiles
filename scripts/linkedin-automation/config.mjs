// Configuration for LinkedIn automation scripts.
// Adjust delays and limits to match your comfort level with rate limiting.

import { join } from "node:path";
import { homedir } from "node:os";

export const CONFIG = {
  // Path to store the browser session (cookies, localStorage)
  sessionDir: join(homedir(), ".linkedin-automation-session"),

  // Maximum connection requests per run (LinkedIn weekly limit is ~100)
  maxConnectionsPerRun: 20,

  // Delay between actions (milliseconds) — randomized within range
  delays: {
    betweenConnections: { min: 3000, max: 8000 },
    afterPageLoad: { min: 2000, max: 4000 },
    beforeClick: { min: 500, max: 1500 },
    scrollPause: { min: 1000, max: 3000 },
  },

  // Browser settings
  browser: {
    headless: false, // Set true for background runs
    slowMo: 50, // Extra delay between actions (ms)
  },

  // Dry run mode — logs what would happen without sending requests
  dryRun: process.env.DRY_RUN === "1",

  // Optional: custom notes for connection requests (max 300 chars)
  // Use {firstName} to personalize the note, or set a value to null to skip it.
  connectionNotes: {
    commenter:
      "Hey {firstName}, thanks for engaging with my post. I'm looking to connect with people who have like-minded views on AI and tech to bounce ideas off. Would love to connect.",
    liker:
      "Hey {firstName}, thanks for engaging with my post. I'm looking to connect with people who have like-minded views on AI and tech to bounce ideas off. Would love to connect.",
    profileViewer:
      "Hi {firstName}, I noticed you checked out my profile. Let me know if you'd be interested in connecting.",
    default: null,
  },
};

/**
 * Returns a random delay within the specified range.
 */
export function randomDelay(range) {
  return Math.floor(Math.random() * (range.max - range.min + 1)) + range.min;
}

/**
 * Waits for a random amount of time within the given range.
 */
export async function humanDelay(page, range) {
  const ms = randomDelay(range);
  await page.waitForTimeout(ms);
}
