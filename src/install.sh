#!/bin/bash
# Installs Caffeinate Doubleshot as a root LaunchDaemon.
#
#   Latest release:  curl -fsSL https://github.com/floschu/caffeinate-doubleshot/releases/latest/download/install.sh | sudo bash
#   From a clone:    ./src/install.sh
set -euo pipefail

VERSION=dev   # set by the release workflow
RELEASE_URL="https://github.com/floschu/caffeinate-doubleshot/releases/download/v$VERSION"
LABEL=at.flosch.caffeinate-doubleshot
# Only root can write here. /usr/local/bin belongs to the user on Intel Macs with
# Homebrew, and launchd runs whatever sits at the daemon path as root.
DAEMON_DIR=/Library/PrivilegedHelperTools
SELF="${BASH_SOURCE[0]:-}"

[ "$(uname)" = Darwin ] || { echo "Caffeinate Doubleshot only works on macOS." >&2; exit 1; }

# Re-run the whole script as root so sudo asks for the password only once.
if [ "$(id -u)" -ne 0 ]; then
  [ -f "$SELF" ] && exec sudo bash "$SELF" "$@"
  echo "Please run with sudo: curl -fsSL $RELEASE_URL/install.sh | sudo bash" >&2
  exit 1
fi

# Use files next to this script, or download them from the same release when piped from curl.
src=""
if [ -f "$SELF" ]; then
  dir=$(cd "$(dirname "$SELF")" && pwd)
  [ -f "$dir/caffeinate-doubleshot.sh" ] && src=$dir
fi
if [ -z "$src" ]; then
  [ "$VERSION" != dev ] || { echo "Install from a release or a clone." >&2; exit 1; }
  src=$(mktemp -d)
  trap 'rm -rf "$src"' EXIT
  for f in caffeinate-doubleshot.sh doubleshot _doubleshot "$LABEL.plist"; do
    curl -fsSL "$RELEASE_URL/$f" -o "$src/$f"
  done
fi

mkdir -p "$DAEMON_DIR" /usr/local/bin
install -m 755 -o root -g wheel "$src/caffeinate-doubleshot.sh" "$DAEMON_DIR/"
install -m 755 -o root -g wheel "$src/doubleshot" /usr/local/bin/
rm -f /usr/local/bin/caffeinate-doubleshot.sh   # where versions up to 1.1.0 kept the daemon
install -m 644 -o root -g wheel "$src/$LABEL.plist" /Library/LaunchDaemons/
mkdir -p /usr/local/share/zsh/site-functions   # in the default zsh fpath on macOS
install -m 644 -o root -g wheel "$src/_doubleshot" /usr/local/share/zsh/site-functions/
# newsyslog rotates the log at 100 KB and keeps 3 compressed archives.
printf '/var/log/caffeinate-doubleshot.log\t644\t3\t100\t*\tJ\n' >/etc/newsyslog.d/caffeinate-doubleshot.conf

# An update keeps a daemon the user disabled with `doubleshot disable` stopped.
if launchctl print-disabled system | grep -E "\"$LABEL\" => (disabled|true)" >/dev/null; then
  launchctl bootout "system/$LABEL" 2>/dev/null || true
  echo "Caffeinate Doubleshot $VERSION installed. It is disabled, run 'doubleshot enable' to turn it on."
  exit 0
fi
/usr/local/bin/doubleshot enable >/dev/null   # restarts a running daemon
echo "Caffeinate Doubleshot $VERSION installed. Run 'doubleshot' to see its status."
