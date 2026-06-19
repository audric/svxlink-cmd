# svx

Interactive terminal tool for administering [SvxLink](https://github.com/sm0svx/svxlink) services on a Raspberry Pi.

## Features

- Start / Stop / Restart / Reload services
- Detailed service status and live log following (journald or file)
- Edit configuration, GPIO, and environment files
- Enable / Disable services at boot
- GPIO setup restart
- Alsamixer integration (auto-detects USB audio device)
- Live RX input-level meter (VU bar) for setting capture gain — optional `svx-vumeter` helper
- Send the repeater ident on demand — transmits a known signal for TX/deviation checks
- Log rotation check and auto-fix
- Live system info: service status, CPU temperature, uptime, last boot

## Services managed

- `svxlink.service` — Main repeater controller
- `remotetrx.service` — Remote transceiver
- `svxreflector.service` — Reflector/conference server
- `svxlink_gpio_setup.service` — GPIO pin setup

## Requirements

- Raspberry Pi (or Debian-based system) with SvxLink installed
- `dialog` or `whiptail` — for the `svx` menu (auto-detected, offered for install if missing)
- `alsa-utils` — for the audio panel and volume persistence (offered for install if missing)

## Install

One command installs everything — the `svx` menu and the audio meter:

```bash
curl -fsSL https://raw.githubusercontent.com/audric/svxlink-cmd/master/install.sh | sudo sh
```

## Usage

```bash
sudo svx
```

## Audio calibration

Two helpers under the **Audio** menu make it easier to set RX and TX levels
without the edit → restart → key-up → listen loop:

- **RX level meter** — a live VU bar of the capture input, so you can set the
  mic/capture gain while watching the level in real time (aim for peaks below
  clipping). It stops the SvxLink service for the session to free the capture
  device and restarts it on exit.

- **Send ident (TX readback)** — makes the repeater transmit a known readback
  on demand, so you can check TX level / deviation on the air or an analyzer.

## Screenshot

```
○ SvxLink  ○ RemoteTRX  ○ SvxReflector | 48°C  Up 3d 2h  Since 2026-03-28 14:30
┌──────────── Svx Admin v2.1.5 ────────────┐
│                                           │
│  Choose an action:                        │
│ ┌───────────────────────────────────────┐ │
│ │  1  Start service                     │ │
│ │  2  Stop service                      │ │
│ │  3  Restart service                   │ │
│ │  4  Reload config (SIGHUP)            │ │
│ │  ─  ─── Monitoring ─────────          │ │
│ │  5  Show detailed status              │ │
│ │  6  Follow live logs                  │ │
│ │  7  System health check               │ │
│ │  ─  ─── Configuration ──────          │ │
│ │  8  Edit config file                  │ │
│ │  9  Edit GPIO config                  │ │
│ │ 10  Edit environment defaults         │ │
│ │  ─  ─── Audio ──────────────          │ │
│ │ 11  Alsamixer                         │ │
│ │ 12  RX level meter                    │ │
│ │ 13  Send ident (TX readback)          │ │
│ │  ─  ─── Reflector ──────────          │ │
│ │ 14  Select talkgroup                  │ │
│ │  ─  ─── Maintenance ────────          │ │
│ │ 15  Check log rotation                │ │
│ │ 16  Update svx to latest              │ │
│ │  ─  ─── Boot & GPIO ────────          │ │
│ │ 17  Enable service at boot            │ │
│ │ 18  Disable service at boot           │ │
│ │ 19  Restart GPIO setup                │ │
│ └───────────────────────────────────────┘ │
│          <OK>          <Quit>             │
└───────────────────────────────────────────┘
```

## Author

[Audric IW1GEU](https://github.com/audric)

## Other projects

Check out [SvxReflectorDashboard](https://github.com/audric/SvxReflectorDashboard) — a web dashboard for SvxReflector.

## License

GPL-3.0
