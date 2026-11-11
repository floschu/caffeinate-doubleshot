# AGENTS.md

## Project

Caffeinate Doubleshot keeps a MacBook awake with the lid closed while any `caffeinate` process runs, with no external display or power needed. It is a small Bash LaunchDaemon with no dependencies beyond macOS built-ins.

## Files

| File | Purpose |
|---|---|
| `src/caffeinate-doubleshot.sh` | The daemon. Polls every 3 seconds and toggles `pmset -a disablesleep`. Installed to `/usr/local/bin/`. |
| `src/doubleshot` | User command: `status`, `battery [0-100]`, `log`, `update`, `version`, `uninstall`. Installed to `/usr/local/bin/`. |
| `src/at.flosch.caffeinate-doubleshot.plist` | LaunchDaemon definition (`RunAtLoad`, `KeepAlive`, logs to `/var/log/caffeinate-doubleshot.log`). Installed to `/Library/LaunchDaemons/`. |
| `src/install.sh` | Installs or updates. Works from a clone or piped from curl (`curl ... \| sudo bash`), in which case it downloads the other files from the release it came from. |
| `.github/workflows/ci.yml` | Installs on a macOS runner and checks sleep toggling, the battery setting, update and uninstall. |
| `.github/workflows/release.yml` | On a `vX.Y.Z` tag: runs CI, sets `VERSION` in the scripts and publishes a GitHub release with the four `src/` files. |
| `/usr/local/etc/caffeinate-doubleshot.conf` | Not in the repo. Written by `doubleshot battery`, holds `MIN_BATTERY=<n>`. The daemon reads it on every poll. Missing means 15. |

Keep the top level to `README.md`, `AGENTS.md` and `.gitignore` (plus `.github/`). Scripts go in `src/`. The icon goes in `assets/`: `doubleshot.icon` is the Icon Composer source, `icon.png` the README image. Re-render it after icon changes:

```sh
"/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" assets/doubleshot.icon \
  --export-image --output-file assets/icon.png --platform macOS --rendition Default --width 200 --height 200 --scale 2
```

## Behaviour that must not break

- Any `caffeinate` process triggers it, regardless of what started it (Raycast, Terminal, other apps). Do not filter by parent process.
- When `caffeinate` ends while the lid is closed, the Mac must sleep immediately (`pmset sleepnow`).
- On battery below `MIN_BATTERY` (default 15%, set with `doubleshot battery`), sleep is allowed again even while `caffeinate` runs. The daemon parses the config file and never sources it, because it runs as root.
- Every exit path (daemon stop, uninstall) must leave `disablesleep` at 0. A stuck `disablesleep 1` keeps a closed laptop running and heating up.
- Installers and `doubleshot` must ask for the sudo password only once. sudo credential caching may be disabled on managed Macs, so re-exec the whole script as root instead of calling `sudo` per command.

## Conventions

- Bash only, macOS built-in tools only (`pmset`, `ioreg`, `pgrep`, `launchctl`). No Homebrew or other dependencies.
- Keep it small and readable. Prefer the simplest solution.
- Docs: no em or en dashes, prefer tables over lists.
- Commits and PRs: no tool attribution or "generated with" markers.

## Releases

Release with `git tag v1.2.3 && git push origin v1.2.3`. In the repo `VERSION=dev`. Only the release workflow sets a real version. Users install from `releases/latest/download/install.sh` and update with `doubleshot update`.

## Testing

CI (`.github/workflows/ci.yml`) runs on every push on a macOS runner. It lints, installs, checks that `caffeinate` toggles `SleepDisabled`, sets the battery limit, updates to the latest release and uninstalls. Quick local check:

```sh
bash -n src/caffeinate-doubleshot.sh src/install.sh src/doubleshot
plutil -lint src/at.flosch.caffeinate-doubleshot.plist
```

Runners have no lid or battery, so test these on a real MacBook after `./src/install.sh`:

| Scenario | Expected |
|---|---|
| `caffeinate` running, close lid on battery, nothing attached | Mac stays awake (no `Sleep` entries in `pmset -g log`) |
| `caffeinate -t 60`, close lid | `pmset -g log` shows `Software Sleep` about 60 s later |
| On battery, `doubleshot battery 100`, start `caffeinate`, close lid | Mac sleeps within ~3 s |

State changes are logged to `/var/log/caffeinate-doubleshot.log` (`doubleshot log`).
