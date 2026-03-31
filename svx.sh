#!/usr/bin/env bash
set -euo pipefail

# --- Constants ---
readonly VERSION="1.0.0"
readonly SCRIPT_NAME="SvxLink Admin"

# --- Root check ---
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root (sudo ./svx.sh)" >&2
    exit 1
fi

# --- Dialog detection ---
DIALOG=""
if command -v dialog &>/dev/null; then
    DIALOG="dialog"
elif command -v whiptail &>/dev/null; then
    DIALOG="whiptail"
else
    echo "Error: Neither 'dialog' nor 'whiptail' found." >&2
    echo "Install one with: sudo apt install dialog" >&2
    exit 1
fi

# --- Temp file for dialog output ---
DIALOG_OUT=$(mktemp)
trap 'rm -f "$DIALOG_OUT"' EXIT

# --- Editor detection ---
EDITOR="${EDITOR:-$(command -v nano || command -v vi || echo "vi")}"
