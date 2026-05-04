#!/usr/bin/env python3
"""Capture safe Firefox prefs.js entries into the dotfiles-managed user.js."""

from __future__ import annotations

import argparse
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path


USER_PREF_RE = re.compile(
    r'^(?P<prefix>\s*user_pref\("(?P<name>(?:\\\\.|[^"\\\\])*)",\s*)'
    r'(?P<value>.*)(?P<suffix>\);\s*)$'
)

CAPTURE_BEGIN = "// BEGIN captured Firefox preferences"
CAPTURE_END = "// END captured Firefox preferences"

SAFE_EXACT = {
    "accessibility.typeaheadfind.flashBar",
    "browser.bookmarks.restore_default_bookmarks",
    "browser.contentblocking.category",
    "browser.ctrlTab.sortByRecentlyUsed",
    "browser.ipProtection.enabled",
    "browser.ml.linkPreview.collapsed",
    "browser.newtabpage.activity-stream.discoverystream.promoCard.enabled",
    "browser.newtabpage.activity-stream.discoverystream.sections.interestPicker.visibleSections",
    "browser.newtabpage.activity-stream.newtabAdSize.billboard",
    "browser.newtabpage.activity-stream.newtabAdSize.billboard.position",
    "browser.newtabpage.activity-stream.showSponsored",
    "browser.newtabpage.activity-stream.showSponsoredTopSites",
    "browser.newtabpage.activity-stream.telemetry",
    "browser.newtabpage.activity-stream.feeds.telemetry",
    "browser.newtabpage.activity-stream.weather.optInDisplayed",
    "browser.shell.checkDefaultBrowser",
    "browser.startup.homepage",
    "browser.toolbars.bookmarks.visibility",
    "browser.uiCustomization.horizontalTabsBackup",
    "browser.uiCustomization.navBarWhenVerticalTabs",
    "browser.uiCustomization.state",
    "devtools.everOpened",
    "devtools.responsive.reloadNotification.enabled",
    "devtools.toolbox.selectedTool",
    "dom.forms.autocomplete.formautofill",
    "dom.security.https_only_mode_ever_enabled",
    "extensions.pictureinpicture.enable_picture_in_picture_overrides",
    "extensions.pocket.enabled",
    "extensions.webcompat.perform_injections",
    "general.autoScroll",
    "media.eme.enabled",
    "network.dns.disablePrefetch",
    "network.http.speculative-parallel-limit",
    "network.prefetch-next",
    "pdfjs.enableAltTextForEnglish",
    "places.semanticHistory.distanceThreshold",
    "places.semanticHistory.featureGate",
    "privacy.clearOnShutdown_v2.formdata",
    "privacy.userContext.enabled",
    "privacy.userContext.extension",
    "privacy.userContext.longPressBehavior",
    "privacy.userContext.ui.enabled",
    "signon.rememberSignons",
    "sidebar.backupState",
    "sidebar.main.tools",
    "sidebar.new-sidebar.has-used",
    "sidebar.revamp",
    "sidebar.verticalTabs.dragToPinPromo.dismissed",
    "sidebar.visibility",
}

SAFE_PREFIXES = (
    "browser.contentblocking.",
    "browser.ml.linkPreview.",
    "browser.shell.",
    "browser.startup.",
    "browser.theme.",
    "browser.toolbars.",
    "browser.uiCustomization.",
    "devtools.",
    "dom.forms.",
    "dom.security.",
    "extensions.pocket.",
    "extensions.pictureinpicture.",
    "extensions.webcompat.",
    "network.dns.",
    "pdfjs.",
    "places.semanticHistory.",
    "privacy.clearOnShutdown_v2.",
    "privacy.userContext.",
    "sidebar.",
)

