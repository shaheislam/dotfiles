#!/usr/bin/env python3
"""Capture, validate, and apply dotfiles-managed FluidVoice preferences."""

from __future__ import annotations

import argparse
import base64
import copy
import datetime as dt
import json
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


DOMAIN = "com.FluidApp.app"
SCHEMA = "dotfiles.fluidvoice.preferences.v1"
DOTFILES_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CONFIG = DOTFILES_ROOT / ".config/fluidvoice/config.json"
DEFAULT_PREFS_PLIST = Path.home() / "Library/Preferences/com.FluidApp.app.plist"
TYPE_KEY = "__fluidvoice_type"

SAFE_KEYS = {
    "AccentColorOption",
    "AppPromptBindings",
    "AutoUpdateCheckEnabled",
    "BetaReleasesEnabled",
    "CancelRecordingHotkeyShortcut",
    "CommandModeConfirmBeforeExecute",
    "CommandModeHotkeyShortcut",
    "CommandModeLinkedToGlobal",
    "CommandModeSelectedModel",
    "CommandModeSelectedProviderID",
    "CommandModeShortcutEnabled",
    "CopyTranscriptionToClipboard",
    "CustomDictationPrompt",
    "CustomDictionaryEntries",
    "DefaultDictationPromptOverride",
    "DefaultEditPromptOverride",
    "DefaultRewritePromptOverride",
    "DefaultWritePromptOverride",
    "DictationPromptOff",
    "DictationPromptProfiles",
    "EnableAIProcessing",
    "EnableAIStreaming",
    "EnableDebugLogs",
    "EnableStreamingPreview",
    "EnableTranscriptionSounds",
    "FillerWords",
    "Fluid1InterestCaptured",
    "GAAVModeEnabled",
    "HotkeyMode",
    "HotkeyShortcutKey",
    "IntendedDockVisibility",
    "LaunchAtStartup",
    "ModelReasoningConfigs",
    "NotchPresentationMode",
    "NotifyAIProcessingFailures",
    "OnboardingAISkipped",
    "OnboardingCompleted",
    "OnboardingCurrentStep",
    "OnboardingPlaygroundValidated",
    "OverlayBottomOffset",
    "OverlayPosition",
    "OverlaySize",
    "PauseMediaDuringTranscription",
    "PlaygroundUsed",
    "PressAndHoldMode",
    "PromptModeHotkeyShortcut",
    "PromptModeSelectedPromptID",
    "PromptModeShortcutEnabled",
    "RemoveFillerWordsEnabled",
    "RewriteModeHotkeyShortcut",
    "RewriteModeLinkedToGlobal",
    "RewriteModeSelectedModel",
    "RewriteModeSelectedProviderID",
    "RewriteModeShortcutEnabled",
    "SaveTranscriptionHistory",
    "SavedProviders",
    "SecondaryDictationPromptOff",
    "SelectedAIModel",
    "SelectedCohereLanguage",
    "SelectedDictationPromptID",
    "SelectedEditPromptID",
    "SelectedModelByProvider",
    "SelectedProviderID",
    "SelectedRewritePromptID",
    "SelectedSpeechModel",
    "SelectedTranscriptionProvider",
    "SelectedWritePromptID",
    "ShareAnonymousAnalytics",
    "ShowInDock",
    "ShowThinkingTokens",
    "SyncAudioDevicesWithSystem",
    "TextInsertionMode",
    "TranscriptionPreviewCharLimit",
    "TranscriptionSoundIndependentVolume",
    "TranscriptionSoundVolume",
    "TranscriptionStartSound",
    "UserTypingWPM",
    "VisualizerNoiseThreshold",
    "VocabularyBoostingEnabled",
    "WeekendsDontBreakStreak",
    "WhisperModelSize",
}

