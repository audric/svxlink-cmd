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

```bash
sudo curl -sL https://raw.githubusercontent.com/audric/svxlink-cmd/master/svx -o /usr/local/bin/svx && sudo chmod +x /usr/local/bin/svx
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
  device and restarts it on exit. This item runs the optional **`svx-vumeter`**
  binary — a small static Go program under [`vumeter/`](vumeter/); build it for
  your Pi and install it to `/usr/local/bin/svx-vumeter`:

  ```bash
  cd vumeter && make           # cross-compile for Raspberry Pi (armv7)
  # then copy ./svx-vumeter to the Pi's /usr/local/bin/
  ```

- **Send ident (TX readback)** — makes the repeater transmit a known readback
  on demand, so you can check TX level / deviation on the air or an analyzer.
  It writes a DTMF command to the logic's control PTY, which it discovers from
  your config (`DTMF_CTRL_PTY=`) rather than assuming a fixed path.

## Screenshot

```
○ SvxLink  ○ RemoteTRX  ○ SvxReflector | 48°C  Up 3d 2h  Since 2026-03-28 14:30
┌──────────── Svx Admin v2.1.0 ────────────┐
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
│ │  ─  ─── Maintenance ────────          │ │
│ │ 14  Check log rotation                │ │
│ │  ─  ─── Boot & GPIO ────────          │ │
│ │ 15  Enable service at boot            │ │
│ │ 16  Disable service at boot           │ │
│ │ 17  Restart GPIO setup                │ │
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
