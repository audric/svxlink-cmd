#!/usr/bin/env bash
set -uo pipefail

# --- Constants ---
readonly VERSION="1.0.0"
readonly SCRIPT_NAME="Svx Admin"

# --- Root check ---
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root (sudo ./svx.sh)" >&2
    exit 1
fi

# --- Dependency check ---
missing_pkgs=()

if ! command -v dialog &>/dev/null && ! command -v whiptail &>/dev/null; then
    missing_pkgs+=("dialog")
fi

if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
    echo "Missing packages: ${missing_pkgs[*]}"
    read -rp "Install them now? [Y/n] " answer
    case "${answer:-y}" in
        [Yy]*)
            apt-get update -qq && apt-get install -y "${missing_pkgs[@]}"
            ;;
        *)
            echo "Cannot continue without: ${missing_pkgs[*]}" >&2
            exit 1
            ;;
    esac
fi

# --- Dialog detection ---
DIALOG=""
if command -v dialog &>/dev/null; then
    DIALOG="dialog"
elif command -v whiptail &>/dev/null; then
    DIALOG="whiptail"
else
    echo "Error: dialog installation failed." >&2
    exit 1
fi

# --- Temp file for dialog output ---
DIALOG_OUT=$(mktemp)

# --- Custom dialog theme (dark, no blue) ---
DIALOGRC_FILE=$(mktemp)
trap 'rm -f "$DIALOG_OUT" "$DIALOGRC_FILE"' EXIT

if [[ "$DIALOG" == "dialog" ]]; then
    cat > "$DIALOGRC_FILE" <<'THEME'
use_shadow = OFF
use_colors = ON
screen_color = (WHITE,BLACK,ON)
shadow_color = (BLACK,BLACK,ON)
dialog_color = (WHITE,BLACK,OFF)
title_color = (GREEN,BLACK,ON)
border_color = (WHITE,BLACK,ON)
button_active_color = (WHITE,BLUE,ON)
button_inactive_color = (WHITE,BLACK,OFF)
button_key_active_color = (WHITE,BLUE,ON)
button_key_inactive_color = (WHITE,BLACK,ON)
button_label_active_color = (WHITE,BLUE,ON)
button_label_inactive_color = (WHITE,BLACK,ON)
menubox_color = (WHITE,BLACK,OFF)
menubox_border_color = (WHITE,BLACK,OFF)
menubox_border2_color = (WHITE,BLACK,OFF)
item_color = (WHITE,BLACK,OFF)
item_selected_color = (BLACK,WHITE,OFF)
tag_color = (GREEN,BLACK,ON)
tag_selected_color = (BLACK,WHITE,ON)
tag_key_color = (GREEN,BLACK,ON)
tag_key_selected_color = (BLACK,WHITE,ON)
check_color = (WHITE,BLACK,OFF)
check_selected_color = (BLACK,GREEN,ON)
uarrow_color = (GREEN,BLACK,ON)
darrow_color = (GREEN,BLACK,ON)
inputbox_color = (WHITE,BLACK,OFF)
inputbox_border_color = (WHITE,BLACK,ON)
form_active_text_color = (BLACK,GREEN,ON)
form_text_color = (WHITE,BLACK,OFF)
form_item_readonly_color = (WHITE,BLACK,ON)
gauge_color = (GREEN,BLACK,ON)
border2_color = (WHITE,BLACK,OFF)
searchbox_color = (WHITE,BLACK,OFF)
searchbox_title_color = (GREEN,BLACK,ON)
searchbox_border_color = (WHITE,BLACK,ON)
position_indicator_color = (GREEN,BLACK,ON)
THEME
    export DIALOGRC="$DIALOGRC_FILE"
fi

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

declare -A LOG_FILES=(
    [svxlink]="/var/log/svxlink"
    [remotetrx]="/var/log/remotetrx"
    [svxreflector]="/var/log/svxreflector"
)