DENY_KEYS = {
    "AnalyticsAnonymousInstallID",
    "AnalyticsFirstOpenAt",
    "AvailableAIModels",
    "AvailableModelsByProvider",
    "AXLastPromptAt",
    "CommandModeChatSessions",
    "CommandModeCurrentChatID",
    "ExternalCoreMLArtifactsDirectories",
    "FluidVoice_AccessibilityRestartPending",
    "FluidVoice_HasAutoRestartedForAccessibility",
    "LastUpdateCheckDate",
    "OverlayBottomOffsetMigratedTo50",
    "PreferredInputDeviceUID",
    "PreferredOutputDeviceUID",
    "ProviderAPIKeyIdentifiers",
    "ProviderAPIKeys",
    "SnoozedUpdateVersion",
    "TranscriptionHistoryEntries",
    "UpdatePromptSnoozedUntil",
    "VerifiedProviderFingerprints",
}

DENY_PREFIXES = (
    "NSNav",
    "NSSplitView",
    "NSWindow Frame",
)

SECRET_FIELD_NAMES = {
    "apiKey",
    "api_key",
    "authorization",
    "bearerToken",
    "credential",
    "credentials",
    "password",
    "secret",
    "token",
}

SECRET_STRING_MARKERS = (
    "-----BEGIN PRIVATE KEY-----",
    "AKIA",
    "ghp_",
    "sk-",
    "xoxb-",
)


class FluidVoiceConfigError(ValueError):
    """Raised when the managed FluidVoice config is invalid or unsafe."""


