# svx

Interactive terminal tool for administering [SvxLink](https://github.com/sm0svx/svxlink) services on a Raspberry Pi.

## Features

- Start / Stop / Restart / Reload services
- Detailed service status and live log following (journald or file)
- Edit configuration, GPIO, and environment files
- Enable / Disable services at boot
- GPIO setup restart
- Alsamixer integration (auto-detects USB audio device)
- Log rotation check and auto-fix
- Live system info: service status, CPU temperature, uptime, last boot
- Audio Calibration tool for adjusting audio level on Rx and TX
- Signal detector Calibration Tool for adjusting CTCSS tone sensitivity

## Services managed

- `svxlink.service` — Main repeater controller
- `remotetrx.service` — Remote transceiver
- `svxreflector.service` — Reflector/conference server
- `svxlink_gpio_setup.service` — GPIO pin setup

## Requirements

- Raspberry Pi (or Debian-based system) with SvxLink installed
- `dialog` or `whiptail` (auto-detected, will offer to install if missing)

## Install

```bash
sudo curl -sL https://raw.githubusercontent.com/audric/svxlink-cmd/master/svx -o /usr/local/bin/svx && sudo chmod +x /usr/local/bin/svx
```

## Usage

```bash
sudo svx
```

## Screenshot

```
○ SvxLink  ○ RemoteTRX  ○ SvxReflector | 48°C  Up 3d 2h  Since 2026-03-28 14:30
┌──────────── Svx Admin v1.0.0 ────────────┐
│                                           │
│  Choose an action:                        │
│ ┌───────────────────────────────────────┐ │
│ │  1  Start service                     │ │
│ │  2  Stop service                      │ │
│ │  3  Restart service                   │ │
│ │  4  Reload config (SIGHUP)            │ │
│ │  ─  ─── Monitoring ─────────          │ │
│ │  5  Show detailed status              │ │
│ │  6  Follow live logs                  | |
| |  7  System health check               │ │
│ │  ─  ─── Configuration ──────          │ │
│ │  8  Edit config file                  │ │
│ │  9  Edit GPIO config                  │ │
│ │ 10 Edit environment defaults          │ │
│ │  ─  ─── Audio ──────────────          │ │
│ │ 11  Alsamixer                         │ │
│ │  ─  ─── Maintenance ────────          │ │
│ │ 12  Check log rotation                │ │
│ │  ─  ─── Boot & GPIO ────────          │ │
│ │ 13  Enable service at boot            │ │
│ │ 14  Disable service at boot           │ │
│ │ 15  Restart GPIO setup                │ │
│ | 16  Audio Calibration tool            | |
| | 17  Signal Level Detector Calibration | |
| |───────────────────────────────────────┘ │
│          <OK>          <Quit>             │
└───────────────────────────────────────────┘
```

## Author

[Audric IW1GEU](https://github.com/audric)

[Rob VK5TRM](https://github.com/vk5trm)

## Other projects

Check out [SvxReflectorDashboard](https://github.com/audric/SvxReflectorDashboard) — a web dashboard for SvxReflector.

## License

GPL-3.0
