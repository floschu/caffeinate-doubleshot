#!/bin/bash
# Installs Caffeinate Doubleshot as a root LaunchDaemon.
#
#   Latest release:  curl -fsSL https://github.com/floschu/caffeinate-doubleshot/releases/latest/download/install.sh | sudo bash
#   From a clone:    ./src/install.sh
set -euo pipefail

VERSION=dev   # set by the release workflow
RELEASE_URL="https://github.com/floschu/caffeinate-doubleshot/releases/download/v$VERSION"
LABEL=at.flosch.caffeinate-doubleshot
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
  for f in caffeinate-doubleshot.sh doubleshot "$LABEL.plist"; do
    curl -fsSL "$RELEASE_URL/$f" -o "$src/$f"
  done
fi

mkdir -p /usr/local/bin
install -m 755 -o root -g wheel "$src/caffeinate-doubleshot.sh" "$src/doubleshot" /usr/local/bin/
install -m 644 -o root -g wheel "$src/$LABEL.plist" /Library/LaunchDaemons/
launchctl bootout "system/$LABEL" 2>/dev/null || true
# bootout returns before the old service is gone. Bootstrapping too early fails with error 5.
for _ in $(seq 20); do
  launchctl print "system/$LABEL" >/dev/null 2>&1 || break
  sleep 0.5
done
launchctl bootstrap system "/Library/LaunchDaemons/$LABEL.plist"

echo "Caffeinate Doubleshot $VERSION installed. Run 'doubleshot' to see its status."
