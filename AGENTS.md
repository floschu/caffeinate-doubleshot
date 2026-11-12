# AGENTS.md

## Project

Caffeinate Doubleshot keeps a MacBook awake with the lid closed while any `caffeinate` process runs, with no external display or power needed. It is a small Bash LaunchDaemon with no dependencies beyond macOS built-ins.

## Files

| File | Purpose |
|---|---|
| `src/caffeinate-doubleshot.sh` | The daemon. Polls every 3 seconds and toggles `pmset -a disablesleep`. Installed to `/Library/PrivilegedHelperTools/`, which only root can write to. |
| `src/doubleshot` | User command: `status`, `enable`, `disable`, `battery [0-100]`, `log`, `update [version]`, `version`, `uninstall`. Installed to `/usr/local/bin/`. |
| `src/_doubleshot` | zsh completion for `doubleshot`. Installed to `/usr/local/share/zsh/site-functions/`, which is in the default fpath of macOS `/bin/zsh`. Keep its command list in step with `doubleshot`. |
| `src/at.flosch.caffeinate-doubleshot.plist` | LaunchDaemon definition (`RunAtLoad`, `KeepAlive`, logs to `/var/log/caffeinate-doubleshot.log`). Installed to `/Library/LaunchDaemons/`. |
| `src/install.sh` | Installs or updates. Works from a clone or piped from curl (`curl ... \| sudo bash`), in which case it downloads the other files from the release it came from. Also writes the newsyslog rule and restarts the daemon through `doubleshot enable`. |
| `.github/workflows/ci.yml` | Installs on a macOS runner and checks completion, sleep toggling, enable and disable, the battery setting, uninstall and update. |
| `.github/ci-helpers.sh` | Shell functions for CI steps, loaded through `BASH_ENV`. |
| `.github/workflows/release.yml` | On a `vX.Y.Z` tag: runs CI, sets `VERSION` in the scripts and publishes a GitHub release with the five `src/` files. |
| `/usr/local/etc/caffeinate-doubleshot.conf` | Not in the repo. Written by `doubleshot battery`, holds `MIN_BATTERY=<n>`. The daemon reads it on every poll. Missing means 15. |
| `/etc/newsyslog.d/caffeinate-doubleshot.conf` | Not in the repo. Written by `install.sh`. Rotates the log at 100 KB and keeps 3 archives. |

Keep the top level to `README.md`, `AGENTS.md` and `.gitignore` (plus `.github/`). Scripts go in `src/`. The icon goes in `assets/`: `doubleshot.icon` is the Icon Composer source, `icon.png` the README image. Re-render it after icon changes:

```sh
"/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" assets/doubleshot.icon \
  --export-image --output-file assets/icon.png --platform macOS --rendition Default --width 200 --height 200 --scale 2
```

## Behaviour that must not break

- Any `caffeinate` process triggers it, regardless of what started it (Raycast, Terminal, other apps). Do not filter by parent process.
- When `caffeinate` ends while the lid is closed, the Mac must sleep immediately (`pmset sleepnow`). Only when sleep was disabled before: a daemon start with the lid closed (boot in clamshell mode, `doubleshot enable` over SSH) must not sleep. The daemon starts from the current `SleepDisabled` value, so a leftover 1 from a killed daemon still leads to sleep.
- The daemon script lives in a root-only directory. On Intel Macs with Homebrew, `/usr/local/bin` belongs to the user, and launchd runs the script at the plist path as root.
- On battery below `MIN_BATTERY` (default 15%, set with `doubleshot battery`), sleep is allowed again even while `caffeinate` runs. The daemon parses the config file and never sources it, because it runs as root.
- Every exit path (daemon stop, `doubleshot disable`, uninstall) must leave `disablesleep` at 0. A stuck `disablesleep 1` keeps a closed laptop running and heating up.
- `doubleshot disable` uses `launchctl disable`, so it survives a reboot. An install or update keeps a disabled daemon stopped. Uninstall clears the flag with `launchctl enable`.
- Installers and `doubleshot` must ask for the sudo password only once. sudo credential caching may be disabled on managed Macs, so re-exec the whole script as root instead of calling `sudo` per command.

## Conventions

- Bash only, macOS built-in tools only (`pmset`, `ioreg`, `pgrep`, `launchctl`). No Homebrew or other dependencies.
- Keep it small and readable. Prefer the simplest solution.
- Docs: no em or en dashes, prefer tables over lists.
- Commits and PRs: no tool attribution or "generated with" markers.

## Releases

Release with `git tag -a v1.2.3 -m v1.2.3 && git push origin v1.2.3`. Only release when the owner asks for it. In the repo `VERSION=dev`. Only the release workflow sets a real version. Users install from `releases/latest/download/install.sh` and update with `doubleshot update`. `doubleshot update 1.2.3` installs a given release, also an older one, which is the way back for testing.

## Testing

CI (`.github/workflows/ci.yml`) runs on every push on a macOS runner. It lints, installs, checks the zsh completion, checks that `caffeinate` toggles `SleepDisabled`, disables and enables, sets the battery limit, uninstalls, and updates to the latest release. Quick local check:

```sh
bash -n src/caffeinate-doubleshot.sh src/install.sh src/doubleshot
zsh -n src/_doubleshot
plutil -lint src/at.flosch.caffeinate-doubleshot.plist
```

Runners have no lid or battery, so test these on a real MacBook after `./src/install.sh`:

| Scenario | Expected |
|---|---|
| `caffeinate` running, close lid on battery, nothing attached | Mac stays awake (no `Sleep` entries in `pmset -g log`) |
| `caffeinate -t 60`, close lid | `pmset -g log` shows `Software Sleep` about 60 s later |
| On battery, `doubleshot battery 100`, start `caffeinate`, close lid | Mac sleeps within ~3 s |
| External display attached, lid closed, no `caffeinate`, run `doubleshot enable` or reboot | Mac stays awake |

State changes are logged to `/var/log/caffeinate-doubleshot.log` (`doubleshot log`).