DENY_EXACT = {
    "browser.download.lastDir",
    "browser.ml.linkPreview.nimbus",
    "browser.ml.linkPreview.onboardingTimes",
    "browser.newtabpage.pinned",
    "browser.search.region",
    "browser.search.totalSearches",
    "browser.shell.defaultBrowserCheckCount",
    "browser.shell.didSkipDefaultBrowserCheckOnFirstRun",
    "browser.shell.mostRecentDateSetAsDefault",
    "browser.shell.mostRecentDefaultPromptSeen",
    "browser.shell.userDisabledDefaultCheck",
    "browser.startup.couldRestoreSession.count",
    "browser.startup.lastColdStartupCheck",
    "browser.startup.homepage_override.buildID",
    "browser.startup.homepage_override.mstone",
    "browser.theme.content-theme",
    "browser.theme.toolbar-theme",
    "browser.urlbar.lastUrlbarSearchSeconds",
    "devtools.debugger.prefs-schema-version",
    "extensions.webextensions.uuids",
    "extensions.activeThemeID",
    "layout.css.prefers-color-scheme.content-override",
    "pdfjs.enabledCache.state",
    "pdfjs.migrationVersion",
    "places.semanticHistory.initialized",
    "sidebar.nimbus",
    "toolkit.telemetry.cachedClientID",
}

DENY_PREFIXES = (
    "app.normandy.",
    "app.update.",
    "browser.contextual-services.",
    "browser.contentblocking.cfr-milestone.",
    "browser.download.",
    "browser.engagement.",
    "browser.firefox-view.",
    "browser.ipProtection.entitlementCache",
    "browser.ipProtection.locationListCache",
    "browser.ipProtection.stateCache",
    "browser.ipProtection.usageCache",
    "browser.laterrun.",
    "browser.migration.",
    "browser.newtabpage.activity-stream.discoverystream.placements.",
    "browser.newtabpage.activity-stream.discoverystream.spoc.",
    "browser.newtabpage.activity-stream.impressionId",
    "browser.newtabpage.activity-stream.storageVersion",
    "browser.newtabpage.activity-stream.telemetry.surfaceId",
    "browser.newtabpage.storageVersion",
    "browser.newtabpage.trainhopAddon.",
    "browser.pagethumbnails.",
    "browser.proton.",
    "browser.region.",
    "browser.rights.",
    "browser.safebrowsing.",
    "browser.sessionstore.",
    "browser.topsites.",
    "browser.translations.mostRecent",
    "browser.urlbar.placeholderName",
    "browser.urlbar.quickactions.",
    "browser.urlbar.quicksuggest.",
    "browser.urlbar.tipShownCount.",
    "captchadetection.",
    "datareporting.dau.",
    "distribution.",
    "doh-rollout.",
    "dom.push.",
    "extensions.blocklist.",
    "extensions.databaseSchema",
    "extensions.dnr.",
    "extensions.getAddons.",
    "extensions.last",
    "extensions.pendingOperations",
    "extensions.quarantinedDomains.",
    "extensions.signatureCheckpoint",
    "extensions.systemAddonSet",
    "extensions.webextensions.",
    "gecko.handlerService.",
    "identity.",
    "idle.",
    "media.gmp",
    "media.videocontrols.picture-in-picture.video-toggle.first-seen",
    "messaging-system-action.",
    "nimbus.",
    "privacy.bounceTrackingProtection.",
    "privacy.purge_trackers.",
    "privacy.sanitize.",
    "privacy.trackingprotection.allow_list.hasMigrated",
    "services.",
    "signon.rustMirror.",
    "storage.",
    "termsofuse.",
    "toolkit.profiles.",
    "toolkit.startup.",
    "toolkit.telemetry.",
    "trailhead.",
)


def parse_user_pref_lines(path: Path) -> dict[str, str]:
    prefs: dict[str, str] = {}
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            match = USER_PREF_RE.match(line.rstrip("\n"))
            if match:
                prefs[match.group("name")] = match.group("value")
    return prefs


def resolve_profile_path(firefox_root: Path, profile_ref: str) -> Path:
    profile_path = Path(profile_ref)
    if profile_path.is_absolute():
        return profile_path
    return firefox_root / profile_path


