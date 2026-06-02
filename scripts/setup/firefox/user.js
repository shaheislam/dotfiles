// Dotfiles-managed Firefox preferences.
// Installed into the default local Firefox profile by scripts/setup/firefox-setup.sh.
// This file intentionally does not manage cookies, history, sessions, or logins.

// Required for Granted/AWS console isolation via Firefox containers.
user_pref("privacy.userContext.enabled", true);
user_pref("privacy.userContext.ui.enabled", true);
user_pref("privacy.userContext.longPressBehavior", 2);

// Keep Firefox itself dark without forcing dark styling onto every website.
user_pref("extensions.activeThemeID", "firefox-compact-dark@mozilla.org");
user_pref("layout.css.prefers-color-scheme.content-override", 0);

// Required for userChrome.css/userContent.css customizations, including hidden native tabs for Sidebery.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("svg.context-properties.content.enabled", true);
user_pref("layout.css.backdrop-filter.enabled", true);

// Prefer unloading idle/background tabs over swapping the whole browser under memory pressure.
// Auto Tab Discard's 60-minute policy is managed by scripts/setup/firefox/policies.json.
user_pref("browser.tabs.unloadOnLowMemory", true);

// Keep startup/new-tab noise low without changing browsing data.
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("browser.bookmarks.restore_default_bookmarks", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);

