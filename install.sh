#!/bin/sh
# One-shot installer for the svx SvxLink admin menu and the svx-vumeter RX meter.
#
#   curl -fsSL https://raw.githubusercontent.com/audric/svxlink-cmd/master/install.sh | sudo sh
#
# Installs the svx menu (a bash script) and a prebuilt, arch-matched svx-vumeter
# binary from the latest GitHub release. No compiler needed.
set -eu

REPO="audric/svxlink-cmd"
BINDIR="${BINDIR:-/usr/local/bin}"

command -v curl >/dev/null 2>&1 || { echo "install: curl is required" >&2; exit 1; }

# 1) The svx menu — a bash script, architecture-independent.
echo "Installing svx -> $BINDIR/svx"
curl -fsSL "https://raw.githubusercontent.com/$REPO/master/svx" -o "$BINDIR/svx"
chmod +x "$BINDIR/svx"

# 2) The svx-vumeter RX meter — a prebuilt binary for this machine's arch.
case "$(uname -m)" in
	armv6l)          arch=armv6 ;;
	armv7l)          arch=armv7 ;;
	aarch64 | arm64) arch=arm64 ;;
	x86_64 | amd64)  arch=amd64 ;;
	*) arch="" ; echo "install: no svx-vumeter build for '$(uname -m)' — RX meter skipped" >&2 ;;
esac

if [ -n "$arch" ]; then
	url="https://github.com/$REPO/releases/latest/download/svx-vumeter-linux-$arch"
	echo "Installing svx-vumeter ($arch) -> $BINDIR/svx-vumeter"
	tmp=$(mktemp)
	trap 'rm -f "$tmp"' EXIT
	if curl -fSL "$url" -o "$tmp"; then
		chmod +x "$tmp"
		mv "$tmp" "$BINDIR/svx-vumeter"
		trap - EXIT
	else
		echo "install: svx-vumeter download failed (no release asset yet?) — svx still installed" >&2
	fi
fi

echo "Done. Run: sudo svx"