readonly GPIO_CONF="/etc/svxlink/gpio.conf"

# Get service status as a word: active, inactive, failed, unknown
get_service_status() {
    local st
    st=$(systemctl is-active "${1}.service" 2>/dev/null) || true
    echo "${st:-unknown}"
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
                active)  title+="\Z2● ${label}\Zn  " ;;
                failed)  title+="\Z1● ${label}\Zn  " ;;
                *)       title+="\Z3○ ${label}\Zn  " ;;
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

# Build system info string for the title bar
build_sysinfo() {
    local info=""

    # CPU temperature
    local temp_file="/sys/class/thermal/thermal_zone0/temp"
    if [[ -r "$temp_file" ]]; then
        local raw
        raw=$(<"$temp_file")
        info+="${temp_file:+$((raw / 1000))°C}"
    fi

    # Uptime
    local up
    up=$(uptime -p 2>/dev/null | sed 's/up //;s/ days\?/d/;s/ hours\?/h/;s/ minutes\?/m/;s/,//g') || true
    [[ -n "$up" ]] && info+="  Up ${up}"

    # Last boot
    local last_boot
    last_boot=$(uptime -s 2>/dev/null) || true
    [[ -n "$last_boot" ]] && info+="  Since ${last_boot%:*}"

    echo "$info"
}

# =============================================================================
# Service Picker
# =============================================================================

# Sets PICKED_SERVICE to the chosen service name, or returns 1 on cancel.
PICKED_SERVICE=""
pick_service() {
    PICKED_SERVICE=""
    local prompt="${1:-Select a service:}"
    local items=()
    local i=1
    for svc in "${SERVICES[@]}"; do
        local status
        status=$(get_service_status "$svc")
        items+=("$i" "$(printf "%-14s(%s)" "${SERVICE_LABELS[$svc]}" "$status")")
        ((i++))
    done

    if [[ "$DIALOG" == "dialog" ]]; then
        dialog --colors --no-shadow --title " Select Service " \
            --menu "\n$prompt\n" 14 0 3 \
            "${items[@]}" 2>"$DIALOG_OUT" || return 1
    else
        whiptail --title " Select Service " \
            --menu "\n$prompt\n" 14 0 3 \
            "${items[@]}" 2>"$DIALOG_OUT" || return 1
    fi

    local choice
    choice=$(<"$DIALOG_OUT")
    PICKED_SERVICE="${SERVICES[$((choice - 1))]}"
    [[ -n "$PICKED_SERVICE" ]] || return 1
}

# =============================================================================
# Result Display
# =============================================================================

show_result() {
    local title="$1"
    local msg="$2"
    if [[ "$DIALOG" == "dialog" ]]; then
        dialog --colors --no-shadow --title "$title" --msgbox "$msg" 15 60
    else
        whiptail --title "$title" --msgbox "$msg" 15 60
    fi
}

# =============================================================================
# Service Control Actions
# =============================================================================

do_service_action() {
    local action="$1"
    pick_service "Select service to ${action}:" || return
    local svc="$PICKED_SERVICE"
    local output
    output=$(systemctl "$action" "${svc}.service" 2>&1) && \
        show_result "Success" "${SERVICE_LABELS[$svc]}: ${action} completed.\n\n${output}" || \
        show_result "Error" "${SERVICE_LABELS[$svc]}: ${action} failed.\n\n${output}"
}

action_start()   { do_service_action "start"; }
action_stop()    { do_service_action "stop"; }
action_restart() { do_service_action "restart"; }
action_reload()  { do_service_action "reload"; }
action_enable()  { do_service_action "enable"; }
action_disable() { do_service_action "disable"; }

# =============================================================================
# Monitoring Actions
# =============================================================================

action_status() {
    pick_service "Show status for:" || return
    local svc="$PICKED_SERVICE"
    local output
    output=$(systemctl status "${svc}.service" 2>&1 || true)
    show_result "${SERVICE_LABELS[$svc]} Status" "$output"
}

