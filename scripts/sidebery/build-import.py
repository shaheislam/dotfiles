#!/usr/bin/env -S uv run --script --quiet
# /// script
# requires-python = ">=3.10"
# dependencies = ["pyyaml>=6.0"]
# ///
"""
build-import.py — generate a Sidebery-importable JSON from url-routing.yaml.

Self-bootstrapping: PEP 723 inline metadata lets `uv run` provision PyYAML
in an ephemeral env on first run — no global pip install needed.
Falls back to plain `python3` if you preinstall pyyaml yourself.

Reads:
  ~/dotfiles/.config/sidebery/url-routing.yaml
  ~/Library/Application Support/Firefox/Profiles/<profile>/containers.json
    (auto-discovered; falls back to default name->container-N mapping)

Writes:
  ~/dotfiles/.config/sidebery/sidebery-import.json
  ~/dotfiles/.config/sidebery/pinning-helper.md

Portability:
  - Resolves container names to live cookieStoreIds per device.
  - Never bakes machine-specific paths into the JSON.
  - Safe to re-run; output is fully deterministic given the same input
    (uuids are stable hashes of panel name / rule index).
"""

from __future__ import annotations

import hashlib
import json
import sys
import uuid
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:
    sys.exit("PyYAML required: pip install pyyaml  (or: pipx install pyyaml)")


REPO = Path(__file__).resolve().parents[2]
YAML_PATH = REPO / ".config/sidebery/url-routing.yaml"
OUT_JSON = REPO / ".config/sidebery/sidebery-import.json"
PIN_DOC = REPO / ".config/sidebery/pinning-helper.md"

# Mozilla default name <-> userContextId fallback (used when containers.json
# can't be resolved or names are localised null). Firefox Sync keeps these
# stable across devices for default identities.
DEFAULT_NAME_TO_CTX = {
    "Personal": 1,
    "Work": 2,
    "Banking": 3,
    "Shopping": 4,
}


def stable_id(*parts: str) -> str:
    """Deterministic UUIDv4-shaped string from input parts."""
    h = hashlib.sha1("\x1f".join(parts).encode()).hexdigest()
    return f"{h[0:8]}-{h[8:12]}-4{h[13:16]}-a{h[17:20]}-{h[20:32]}"


def find_firefox_profile() -> Path | None:
    base = Path.home() / "Library/Application Support/Firefox/Profiles"
    if not base.is_dir():
        return None
    # Prefer the most recently modified `.default-release` profile.
    candidates = sorted(
        [p for p in base.iterdir() if p.is_dir()],
        key=lambda p: (p.name.endswith("default-release"), p.stat().st_mtime),
        reverse=True,
    )
    return candidates[0] if candidates else None


# Mozilla's built-in identities use l10nIDs instead of literal names.
L10N_TO_NAME = {
    "userContextPersonal.label": "Personal",
    "userContextWork.label": "Work",
    "userContextBanking.label": "Banking",
    "userContextShopping.label": "Shopping",
}


def resolve_containers() -> dict[str, str]:
    """name -> cookieStoreId. Falls back to default mapping on miss."""
    name_to_csid: dict[str, str] = {}
    profile = find_firefox_profile()
    if profile is not None:
        cj = profile / "containers.json"
        if cj.is_file():
            data = json.loads(cj.read_text())
            for ident in data.get("identities", []):
                if not ident.get("public", True):
                    continue
                name = ident.get("name") or L10N_TO_NAME.get(ident.get("l10nID", ""))
                ctx = ident.get("userContextId")
                if name and ctx is not None:
                    name_to_csid[name] = f"firefox-container-{ctx}"
    # Backfill with defaults (in case Throwaway / new ones not yet created).
    for n, ctx in DEFAULT_NAME_TO_CTX.items():
        name_to_csid.setdefault(n, f"firefox-container-{ctx}")
    return name_to_csid


