# Sidebery URL routing

Canonical source of truth for Sidebery panel + container + URL routing on
this machine and any Firefox-Sync'd device.

## Files

| Path | Role |
|---|---|
| `url-routing.yaml` | **SoT** — hand-edited. Defines panels, containers, URL rules, pinning policy. |
| `sidebery-import.json` | Generated. Drop-in import for Sidebery → Settings → Help → Import. |
| `pinning-helper.md` | Generated. Top-3 hosts per panel for manual pin-tab after import. |
| `keymap-alignment.md` | Hand-edited audit of tmux × Nvim × Aerospace × Ghostty × Sidebery bindings + recommended Sidebery rebinds. |
| `../../scripts/sidebery/build-import.py` | YAML → JSON generator. |
| `../../scripts/sidebery/dump-history.py` | Frecency dump from `places.sqlite`. |

## Workflow

```
edit url-routing.yaml
        │
        ▼
python3 scripts/sidebery/build-import.py
        │
        ▼
Firefox → about:addons → Sidebery → Settings → Help → Import settings
        │
        ▼
Pick sidebery-import.json, tick "Sidebar (panels, navigation, ...)"
        │
        ▼
Pin top tabs from pinning-helper.md manually (~90s)
```

## Cross-device portability

This profile is sync'd via Firefox Sync. The design assumes that:

- The **Multi-Account Containers** sync engine is on (it is by default once
  you sign into Sync), so `Personal/Work/Banking/Shopping` carry identical
  `userContextId`s across devices.
- A new **Throwaway** container won't sync until you create it on at least
  one device (`about:preferences#containers`). Once created, Sync pushes it
  to others. Until then, the import on a device without it will fall back
  to "no container binding" for the Scratch panel.
- The generator (`build-import.py`) resolves container names → live
  `firefox-container-N` IDs **at generate time** by reading
  `containers.json` from the active Firefox profile on whichever device
  you run it on. So the JSON output is device-local; the YAML is the
  portable artefact.

**Best practice**: run `build-import.py` and import on each device
separately. Don't sync the generated JSON across machines.

## Initial setup on a new device

1. `stow .` from `~/dotfiles` to materialise this directory.
2. In Firefox: create the **Throwaway** container manually
   (`about:preferences#containers` → Add new container → red / circle).
3. Run:
   ```fish
   python3 ~/dotfiles/scripts/sidebery/build-import.py
   ```
4. Firefox → about:addons → Sidebery → Settings → Help → Import.
5. Pick `~/dotfiles/.config/sidebery/sidebery-import.json`.
6. Tick "Sidebar" (panels + navigation). Leave others off unless intentional.
7. Open `pinning-helper.md` and pin the listed top-3 hosts per panel.

## Refreshing routes from history

Every quarter (or after a job change) regenerate the frecency view:

```fish
python3 ~/dotfiles/scripts/sidebery/dump-history.py --days 180 --limit 100
```

Add new high-frecency hosts to the matching panel in `url-routing.yaml`,
then rerun the generator.

## Privacy

- `sidebery-export.json` (the *raw* Sidebery export, if you ever drop one
  here for analysis) is `.gitignore`'d — it can contain pinned-tab URLs
  and snapshot data you may not want in git.
- `sidebery-import.json` is checked in: it's purely structural (panel +
  rule patterns) and contains no personal URL data beyond what's also in
  `url-routing.yaml`.
- `pinning-helper.md` may contain frecency rankings derived from your
  history — also `.gitignore`'d by default; flip locally if you want it
  in git.

## Gaps not solved by this setup

- **Pinned tab state** isn't carried by Sidebery's import schema → manual
  step (`pinning-helper.md` is the cheat sheet).
- **Cross-extension assignment** (e.g. Multi-Account Containers'
  `siteContainerMap`) is independent of Sidebery. If a site needs to
  open in container X regardless of how the link was clicked, set that
  up in MAC's UI as a second layer.
- **Cross-device history sync** is currently disabled
  (`services.sync.engine.history = false`). Routes recommended from this
  device only. Enable in `about:preferences#sync` if you want merged
  history → reroute after merge.