action_logs() {
    pick_service "Follow logs for:" || return
    local svc="$PICKED_SERVICE"
    local logfile="${LOG_FILES[$svc]}"
    local log_items=("journald" "$(printf "%-12s%s" "journalctl" "-u ${svc}.service")")
    if [[ -f "$logfile" ]]; then
        log_items+=("file" "$(printf "%-12s%s" "tail -f" "${logfile}")")
    fi

    if [[ "$DIALOG" == "dialog" ]]; then
        dialog --colors --no-shadow --title "Log Source" \
            --menu "\nChoose log source for ${SERVICE_LABELS[$svc]}:\n" 12 55 2 \
            "${log_items[@]}" 2>"$DIALOG_OUT" || return
    else
        whiptail --title "Log Source" \
            --menu "\nChoose log source for ${SERVICE_LABELS[$svc]}:\n" 12 55 2 \
            "${log_items[@]}" 2>"$DIALOG_OUT" || return
    fi

    local source
    source=$(<"$DIALOG_OUT")
    clear
    echo "=== Following logs for ${SERVICE_LABELS[$svc]} (Ctrl+C to return) ==="
    echo ""
    (
        trap 'exit 0' INT
        if [[ "$source" == "journald" ]]; then
            journalctl -u "${svc}.service" -f
        else
            tail -f "$logfile"
        fi
    )
}

# =============================================================================
# Configuration Actions
# =============================================================================

action_edit_config() {
    pick_service "Edit config for:" || return
    local svc="$PICKED_SERVICE"
    local conf="${CONFIG_FILES[$svc]}"
    if [[ ! -f "$conf" ]]; then
        show_result "Error" "Config file not found:\n${conf}"
        return
    fi
    $EDITOR "$conf"
}

action_edit_gpio() {
    if [[ ! -f "$GPIO_CONF" ]]; then
        show_result "Error" "GPIO config not found:\n${GPIO_CONF}"
        return
    fi
    $EDITOR "$GPIO_CONF"
}

action_edit_env() {
    pick_service "Edit environment for:" || return
    local svc="$PICKED_SERVICE"
    local envf="${ENV_FILES[$svc]}"
    if [[ ! -f "$envf" ]]; then
        show_result "Error" "Environment file not found:\n${envf}"
        return
    fi
    $EDITOR "$envf"
}

# =============================================================================
# GPIO Action
# =============================================================================

action_alsamixer() {
    local usb_card=""
    if [[ -f /proc/asound/cards ]]; then
        usb_card=$(awk '/USB-Audio/{print $1; exit}' /proc/asound/cards)
    fi
    if [[ -n "$usb_card" ]]; then
        alsamixer -c "$usb_card" || true
    else
        alsamixer || true
    fi
}

readonly LOGROTATE_CONF="/etc/logrotate.d/svxlink"
readonly LOGROTATE_CONTENT="/var/log/svxlink
/var/log/remotetrx
/var/log/svxreflector
{
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}"

