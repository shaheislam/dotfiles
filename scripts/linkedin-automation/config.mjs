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

  // Optional: custom note for connection requests (max 300 chars)
  // Set to null to send without a note
  connectionNote: null,
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
