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

# --- Services ---
readonly SERVICES=("svxlink" "remotetrx" "svxreflector")

declare -A SERVICE_LABELS=(
    [svxlink]="SvxLink"
    [remotetrx]="RemoteTRX"
    [svxreflector]="SvxReflector"
)

declare -A CONFIG_FILES=(
    [svxlink]="/etc/svxlink/svxlink.conf"
    [remotetrx]="/etc/svxlink/remotetrx.conf"
    [svxreflector]="/etc/svxlink/svxreflector.conf"
)

declare -A ENV_FILES=(
    [svxlink]="/etc/default/svxlink"
    [remotetrx]="/etc/default/remotetrx"
    [svxreflector]="/etc/default/svxreflector"
)

readonly GPIO_CONF="/etc/svxlink/gpio.conf"

# Get service status as a word: active, inactive, failed, unknown
get_service_status() {
    systemctl is-active "${1}.service" 2>/dev/null || echo "unknown"
}

# Build a status summary string for the menu title
build_status_title() {
    local title=""
    for svc in "${SERVICES[@]}"; do
        local status
        status=$(get_service_status "$svc")
        local label="${SERVICE_LABELS[$svc]}"
        if [[ "$DIALOG" == "dialog" ]]; then
            case "$status" in
                active)  title+="\\Z2● ${label}\\Zn  " ;;
                failed)  title+="\\Z1● ${label}\\Zn  " ;;
                *)       title+="\\Z3○ ${label}\\Zn  " ;;
            esac
        else
            case "$status" in
                active)  title+="[UP] ${label}  " ;;
                failed)  title+="[FAIL] ${label}  " ;;
                *)       title+="[DOWN] ${label}  " ;;
            esac
        fi
    done
    echo "$title"
}