action_check_logrotate() {
    # Check if any file-based logs exist
    local has_logs=false
    for svc in "${SERVICES[@]}"; do
        [[ -f "${LOG_FILES[$svc]}" ]] && has_logs=true && break
    done

    if [[ "$has_logs" == false ]]; then
        show_result "No File Logs" "No SvxLink file-based logs found.\n\nServices are logging to journald only.\nNo log rotation needed."
        return
    fi

    # File logs exist — check logrotate
    if ! command -v logrotate &>/dev/null; then
        show_result "Warning" "SvxLink is writing to log files but\nlogrotate is not installed.\n\nInstall it with:\n  apt install logrotate\n\nThen run this check again."
        return
    fi

    if [[ -f "$LOGROTATE_CONF" ]]; then
        local content
        content=$(<"$LOGROTATE_CONF")
        show_result "Log Rotation OK" "Config: ${LOGROTATE_CONF}\n\n${content}"
    else
        if [[ "$DIALOG" == "dialog" ]]; then
            dialog --colors --no-shadow --title " Log Rotation Missing " \
                --yesno "\nSvxLink is writing to log files but no\nlogrotate config was found.\n\nCreate ${LOGROTATE_CONF}?\n\nWeekly rotation, 4 copies, compressed.\n" 15 55 2>"$DIALOG_OUT"
        else
            whiptail --title " Log Rotation Missing " \
                --yesno "\nSvxLink is writing to log files but no\nlogrotate config was found.\n\nCreate ${LOGROTATE_CONF}?\n\nWeekly rotation, 4 copies, compressed.\n" 15 55 2>"$DIALOG_OUT"
        fi
        if [[ $? -eq 0 ]]; then
            echo "$LOGROTATE_CONTENT" > "$LOGROTATE_CONF"
            chmod 644 "$LOGROTATE_CONF"
            show_result "Success" "Created ${LOGROTATE_CONF}\n\nLog rotation is now active."
        fi
    fi
}

action_health_check() {
    local report=""

    # Disk usage
    report+="DISK USAGE\n"
    report+="$(df -h --output=target,size,used,avail,pcent / /boot 2>/dev/null | head -5)\n"
    report+="\n"

    # Top 10 CPU consuming processes
    report+="TOP 10 PROCESSES (CPU)\n"
    report+="$(ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | head -11)\n"

    if [[ "$DIALOG" == "dialog" ]]; then
        dialog --colors --no-shadow --title " System Health " \
            --msgbox "$report" 28 70
    else
        whiptail --title " System Health " \
            --msgbox "$report" 28 70
    fi
}

action_gpio_restart() {
    local output
    output=$(systemctl restart svxlink_gpio_setup.service 2>&1) && \
        show_result "Success" "GPIO setup restarted.\n\n${output}" || \
        show_result "Error" "GPIO setup restart failed.\n\n${output}"
}

# =============================================================================
# NEW FUNCTION: devcal with Section Selection added by VK5TRM
# =============================================================================

action_devcal_sections() {
    local conf="${CONFIG_FILES[svxlink]}"
    
    if [[ ! -f "$conf" ]]; then
        show_result "Error" "Config file not found:\n${conf}"
        return
    fi
    
    # Extract ALL section names starting with Rx or Tx (case-insensitive)
    local sections
    sections=$(grep -E '^\[(([Rr][Xx]|[Tt][Xx])[^]]*)\]' "$conf" | sed 's/\[//;s/\]//' | sort)
    
    if [[ -z "$sections" ]]; then
        show_result "No Radios Found" "No radio config sections found in:\n${conf}"
        return
    fi
    
    # Create menu items from sections
    local items=()
    local i=1
    while IFS= read -r section; do
        items+=("$i" "$section")
        ((i++))
    done <<< "$sections"
    
    if [[ "$DIALOG" == "dialog" ]]; then
        dialog --colors --no-shadow --title " Select Radio " \
            --menu "\nChoose a radio section:\n" 14 30 "${#items[@]}" \
            "${items[@]}" 2>"$DIALOG_OUT" || return
    else
        whiptail --title " Select Radio " \
            --menu "\nChoose a radio section:\n" 14 30 "${#items[@]}" \
            "${items[@]}" 2>"$DIALOG_OUT" || return
    fi
    
    local choice
    choice=$(<"$DIALOG_OUT")
    local selected_section
    selected_section=$(echo "$sections" | sed -n "${choice}p")
    
    # Determine flag based on section name (Rx or Tx)
    local flag
    if [[ "$selected_section" =~ ^[Rr][Xx] ]]; then
        flag="-r"
    elif [[ "$selected_section" =~ ^[Tt][Xx] ]]; then
        flag="-t"
    else
        show_result "Error" "Invalid section: ${selected_section}"
        return
    fi
    
    # Stop svxlink service
    clear
    echo "=== Stopping svxlink service ==="
    systemctl stop svxlink.service
    sleep 2
    
    # Run devcal with appropriate flag
    echo "=== Running devcal ${flag} ${selected_section} (Ctrl+C to stop) ==="
    echo ""
    (
        trap 'exit 0' INT
        devcal ${flag} "$conf" "$selected_section"
    )
    
    # Restart svxlink service
    echo ""
    echo "=== Restarting svxlink service ==="
    systemctl start svxlink.service
    sleep 2
    
    echo "Done! Press Enter to return to menu..."
    read -r
}