def load_plist(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    with path.open("rb") as handle:
        data = plistlib.load(handle)
    if not isinstance(data, dict):
        raise FluidVoiceConfigError(f"Preference plist is not a dictionary: {path}")
    return data


def try_decode_json_data(value: bytes) -> Any | None:
    try:
        text = value.decode("utf-8")
        return json.loads(text)
    except (UnicodeDecodeError, json.JSONDecodeError):
        return None


def sanitize_secret_fields(value: Any) -> Any:
    if isinstance(value, dict):
        sanitized: dict[str, Any] = {}
        for key, nested in value.items():
            if str(key) in SECRET_FIELD_NAMES:
                sanitized[str(key)] = ""
            else:
                sanitized[str(key)] = sanitize_secret_fields(nested)
        return sanitized
    if isinstance(value, list):
        return [sanitize_secret_fields(item) for item in value]
    return value


def contains_local_path(value: Any) -> bool:
    home = str(Path.home())
    if isinstance(value, str):
        return home in value or "/Users/" in value or "file://" in value
    if isinstance(value, bytes):
        decoded = try_decode_json_data(value)
        if decoded is None:
            return False
        return contains_local_path(decoded)
    if isinstance(value, dict):
        return any(contains_local_path(item) for item in value.values())
    if isinstance(value, list):
        return any(contains_local_path(item) for item in value)
    return False


def contains_secret_marker(value: Any) -> bool:
    if isinstance(value, str):
        return any(marker in value for marker in SECRET_STRING_MARKERS)
    if isinstance(value, bytes):
        decoded = try_decode_json_data(value)
        if decoded is None:
            return False
        return contains_secret_marker(decoded)
    if isinstance(value, dict):
        for key, nested in value.items():
            if str(key) in SECRET_FIELD_NAMES and nested not in (None, ""):
                return True
            if contains_secret_marker(nested):
                return True
        return False
    if isinstance(value, list):
        return any(contains_secret_marker(item) for item in value)
    return False


def is_safe_key(key: str) -> bool:
    if key in DENY_KEYS:
        return False
    if any(key.startswith(prefix) for prefix in DENY_PREFIXES):
        return False
    return key in SAFE_KEYS


def plist_value_to_config_value(value: Any) -> Any:
    if isinstance(value, bytes):
        decoded = try_decode_json_data(value)
        if decoded is not None:
            return {
                TYPE_KEY: "json-data",
                "value": sanitize_secret_fields(decoded),
            }
        return {
            TYPE_KEY: "data",
            "base64": base64.b64encode(value).decode("ascii"),
        }
    if isinstance(value, dt.datetime):
        return {
            TYPE_KEY: "date",
            "value": value.isoformat(),
        }
    if isinstance(value, dict):
        return {str(key): plist_value_to_config_value(nested) for key, nested in value.items()}
    if isinstance(value, list):
        return [plist_value_to_config_value(item) for item in value]
    return value


def config_value_to_plist_value(value: Any) -> Any:
    if isinstance(value, dict) and value.get(TYPE_KEY) == "json-data":
        return json.dumps(value.get("value"), ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    if isinstance(value, dict) and value.get(TYPE_KEY) == "data":
        return base64.b64decode(value.get("base64", ""), validate=True)
    if isinstance(value, dict) and value.get(TYPE_KEY) == "date":
        return dt.datetime.fromisoformat(str(value.get("value", "")).replace("Z", "+00:00"))
    if isinstance(value, dict):
        return {str(key): config_value_to_plist_value(nested) for key, nested in value.items()}
    if isinstance(value, list):
        return [config_value_to_plist_value(item) for item in value]
    return value


def capture_preferences(source_plist: Path) -> tuple[dict[str, Any], dict[str, str]]:
    source = load_plist(source_plist)
    captured: dict[str, Any] = {}
    skipped: dict[str, str] = {}

    for key in sorted(source):
        value = source[key]
        if not is_safe_key(key):
            skipped[key] = "not managed"
            continue
        if contains_local_path(value):
            skipped[key] = "local path"
            continue

        config_value = plist_value_to_config_value(value)
        if contains_secret_marker(config_value):
            skipped[key] = "secret marker"
            continue
        captured[key] = config_value

    return captured, skipped


def load_config(config_path: Path) -> dict[str, Any]:
    with config_path.open("r", encoding="utf-8") as handle:
        config = json.load(handle)
    if not isinstance(config, dict):
        raise FluidVoiceConfigError("FluidVoice config root must be a JSON object")
    return config


def managed_preferences(config: dict[str, Any]) -> dict[str, Any]:
    prefs = config.get("managedPreferences")
    if not isinstance(prefs, dict):
        raise FluidVoiceConfigError("FluidVoice config must include a managedPreferences object")
    return prefs


def validate_config(config: dict[str, Any]) -> None:
    if config.get("$schema") != SCHEMA:
        raise FluidVoiceConfigError(f"Unexpected FluidVoice config schema: {config.get('$schema')!r}")
    if config.get("domain") != DOMAIN:
        raise FluidVoiceConfigError(f"Unexpected FluidVoice domain: {config.get('domain')!r}")

    prefs = managed_preferences(config)
    for key, value in prefs.items():
        if key in DENY_KEYS or any(key.startswith(prefix) for prefix in DENY_PREFIXES):
            raise FluidVoiceConfigError(f"Refusing to manage unsafe FluidVoice preference: {key}")
        if key not in SAFE_KEYS:
            raise FluidVoiceConfigError(f"FluidVoice preference is not allowlisted: {key}")
        if contains_local_path(value):
            raise FluidVoiceConfigError(f"FluidVoice preference contains a local path: {key}")
        if contains_secret_marker(value):
            raise FluidVoiceConfigError(f"FluidVoice preference contains a secret-like value: {key}")
        config_value_to_plist_value(value)


def config_document(captured: dict[str, Any]) -> dict[str, Any]:
    return {
        "$schema": SCHEMA,
        "domain": DOMAIN,
        "description": "Dotfiles-managed non-secret FluidVoice UserDefaults preferences. Provider API keys, transcription history, device IDs, local paths, and macOS privacy permissions are intentionally excluded.",
        "managedPreferences": captured,
    }


def write_json_atomically(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    tmp_path = path.with_name(f".{path.name}.tmp")
    try:
        tmp_path.write_text(text, encoding="utf-8")
        os.replace(tmp_path, path)
    finally:
        if tmp_path.exists():
            tmp_path.unlink()


def write_plist(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as handle:
        plistlib.dump(value, handle, fmt=plistlib.FMT_BINARY, sort_keys=True)


def backup_existing_file(path: Path) -> Path | None:
    if not path.exists():
        return None
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_path = path.with_name(f"{path.name}.backup.{stamp}")
    shutil.copy2(path, backup_path)
    return backup_path


def should_use_defaults_import() -> bool:
    return sys.platform == "darwin" and shutil.which("defaults") is not None


def import_domain(domain: str, plist_path: Path) -> None:
    subprocess.run(["defaults", "import", domain, str(plist_path)], check=True)


def capture_command(args: argparse.Namespace) -> int:
    captured, skipped = capture_preferences(Path(args.source_plist).expanduser())
    document = config_document(captured)
    validate_config(document)

    if args.dry_run:
        print(f"source={Path(args.source_plist).expanduser()}")
        print(f"preferences_seen={len(captured) + len(skipped)}")
        print(f"preferences_captured={len(captured)}")
        print(f"preferences_skipped={len(skipped)}")
        for key in sorted(captured):
            print(key)
        return 0

    config_path = Path(args.config).expanduser()
    write_json_atomically(config_path, document)
    print(f"Captured {len(captured)} safe FluidVoice preferences into {config_path}")
    if skipped:
        print(f"Skipped {len(skipped)} unmanaged, local, or private preferences")
    return 0


def validate_command(args: argparse.Namespace) -> int:
    config_path = Path(args.config).expanduser()
    config = load_config(config_path)
    validate_config(config)
    print(f"FluidVoice config valid: {config_path}")
    print(f"Managed preferences: {len(managed_preferences(config))}")
    return 0


def apply_command(args: argparse.Namespace) -> int:
    config_path = Path(args.config).expanduser()
    prefs_plist = Path(args.prefs_plist).expanduser()
    config = load_config(config_path)
    validate_config(config)
    managed = {key: config_value_to_plist_value(value) for key, value in managed_preferences(config).items()}

    existing = load_plist(prefs_plist)
    merged = copy.deepcopy(existing)
    merged.update(managed)

    if args.dry_run:
        print(f"domain={DOMAIN}")
        print(f"config={config_path}")
        print(f"prefs_plist={prefs_plist}")
        print(f"managed_preferences={len(managed)}")
        for key in sorted(managed):
            print(key)
        return 0

    if not args.output_plist and existing == merged:
        print("FluidVoice preferences already match the managed config")
        return 0

    backup_path = backup_existing_file(prefs_plist)
    if backup_path is not None:
        print(f"Backed up existing FluidVoice preferences to {backup_path}")

    if args.output_plist:
        write_plist(Path(args.output_plist).expanduser(), merged)
        print(f"Wrote merged FluidVoice preferences to {args.output_plist}")
        return 0

    if should_use_defaults_import():
        with tempfile.NamedTemporaryFile(suffix=".plist", delete=False) as tmp:
            tmp_path = Path(tmp.name)
            plistlib.dump(merged, tmp, fmt=plistlib.FMT_BINARY, sort_keys=True)
        try:
            import_domain(DOMAIN, tmp_path)
        finally:
            tmp_path.unlink(missing_ok=True)
        print(f"Imported FluidVoice preferences into {DOMAIN}")
    else:
        write_plist(prefs_plist, merged)
        print(f"Wrote FluidVoice preferences to {prefs_plist}")

    print("Quit and relaunch FluidVoice if the updated settings are not visible immediately.")
    return 0


def self_test() -> int:
    tmp = Path(tempfile.mkdtemp())
    try:
        source_plist = tmp / "com.FluidApp.app.plist"
        config_path = tmp / "config.json"
        output_plist = tmp / "merged.plist"

        source = {
            "AccentColorOption": "auto",
            "AnalyticsAnonymousInstallID": "00000000-0000-0000-0000-000000000000",
            "CommandModeChatSessions": b"private history",
            "DefaultDictationPromptOverride": "Keep output concise.",
            "HotkeyShortcutKey": json.dumps({"keyCode": 61, "modifierFlagsRawValue": 0}).encode("utf-8"),
            "PreferredInputDeviceUID": "local-device",
            "ProviderAPIKeys": {"openai": "sk-test"},
            "SavedProviders": json.dumps(
                [
                    {
                        "id": "custom-local",
                        "name": "Local",
                        "baseURL": "http://localhost:11434/v1",
                        "apiKey": "sk-test",
                        "models": ["llama"],
                    }
                ]
            ).encode("utf-8"),
            "SelectedProviderID": "openai",
            "TranscriptionHistoryEntries": b"private history",
        }
        write_plist(source_plist, source)

        capture_args = argparse.Namespace(source_plist=str(source_plist), config=str(config_path), dry_run=False)
        capture_command(capture_args)
        config = load_config(config_path)
        prefs = managed_preferences(config)

        assert "AccentColorOption" in prefs
        assert "DefaultDictationPromptOverride" in prefs
        assert "HotkeyShortcutKey" in prefs
        assert "SavedProviders" in prefs
        assert "SelectedProviderID" in prefs
        assert "AnalyticsAnonymousInstallID" not in prefs
        assert "CommandModeChatSessions" not in prefs
        assert "PreferredInputDeviceUID" not in prefs
        assert "ProviderAPIKeys" not in prefs
        assert "TranscriptionHistoryEntries" not in prefs
        assert prefs["SavedProviders"]["value"][0]["apiKey"] == ""

        validate_config(config)

        existing_plist = tmp / "existing.plist"
        write_plist(existing_plist, {"UnmanagedPreference": True})
        apply_args = argparse.Namespace(
            config=str(config_path),
            prefs_plist=str(existing_plist),
            output_plist=str(output_plist),
            dry_run=False,
        )
        apply_command(apply_args)
        merged = load_plist(output_plist)
        assert merged["UnmanagedPreference"] is True
        assert merged["SelectedProviderID"] == "openai"
        assert json.loads(merged["SavedProviders"].decode("utf-8"))[0]["apiKey"] == ""
        print("FluidVoice config helper self-test passed")
        return 0
    finally:
        shutil.rmtree(tmp)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    capture = subparsers.add_parser("capture", help="capture safe preferences from the live plist")
    capture.add_argument("--source-plist", default=str(DEFAULT_PREFS_PLIST))
    capture.add_argument("--config", default=str(DEFAULT_CONFIG))
    capture.add_argument("--dry-run", action="store_true", help="list captured keys without writing")

    validate = subparsers.add_parser("validate", help="validate the managed config")
    validate.add_argument("--config", default=str(DEFAULT_CONFIG))

    apply = subparsers.add_parser("apply", help="merge and apply the managed config")
    apply.add_argument("--config", default=str(DEFAULT_CONFIG))
    apply.add_argument("--prefs-plist", default=str(DEFAULT_PREFS_PLIST))
    apply.add_argument("--dry-run", action="store_true", help="list managed keys without writing")
    apply.add_argument("--output-plist", default="", help="write merged plist here instead of importing")

    subparsers.add_parser("self-test", help="run synthetic capture/apply tests")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        if args.command == "capture":
            return capture_command(args)
        if args.command == "validate":
            return validate_command(args)
        if args.command == "apply":
            return apply_command(args)
        if args.command == "self-test":
            return self_test()
    except (
        FluidVoiceConfigError,
        OSError,
        plistlib.InvalidFileException,
        json.JSONDecodeError,
        subprocess.CalledProcessError,
        ValueError,
    ) as exc:
        print(f"FluidVoice config error: {exc}", file=sys.stderr)
        return 1
    raise AssertionError(f"Unhandled command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