def find_default_profile(firefox_root: Path) -> Path:
    profiles_ini = firefox_root / "profiles.ini"
    if not profiles_ini.is_file():
        raise FileNotFoundError(f"Firefox profiles.ini not found: {profiles_ini}")

    section = ""
    path = ""
    is_relative = "1"
    is_default = "0"
    install_default = ""
    profile_default: tuple[str, str] | None = None
    first_profile: tuple[str, str] | None = None

    def commit_profile_section() -> None:
        nonlocal first_profile, profile_default
        if not section.startswith("Profile") or not path:
            return
        if first_profile is None:
            first_profile = (path, is_relative)
        if is_default == "1":
            profile_default = (path, is_relative)

    with profiles_ini.open("r", encoding="utf-8", errors="replace") as handle:
        for raw_line in handle:
            line = raw_line.rstrip("\n").rstrip("\r")
            if not line or line.startswith(("#", ";")):
                continue
            if line.startswith("[") and line.endswith("]"):
                commit_profile_section()
                section = line[1:-1]
                path = ""
                is_relative = "1"
                is_default = "0"
                continue

            key, sep, value = line.partition("=")
            if not sep:
                continue
            if section.startswith("Install") and key == "Default":
                install_default = value
            elif section.startswith("Profile"):
                if key == "Path":
                    path = value
                elif key == "IsRelative":
                    is_relative = value
                elif key == "Default" and value == "1":
                    is_default = "1"

    commit_profile_section()

    if install_default:
        return resolve_profile_path(firefox_root, install_default)
    if profile_default:
        path, relative = profile_default
        return resolve_profile_path(firefox_root, path) if relative == "1" else Path(path)
    if first_profile:
        path, relative = first_profile
        return resolve_profile_path(firefox_root, path) if relative == "1" else Path(path)

    raise FileNotFoundError(f"No Firefox profiles found in {profiles_ini}")


def value_looks_sensitive(raw_value: str) -> bool:
    lowered = raw_value.lower()
    home = str(Path.home()).lower()
    sensitive_fragments = (
        home,
        "/users/",
        "file://",
        "token",
        "secret",
        "password",
        "credential",
        "clientid",
        "guid",
        "uuid",
    )
    return any(fragment and fragment in lowered for fragment in sensitive_fragments)


def is_safe_pref(name: str, raw_value: str) -> bool:
    if name in DENY_EXACT:
        return False
    if any(name.startswith(prefix) for prefix in DENY_PREFIXES):
        return False
    if value_looks_sensitive(raw_value):
        return False
    if name in SAFE_EXACT:
        return True
    return any(name.startswith(prefix) for prefix in SAFE_PREFIXES)


def captured_block(captured: dict[str, str]) -> list[str]:
    lines = [
        CAPTURE_BEGIN,
        "// Generated from the local Firefox default profile by scripts/setup/firefox-capture-prefs.py.",
        "// The helper excludes profile/session/device-specific prefs before writing this block.",
    ]
    for name in sorted(captured):
        lines.append(f'user_pref("{name}", {captured[name]});')
    lines.append(CAPTURE_END)
    return lines


def write_text_atomically(path: Path, text: str) -> None:
    tmp_path = path.with_name(f".{path.name}.tmp")
    try:
        tmp_path.write_text(text, encoding="utf-8")
        os.replace(tmp_path, path)
    finally:
        if tmp_path.exists():
            tmp_path.unlink()


def merge_user_js(user_js: Path, captured: dict[str, str]) -> int:
    existing_lines = user_js.read_text(encoding="utf-8").splitlines()
    in_captured_block = False
    outside_lines: list[str] = []
    outside_pref_names: set[str] = set()
    replaced_count = 0

    for line in existing_lines:
        stripped = line.strip()
        if stripped == CAPTURE_BEGIN:
            in_captured_block = True
            continue
        if stripped == CAPTURE_END:
            in_captured_block = False
            continue
        if in_captured_block:
            continue

        match = USER_PREF_RE.match(line)
        if match:
            name = match.group("name")
            outside_pref_names.add(name)
            if name in captured and match.group("value") != captured[name]:
                line = f'{match.group("prefix")}{captured[name]}{match.group("suffix")}'
                replaced_count += 1
        outside_lines.append(line)

    remaining = {name: value for name, value in captured.items() if name not in outside_pref_names}
    while outside_lines and outside_lines[-1] == "":
        outside_lines.pop()

    new_lines = outside_lines + ["", *captured_block(remaining), ""]
    new_text = "\n".join(new_lines)
    old_text = user_js.read_text(encoding="utf-8")
    if old_text != new_text:
        write_text_atomically(user_js, new_text)

    return replaced_count


