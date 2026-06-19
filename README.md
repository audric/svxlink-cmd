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
- `dialog` or `whiptail` — for the classic `svx` menu only (auto-detected, offered for install if missing)
- `alsa-utils` — for the audio panel and volume persistence (offered for install if missing)
- The `svx-tabs` / `svx-dashboard` TUI layouts need only `bash`; they don't use `dialog`

## Install

Pick the front-end you want. The classic menu (`svx`) is recommended and
self-contained; the `svx-tabs` and `svx-dashboard` layouts also pull in the
shared `svx-lib` library (it must live next to them, hence `/usr/local/bin`).

**Classic menu (`svx`):**

```bash
sudo curl -sL https://raw.githubusercontent.com/audric/svxlink-cmd/master/svx -o /usr/local/bin/svx && sudo chmod +x /usr/local/bin/svx
```

**Tabs (`svx-tabs`):**

```bash
sudo curl -sL https://raw.githubusercontent.com/audric/svxlink-cmd/master/svx-lib -o /usr/local/bin/svx-lib && sudo curl -sL https://raw.githubusercontent.com/audric/svxlink-cmd/master/svx-tabs -o /usr/local/bin/svx-tabs && sudo chmod +x /usr/local/bin/svx-tabs
```

**Dashboard (`svx-dashboard`):**

```bash
sudo curl -sL https://raw.githubusercontent.com/audric/svxlink-cmd/master/svx-lib -o /usr/local/bin/svx-lib && sudo curl -sL https://raw.githubusercontent.com/audric/svxlink-cmd/master/svx-dashboard -o /usr/local/bin/svx-dashboard && sudo chmod +x /usr/local/bin/svx-dashboard
```

## Usage

```bash
sudo svx            # classic dialog menu
sudo svx-tabs       # tabbed TUI
sudo svx-dashboard  # single-screen dashboard
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

## Screenshots

Three front-ends are available: the classic `dialog` menu (`svx`) and two
full-screen custom TUI layouts that share `svx-lib` — a tabbed view (`svx-tabs`)
and a single-screen dashboard (`svx-dashboard`).

### Classic menu (`svx`)

Preferred by the author, and the version installed by the one-line installer above.

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

### Dashboard (`svx-dashboard`)

Single-screen overview — services, audio, disk, and live logs at a glance.

```
┌─ Svx Admin v2.1.0 ── repeater-pi ── 192.168.1.50 ─────────────────────────┐
│ CPU: 48°C   Load: 0.42   Up: 3d 2h                                        │
├──────────────────────────┬──────────────────────┬─────────────────────────┤
│ SERVICES                 │ AUDIO (USB:1)        │ DISK                    │
│ ● SvxLink      active    │ Mic  ██████░░ 72%    │ /      ██░░░░░ 31%      │
│ ● RemoteTRX    active    │ Spkr ████░░░░ 55%    │ 31G / 100G              │
│ ○ SvxReflector inactive  │ AGC  OFF             │                         │
│                          │                      │ USB                     │
│ TOP PROCS                │                      │ /media/usb  2.1G/15G    │
│ svxlink      3.2%        │                      │                         │
│ pulseaudio   1.1%        │                      │                         │
├──────────────────────────┴──────────────────────┴─────────────────────────┤
│ LOGS (SvxLink)                                                    ◀ ▶ svc │
│ Apr 01 14:32:10 svxlink: Activating link to reflector                     │
│ Apr 01 14:32:11 svxlink: Rx1: Squelch open                                │
│ Apr 01 14:32:14 svxlink: Tx1: Transmitter ON                              │
├───────────────────────────────────────────────────────────────────────────┤
│ [T]art [S]top [R]estart re[L]oad [C]onf [G]PIO [A]lsa [B]oot [Q]          │
└───────────────────────────────────────────────────────────────────────────┘
```

### Tabs (`svx-tabs`)

Tabbed layout — `Overview`, `Logs`, `Config`, and `Maintenance` on `[1-4]`.

```
┌─ Svx Admin v2.1.0 ── repeater-pi ── 192.168.1.50 ─────────────────────────┐
│ CPU: 48°C  Load: 0.42  Up: 3d 2h   ● SvxLink  ● RemoteTRX  ○ SvxReflector │
├───────────────────────────────────────────────────────────────────────────┤
│  [OVERVIEW]     LOGS      CONFIG      MAINTENANCE                         │
├─────────────────────────────────────┬─────────────────────────────────────┤
│ SERVICES                            │ DISK                                │
│ ● SvxLink       active              │ /      31G/100G  ██░░░░░ 31%        │
│ ● RemoteTRX     active              │                                     │
│ ○ SvxReflector  inactive            │ USB                                 │
│                                     │ /media/usb       2.1G/15G           │
│ AUDIO (USB:1)                       │                                     │
│ Mic  ███████░░░ 72%                 │ TOP PROCS                           │
│ Spkr ██████░░░░ 55%                 │ svxlink         3.2%                │
│ AGC  OFF                            │ pulseaudio      1.1%                │
├─────────────────────────────────────┴─────────────────────────────────────┤
│ [T]art [S]top [R]estart re[L]oad [A]lsa                    [1-4] Tab  [Q] │
└───────────────────────────────────────────────────────────────────────────┘
```

## Author

[Audric IW1GEU](https://github.com/audric)

## Other projects

Check out [SvxReflectorDashboard](https://github.com/audric/SvxReflectorDashboard) — a web dashboard for SvxReflector.

## License

GPL-3.0