// Mirror the lightweight privacy defaults from Firefox enterprise policies.
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("extensions.pocket.enabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);

// BEGIN captured Firefox preferences
// Generated from the local Firefox default profile by scripts/setup/firefox-capture-prefs.py.
// The helper excludes profile/session/device-specific prefs before writing this block.
user_pref("accessibility.typeaheadfind.flashBar", 0);
user_pref("browser.contentblocking.category", "standard");
user_pref("browser.ctrlTab.sortByRecentlyUsed", true);
user_pref("browser.ipProtection.enabled", true);
user_pref("browser.ml.linkPreview.collapsed", true);
user_pref("browser.newtabpage.activity-stream.discoverystream.promoCard.enabled", true);
user_pref("browser.newtabpage.activity-stream.discoverystream.sections.interestPicker.visibleSections", "top_stories_section,arts,home,finance,tech,business,education-science,travel,health,food,government,education,sports,hobbies,society-parenting");
user_pref("browser.newtabpage.activity-stream.newtabAdSize.billboard", true);
user_pref("browser.newtabpage.activity-stream.newtabAdSize.billboard.position", "1");
user_pref("browser.newtabpage.activity-stream.weather.optInDisplayed", false);
user_pref("browser.toolbars.bookmarks.visibility", "never");
user_pref("browser.uiCustomization.horizontalTabsBackup", "{\"placements\":{\"widget-overflow-fixed-list\":[],\"unified-extensions-area\":[\"webextension_metamask_io-browser-action\",\"_4cfbf13b-f27f-4f03-91dc-2aa17644029a_-browser-action\",\"_b5e0e8de-ebfe-4306-9528-bcc18241a490_-browser-action\",\"_e07de650-85aa-4302-9709-d3292c66b674_-browser-action\",\"_9350bc42-47fb-4598-ae0f-825e3dd9ceba_-browser-action\",\"_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action\",\"search_kagi_com-browser-action\",\"dontfuckwithpaste_raim_ist-browser-action\",\"firefox_tampermonkey_net-browser-action\"],\"nav-bar\":[\"sidebar-button\",\"back-button\",\"forward-button\",\"stop-reload-button\",\"customizableui-special-spring1\",\"vertical-spacer\",\"urlbar-container\",\"customizableui-special-spring2\",\"downloads-button\",\"fxa-toolbar-menu-button\",\"unified-extensions-button\",\"_3c078156-979c-498b-8990-85f7987dd929_-browser-action\",\"sponsorblocker_ajay_app-browser-action\",\"adnauseam_rednoise_org-browser-action\",\"_testpilot-containers-browser-action\"],\"TabsToolbar\":[\"firefox-view-button\",\"tabbrowser-tabs\",\"new-tab-button\",\"alltabs-button\"],\"vertical-tabs\":[],\"PersonalToolbar\":[\"import-button\",\"personal-bookmarks\"]},\"seen\":[\"developer-button\",\"screenshot-button\",\"_3c078156-979c-498b-8990-85f7987dd929_-browser-action\",\"webextension_metamask_io-browser-action\",\"_4cfbf13b-f27f-4f03-91dc-2aa17644029a_-browser-action\",\"sponsorblocker_ajay_app-browser-action\",\"_b5e0e8de-ebfe-4306-9528-bcc18241a490_-browser-action\",\"_e07de650-85aa-4302-9709-d3292c66b674_-browser-action\",\"adnauseam_rednoise_org-browser-action\",\"_9350bc42-47fb-4598-ae0f-825e3dd9ceba_-browser-action\",\"_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action\",\"_testpilot-containers-browser-action\",\"search_kagi_com-browser-action\",\"dontfuckwithpaste_raim_ist-browser-action\",\"firefox_tampermonkey_net-browser-action\"],\"dirtyAreaCache\":[\"nav-bar\",\"vertical-tabs\",\"PersonalToolbar\",\"unified-extensions-area\",\"TabsToolbar\"],\"currentVersion\":23,\"newElementCount\":2}");
user_pref("browser.uiCustomization.navBarWhenVerticalTabs", "[\"sidebar-button\",\"back-button\",\"forward-button\",\"stop-reload-button\",\"customizableui-special-spring1\",\"vertical-spacer\",\"urlbar-container\",\"customizableui-special-spring2\",\"downloads-button\",\"fxa-toolbar-menu-button\",\"unified-extensions-button\",\"_3c078156-979c-498b-8990-85f7987dd929_-browser-action\",\"sponsorblocker_ajay_app-browser-action\",\"adnauseam_rednoise_org-browser-action\",\"_testpilot-containers-browser-action\",\"firefox-view-button\",\"alltabs-button\"]");
user_pref("browser.uiCustomization.state", "{\"placements\":{\"widget-overflow-fixed-list\":[],\"unified-extensions-area\":[\"webextension_metamask_io-browser-action\",\"_4cfbf13b-f27f-4f03-91dc-2aa17644029a_-browser-action\",\"_b5e0e8de-ebfe-4306-9528-bcc18241a490_-browser-action\",\"_e07de650-85aa-4302-9709-d3292c66b674_-browser-action\",\"_9350bc42-47fb-4598-ae0f-825e3dd9ceba_-browser-action\",\"_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action\",\"search_kagi_com-browser-action\",\"dontfuckwithpaste_raim_ist-browser-action\",\"firefox_tampermonkey_net-browser-action\",\"claudecodebrowser_ligandal_com-browser-action\"],\"nav-bar\":[\"sidebar-button\",\"back-button\",\"forward-button\",\"stop-reload-button\",\"customizableui-special-spring1\",\"vertical-spacer\",\"urlbar-container\",\"customizableui-special-spring2\",\"downloads-button\",\"ipprotection-button\",\"fxa-toolbar-menu-button\",\"unified-extensions-button\",\"_3c078156-979c-498b-8990-85f7987dd929_-browser-action\",\"sponsorblocker_ajay_app-browser-action\",\"adnauseam_rednoise_org-browser-action\",\"_testpilot-containers-browser-action\"],\"TabsToolbar\":[\"firefox-view-button\",\"tabbrowser-tabs\",\"new-tab-button\",\"alltabs-button\"],\"vertical-tabs\":[],\"PersonalToolbar\":[\"import-button\",\"personal-bookmarks\"]},\"seen\":[\"developer-button\",\"screenshot-button\",\"_3c078156-979c-498b-8990-85f7987dd929_-browser-action\",\"webextension_metamask_io-browser-action\",\"_4cfbf13b-f27f-4f03-91dc-2aa17644029a_-browser-action\",\"sponsorblocker_ajay_app-browser-action\",\"_b5e0e8de-ebfe-4306-9528-bcc18241a490_-browser-action\",\"_e07de650-85aa-4302-9709-d3292c66b674_-browser-action\",\"adnauseam_rednoise_org-browser-action\",\"_9350bc42-47fb-4598-ae0f-825e3dd9ceba_-browser-action\",\"_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action\",\"_testpilot-containers-browser-action\",\"search_kagi_com-browser-action\",\"dontfuckwithpaste_raim_ist-browser-action\",\"firefox_tampermonkey_net-browser-action\",\"claudecodebrowser_ligandal_com-browser-action\",\"ipprotection-button\"],\"dirtyAreaCache\":[\"nav-bar\",\"vertical-tabs\",\"PersonalToolbar\",\"unified-extensions-area\",\"TabsToolbar\"],\"currentVersion\":23,\"newElementCount\":2}");
user_pref("devtools.everOpened", true);
user_pref("devtools.responsive.reloadNotification.enabled", false);
user_pref("devtools.toolbox.selectedTool", "jsdebugger");
user_pref("dom.forms.autocomplete.formautofill", true);
user_pref("dom.security.https_only_mode_ever_enabled", true);
user_pref("extensions.pictureinpicture.enable_picture_in_picture_overrides", true);
user_pref("extensions.webcompat.perform_injections", true);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.http.speculative-parallel-limit", 0);
user_pref("network.prefetch-next", false);
user_pref("pdfjs.enableAltTextForEnglish", true);
user_pref("places.semanticHistory.distanceThreshold", "0.6");
user_pref("places.semanticHistory.featureGate", true);
user_pref("privacy.clearOnShutdown_v2.formdata", true);
user_pref("privacy.userContext.extension", "@testpilot-containers");
user_pref("sidebar.backupState", "{\"command\":\"\",\"panelOpen\":false,\"panelWidth\":200,\"launcherWidth\":48,\"launcherExpanded\":false,\"launcherVisible\":true}");
user_pref("sidebar.installed.extensions", "{3c078156-979c-498b-8990-85f7987dd929}");
user_pref("sidebar.main.tools", "aichat,syncedtabs,history,bookmarks,{3c078156-979c-498b-8990-85f7987dd929}");
user_pref("sidebar.new-sidebar.has-used", true);
user_pref("sidebar.revamp", true);
user_pref("sidebar.verticalTabs.dragToPinPromo.dismissed", true);
user_pref("sidebar.visibility", "hide-sidebar");
user_pref("signon.rememberSignons", false);
// END captured Firefox preferences