def capture_prefs(args: argparse.Namespace) -> int:
    firefox_root = Path(args.firefox_root).expanduser()
    user_js = Path(args.user_js).expanduser()
    profile = Path(args.profile).expanduser() if args.profile else find_default_profile(firefox_root)
    prefs_js = profile / "prefs.js"

    if not prefs_js.is_file():
        raise FileNotFoundError(f"Firefox prefs.js not found: {prefs_js}")
    if not user_js.is_file():
        raise FileNotFoundError(f"dotfiles user.js not found: {user_js}")

    prefs = parse_user_pref_lines(prefs_js)
    captured = {name: value for name, value in prefs.items() if is_safe_pref(name, value)}

    if args.dry_run:
        print(f"profile={profile}")
        print(f"prefs_seen={len(prefs)}")
        print(f"prefs_captured={len(captured)}")
        for name in sorted(captured):
            print(name)
        return 0

    replaced = merge_user_js(user_js, captured)
    print(f"Captured {len(captured)} safe Firefox prefs from {profile}")
    if replaced:
        print(f"Updated {replaced} existing user.js pref values")
    print(f"Updated {user_js}")
    return 0


def self_test() -> int:
    tmp = Path(tempfile.mkdtemp())
    try:
        firefox_root = tmp / "Firefox"
        profile = firefox_root / "Profiles/test.default"
        profile.mkdir(parents=True)
        (firefox_root / "profiles.ini").write_text(
            "\n".join(
                [
                    "[Install123]",
                    "Default=Profiles/test.default",
                    "[Profile0]",
                    "Name=default",
                    "IsRelative=1",
                    "Path=Profiles/test.default",
                    "Default=1",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        (profile / "prefs.js").write_text(
            "\n".join(
                [
                    'user_pref("browser.contentblocking.category", "strict");',
                    'user_pref("browser.download.lastDir", "/Users/example/Downloads");',
                    'user_pref("browser.shell.checkDefaultBrowser", true);',
                    'user_pref("network.dns.disablePrefetch", true);',
                    'user_pref("services.sync.username", "person@example.com");',
                    "",
                ]
            ),
            encoding="utf-8",
        )
        user_js = tmp / "user.js"
        user_js.write_text(
            "\n".join(
                [
                    "// Dotfiles-managed Firefox preferences.",
                    'user_pref("browser.shell.checkDefaultBrowser", false);',
                    "",
                ]
            ),
            encoding="utf-8",
        )

        args = argparse.Namespace(
            firefox_root=str(firefox_root),
            profile="",
            user_js=str(user_js),
            dry_run=False,
        )
        capture_prefs(args)
        output = user_js.read_text(encoding="utf-8")

        assert 'user_pref("browser.contentblocking.category", "strict");' in output
        assert 'user_pref("browser.shell.checkDefaultBrowser", true);' in output
        assert 'user_pref("network.dns.disablePrefetch", true);' in output
        assert "browser.download.lastDir" not in output
        assert "services.sync.username" not in output
        assert CAPTURE_BEGIN in output and CAPTURE_END in output
        return 0
    finally:
        shutil.rmtree(tmp)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--firefox-root",
        default=str(Path.home() / "Library/Application Support/Firefox"),
        help="Firefox profile root containing profiles.ini",
    )
    parser.add_argument("--profile", default="", help="Firefox profile directory to read")
    parser.add_argument(
        "--user-js",
        default=str(Path(__file__).resolve().parent / "firefox/user.js"),
        help="dotfiles-managed user.js to update",
    )
    parser.add_argument("--dry-run", action="store_true", help="list captured pref names without writing")
    parser.add_argument("--self-test", action="store_true", help="run synthetic parser/merge tests")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.self_test:
        return self_test()
    return capture_prefs(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
