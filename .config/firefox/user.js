// Firefox managed prefs — overlaid onto the active profile by
// scripts/firefox/install-user-js.sh.
//
// Philosophy: minimal, justified. Each pref must either (a) match an
// explicit user ask, (b) align with the Throwaway-container data-
// minimisation model, or (c) fix a default that catches most users
// off-guard. No "while we're here" prefs.
//
// Firefox reads user.js at startup and copies values into prefs.js,
// so changes apply on next launch. Runtime UI changes write to
// prefs.js only.

// --- Sync ---
// Enable history sync (default off). Needed for cross-device frecency
// merging that drives our Sidebery routing recommendations.
user_pref("services.sync.engine.history", true);

// --- Privacy signals ---
// Send Do-Not-Track header on all requests.
user_pref("privacy.donottrackheader.enabled", true);
// Send Global Privacy Control — modern successor to DNT, increasingly
// honoured by sites (California CPRA, Colorado CPA reference it).
user_pref("privacy.globalprivacycontrol.enabled", true);
user_pref("privacy.globalprivacycontrol.functionality.enabled", true);

// --- New tab page cleanup ---
// Default new-tab page surfaces Pocket stories + sponsored tiles. Off.
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.feeds.topsites", true);

// --- UX defaults that surprise people ---
// Closing the last tab in a window shouldn't close the window —
// otherwise re-opening loses session context.
user_pref("browser.tabs.closeWindowWithLastTab", false);