# =============================================================================
# Main Menu
# =============================================================================

main_menu() {
    local status_title sysinfo
    status_title=$(build_status_title)
    sysinfo=$(build_sysinfo)

    local W=30
    local menu_items=(
        "1"  "$(printf "%-${W}s" "Start service")"
        "2"  "$(printf "%-${W}s" "Stop service")"
        "3"  "$(printf "%-${W}s" "Restart service")"
        "4"  "$(printf "%-${W}s" "Reload config (SIGHUP)")"
        "─1" "$(printf "%-${W}s" "─── Monitoring ─────────")"
        "5"  "$(printf "%-${W}s" "Show detailed status")"
        "6"  "$(printf "%-${W}s" "Follow live logs")"
        "7"  "$(printf "%-${W}s" "System health check")"
        "─2" "$(printf "%-${W}s" "─── Configuration ──────")"
        "8"  "$(printf "%-${W}s" "Edit config file")"
        "9"  "$(printf "%-${W}s" "Edit GPIO config")"
        "10" "$(printf "%-${W}s" "Edit environment defaults")"
        "─3" "$(printf "%-${W}s" "─── Audio ──────────────")"
        "11" "$(printf "%-${W}s" "Alsamixer")"
        "─4" "$(printf "%-${W}s" "─── Maintenance ────────")"
        "12" "$(printf "%-${W}s" "Check log rotation")"
        "─5" "$(printf "%-${W}s" "─── Boot & GPIO ────────")"
        "13" "$(printf "%-${W}s" "Enable service at boot")"
        "14" "$(printf "%-${W}s" "Disable service at boot")"
        "15" "$(printf "%-${W}s" "Restart GPIO setup")"
        "─6" "$(printf "%-${W}s" "─── Calibration ────────")"
        "16" "$(printf "%-${W}s" "Run Audio Calibration Tool")"
    )

    if [[ "$DIALOG" == "dialog" ]]; then
        dialog --colors --no-shadow \
            --title " $SCRIPT_NAME v$VERSION " \
            --backtitle "$status_title | $sysinfo" \
            --cancel-label "Quit" \
            --menu "\nChoose an action:\n" 32 50 22 \
            "${menu_items[@]}" 2>"$DIALOG_OUT"
    else
        whiptail \
            --title " $SCRIPT_NAME v$VERSION " \
            --backtitle "$status_title | $sysinfo" \
            --cancel-button "Quit" \
            --menu "\nChoose an action:\n" 32 50 22 \
            "${menu_items[@]}" 2>"$DIALOG_OUT"
    fi
}

# =============================================================================
# Main Loop
# =============================================================================

while true; do
    main_menu || break

    choice=$(cat "$DIALOG_OUT")
    case "$choice" in
        1)  action_start ;;
        2)  action_stop ;;
        3)  action_restart ;;
        4)  action_reload ;;
        5)  action_status ;;
        6)  action_logs ;;
        7)  action_health_check ;;
        8)  action_edit_config ;;
        9)  action_edit_gpio ;;
        10) action_edit_env ;;
        11) action_alsamixer ;;
        12) action_check_logrotate ;;
        13) action_enable ;;
        14) action_disable ;;
        15) action_gpio_restart ;;
        16) action_devcal_sections ;;
        *)  ;; # separator selected, ignore
    esac
done

clear
echo "Goodbye!"