def panel_obj(spec: dict[str, Any], name_to_csid: dict[str, str]) -> dict[str, Any]:
    name = spec["name"]
    container_name = spec.get("container")
    if container_name and container_name not in name_to_csid:
        # New container not yet present on this device. Use sentinel — Sidebery
        # will show panel without binding until you create the container in
        # about:preferences#containers, then re-import.
        cookieStoreId = "none"
        print(
            f"  ! container '{container_name}' not found on this device for "
            f"panel '{name}' — falling back to 'none'. Create the container "
            f"and re-run if you want binding.",
            file=sys.stderr,
        )
    else:
        cookieStoreId = name_to_csid.get(container_name, "none") if container_name else "none"

    move_rules = []
    for idx, pattern in enumerate(spec.get("rules") or []):
        move_rules.append(
            {
                "id": stable_id("rule", name, str(idx), pattern),
                "active": True,
                "containerId": cookieStoreId,
                # Sidebery's MoveRule uses regex when pattern starts/ends with '/'.
                "url": pattern,
            }
        )

    return {
        "type": "tabs",
        "id": stable_id("panel", name),
        "name": name,
        "color": spec.get("color", "toolbar"),
        "iconSVG": spec.get("icon", "icon_tabs"),
        "iconIMGSrc": "",
        "iconIMG": "",
        "lockedPanel": False,
        "skipOnSwitching": False,
        "noEmpty": spec.get("no_empty", False),
        "newTabCtx": cookieStoreId,
        "dropTabCtx": cookieStoreId,
        "moveRules": move_rules,
        "moveExcludedTo": -1,
        "bookmarksFolderId": -1,
        "newTabBtns": [],
        "srcPanelConfig": None,
        "urlRulesActive": bool(move_rules),
    }


def main() -> int:
    if not YAML_PATH.is_file():
        sys.exit(f"missing {YAML_PATH}")
    spec = yaml.safe_load(YAML_PATH.read_text())
    name_to_csid = resolve_containers()

    print("Resolved containers:")
    for n, csid in sorted(name_to_csid.items()):
        print(f"  {n:<12} -> {csid}")

    panels = [panel_obj(p, name_to_csid) for p in spec["panels"]]

    # The export shape Sidebery accepts via Settings → Help → Import.
    out = {
        "ver": "5.5.2",
        "sidebar": {
            "panels": panels,
            # Nav order matches panel order; no separators/buttons added.
            "nav": [p["id"] for p in panels],
        },
    }
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(out, indent=2) + "\n")
    print(f"\nWrote {OUT_JSON} ({len(panels)} panels, {sum(len(p['moveRules']) for p in panels)} rules)")

    # Pinning helper — surface top hosts per panel from frecency, if available.
    write_pinning_helper(spec, name_to_csid)
    return 0


def write_pinning_helper(spec: dict[str, Any], name_to_csid: dict[str, str]) -> None:
    lines = [
        "# Pinning helper",
        "",
        "Pinned tabs aren't carried by the Sidebery import schema. After",
        "importing, right-click → 'Pin tab' for each of these inside the",
        "matching panel. List is generated from your `pinning` policy in",
        "`url-routing.yaml` (top-N-by-frecency, source=history).",
        "",
        "Run `scripts/sidebery/dump-history.py --json` to refresh frecency",
        "rankings, then re-run `build-import.py`.",
        "",
    ]
    pol = spec.get("pinning") or {}
    n = int(pol.get("per_panel_top_n", 3))
    src = pol.get("source", "history")
    if src != "history":
        lines.append(f"(pinning source = `{src}`; no automatic suggestions)\n")
    else:
        try:
            from importlib.util import spec_from_file_location, module_from_spec

            dump = REPO / "scripts/sidebery/dump-history.py"
            mod_spec = spec_from_file_location("dump_history", dump)
            mod = module_from_spec(mod_spec)
            mod_spec.loader.exec_module(mod)  # type: ignore[attr-defined]
            ranked = mod.host_frecency(days=365)
        except Exception as e:
            lines.append(f"(could not load history: {e})\n")
            ranked = []

        for panel in spec["panels"]:
            patterns = panel.get("rules") or []
            if not patterns:
                continue
            # crude match: any rule prefix-substring contained in host
            hits = []
            for host, score in ranked:
                for pat in patterns:
                    # strip "/regex/" wrappers and protocol/path noise
                    needle = pat.strip("/").replace("https://", "").replace("http://", "")
                    needle = needle.split("/", 1)[0].lstrip("*.").lstrip("^")
                    if needle and needle in host:
                        hits.append((host, score))
                        break
                if len(hits) >= n:
                    break
            if hits:
                lines.append(f"## {panel['name']}")
                lines.append("")
                for host, score in hits:
                    lines.append(f"- `{host}`  (frecency={score})")
                lines.append("")
    PIN_DOC.write_text("\n".join(lines))
    print(f"Wrote {PIN_DOC}")


if __name__ == "__main__":
    sys.exit(main())
