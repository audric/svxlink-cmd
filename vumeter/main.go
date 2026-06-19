// svx-vumeter — live terminal VU meter for SvxLink RX audio calibration.
//
// One terminal pane: a responsive RX input-level bar (~30 ms refresh) plus
// instant keyboard adjustment of the RX/TX mixer controls. No tmux, no Python.
//
// Audio comes from `arecord` (raw PCM on stdout); volume changes go through
// `amixer`. Both ship with alsa-utils, so this stays a pure-stdlib static
// binary — cross-compile with: GOOS=linux GOARCH=arm GOARM=7 go build
package main

import (
	"bufio"
	"flag"
	"fmt"
	"math"
	"os"
	"os/exec"
	"os/signal"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

var (
	device   = flag.String("D", "plughw:1,0", "ALSA capture device (arecord -D)")
	card     = flag.String("c", "1", "ALSA card index for amixer (-c)")
	rxCtl    = flag.String("rxctl", "Mic", "capture (RX) mixer control name")
	txCtl    = flag.String("txctl", "Speaker", "playback (TX) mixer control name")
	rate     = flag.Int("r", 48000, "sample rate")
	step     = flag.String("step", "2%", "volume step per keypress")
	barWidth = flag.Int("w", 50, "meter bar width in characters")
	stopSvc  = flag.String("stop", "", "systemd service to stop during the session and restart on exit (e.g. svxlink)")
)

const (
	minDB = -54.0 // bottom of the meter scale
	maxDB = 0.0   // 0 dBFS = full scale / clipping
)

// Synthetic key codes for arrow keys, decoded from their escape sequences so
// they work regardless of keyboard layout (handy on IT layouts where [ ] need AltGr).
const (
	keyUp    = 0x81
	keyDown  = 0x82
	keyRight = 0x83
	keyLeft  = 0x84
)

// shared level state, written by the audio reader, read by the renderer
var (
	mu       sync.Mutex
	curDB    = minDB // instantaneous peak of the last block, in dBFS
	holdDB   = minDB // decaying peak-hold marker
	clipping bool
	recDead  string // non-empty if arecord exited (e.g. device busy)
)

// printHelp writes a full, friendly help text (what it does + keys + options).
func printHelp(w *os.File) {
	fmt.Fprint(w, `svx-vumeter — live RX audio-level meter for SvxLink calibration

Usage:
  svx-vumeter [options]

Shows a live VU bar of the capture (RX) input so you can set the mic/capture
gain while watching the level (aim for peaks just below clipping). SvxLink holds
the sound card, so stop it first or pass "-stop svxlink" to free the device.

Keys:
  + / -   (or up / down arrows)      adjust RX gain  (Mic capture)
  , / .   (or left / right arrows)   adjust TX level (Speaker)
  p                                  reset the peak-hold marker
  q                                  quit

Options:
`)
	flag.CommandLine.SetOutput(w)
	flag.PrintDefaults()
}

func main() {
	flag.Usage = func() { printHelp(os.Stderr) }
	for _, a := range os.Args[1:] {
		if a == "-h" || a == "-help" || a == "--help" {
			printHelp(os.Stdout)
			return
		}
	}
	flag.Parse()

	// Optionally free the sound card by stopping a service for the session.
	if *stopSvc != "" {
		_ = exec.Command("systemctl", "stop", *stopSvc).Run()
		defer exec.Command("systemctl", "start", *stopSvc).Run()
	}

	// Start the capture stream: mono S16_LE raw PCM on stdout.
	rec := exec.Command("arecord",
		"-D", *device, "-f", "S16_LE", "-c", "1",
		"-r", strconv.Itoa(*rate), "-t", "raw")
	// Make the child die with us, so a killed meter can never orphan an
	// arecord that keeps the sound card locked.
	rec.SysProcAttr = &syscall.SysProcAttr{Pdeathsig: syscall.SIGKILL}
	stdout, err := rec.StdoutPipe()
	if err != nil {
		fmt.Fprintln(os.Stderr, "pipe:", err)
		os.Exit(1)
	}
	var recErr strings.Builder
	rec.Stderr = &recErr
	if err := rec.Start(); err != nil {
		fmt.Fprintln(os.Stderr, "cannot start arecord:", err)
		os.Exit(1)
	}

	// Put the terminal in raw mode so keys arrive instantly without echo.
	oldStty := sttyState()
	rawTerm()
	restore := func() {
		showCursor()
		if oldStty != "" {
			runStty(strings.Fields(oldStty)...)
		}
	}
	defer restore()

	// Clean up on Ctrl-C / SIGTERM.
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)

	// If arecord exits (most often the device is busy), surface why.
	go func() {
		err := rec.Wait()
		if err != nil {
			msg := strings.TrimSpace(recErr.String())
			if msg == "" {
				msg = err.Error()
			}
			mu.Lock()
			recDead = msg
			mu.Unlock()
		}
	}()

	// --- audio reader goroutine ---
	go func() {
		buf := make([]byte, 1920) // ~20 ms @ 48 kHz mono 16-bit
		r := bufio.NewReader(stdout)
		for {
			n, err := r.Read(buf)
			if n > 0 {
				peak := 0
				clip := false
				for i := 0; i+1 < n; i += 2 {
					s := int(int16(uint16(buf[i]) | uint16(buf[i+1])<<8))
					if s < 0 {
						s = -s
					}
					if s > peak {
						peak = s
					}
					if s >= 32767 {
						clip = true
					}
				}
				db := minDB
				if peak > 0 {
					db = 20 * math.Log10(float64(peak)/32768.0)
				}
				mu.Lock()
				curDB = db
				if db > holdDB {
					holdDB = db
				}
				clipping = clip
				mu.Unlock()
			}
			if err != nil {
				return
			}
		}
	}()

	// --- keyboard reader goroutine ---
	keys := make(chan byte, 8)
	go func() {
		var b [1]byte
		rd := func() (byte, bool) {
			for {
				n, err := os.Stdin.Read(b[:])
				if n > 0 {
					return b[0], true
				}
				if err != nil {
					return 0, false
				}
			}
		}
		for {
			c, ok := rd()
			if !ok {
				return
			}
			if c == 0x1b { // ESC: maybe an arrow sequence (ESC [ A/B/C/D)
				c2, ok := rd()
				if !ok {
					return
				}
				if c2 == '[' {
					c3, ok := rd()
					if !ok {
						return
					}
					switch c3 {
					case 'A':
						keys <- keyUp
					case 'B':
						keys <- keyDown
					case 'C':
						keys <- keyRight
					case 'D':
						keys <- keyLeft
					}
					continue
				}
				keys <- c2
				continue
			}
			keys <- c
		}
	}()

	// Current mixer percentages, refreshed after each change.
	// RX gain lives on the Capture side of the control; TX on Playback.
	rxPct := getVol(*rxCtl, true)
	txPct := getVol(*txCtl, false)

	hideCursor()
	clearScreen()
	ticker := time.NewTicker(30 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-sig:
			return
		case k := <-keys:
			switch k {
			case '+', '=', keyUp:
				setVol(*rxCtl, *step+"+", true)
				rxPct = getVol(*rxCtl, true)
			case '-', '_', keyDown:
				setVol(*rxCtl, *step+"-", true)
				rxPct = getVol(*rxCtl, true)
			case '.', ']', '>', keyRight:
				setVol(*txCtl, *step+"+", false)
				txPct = getVol(*txCtl, false)
			case ',', '[', '<', keyLeft:
				setVol(*txCtl, *step+"-", false)
				txPct = getVol(*txCtl, false)
			case 'p', 'P':
				mu.Lock()
				holdDB = minDB
				mu.Unlock()
			case 'q', 'Q', 3: // 3 = Ctrl-C in raw mode
				return
			}
		case <-ticker.C:
			mu.Lock()
			cur, hold, clip, dead := curDB, holdDB, clipping, recDead
			holdDB -= 0.6 // decay the peak-hold marker
			if holdDB < minDB {
				holdDB = minDB
			}
			mu.Unlock()
			render(cur, hold, clip, rxPct, txPct, dead)
		}
	}
}

// render draws the whole single-pane display, redrawing in place.
func render(cur, hold float64, clip bool, rxPct, txPct, dead string) {
	var b strings.Builder
	b.WriteString("\033[H") // cursor home

	b.WriteString("\033[1m svx-vumeter\033[0m — RX input level   (q quit)\n")
	b.WriteString("\033[K\n")

	if dead != "" {
		b.WriteString(" \033[1;41m AUDIO UNAVAILABLE \033[0m " + dead + "\033[K\n")
		b.WriteString(" stop the radio first, or relaunch with \033[1m-stop svxlink\033[0m\033[K\n\033[K\n")
	}

	b.WriteString(" RX ")
	b.WriteString(fmt.Sprintf("%6.1f dBFS  ", cur))
	b.WriteString(bar(cur, hold))
	if clip {
		b.WriteString("  \033[1;41m CLIP \033[0m")
	} else {
		b.WriteString("        ")
	}
	b.WriteString("\033[K\n\033[K\n")

	b.WriteString(fmt.Sprintf(" %s (RX gain): \033[1m%s\033[0m     %s (TX): \033[1m%s\033[0m\033[K\n",
		*rxCtl, rxPct, *txCtl, txPct))
	b.WriteString("\033[K\n")
	b.WriteString(" keys:  \033[1m+\033[0m/\033[1m-\033[0m (or \033[1m↑↓\033[0m) RX gain   \033[1m,\033[0m/\033[1m.\033[0m (or \033[1m←→\033[0m) TX level   \033[1mp\033[0m reset   \033[1mq\033[0m quit\033[K\n")

	fmt.Print(b.String())
}

// bar renders a colored level bar with a peak-hold marker.
func bar(cur, hold float64) string {
	w := *barWidth
	fill := scale(cur, w)
	mark := scale(hold, w)
	var b strings.Builder
	b.WriteString("[")
	for i := 0; i < w; i++ {
		// color thresholds along the scale: green / yellow / red
		dbAt := minDB + (maxDB-minDB)*float64(i)/float64(w)
		color := "\033[32m" // green
		if dbAt > -9 {
			color = "\033[31m" // red
		} else if dbAt > -18 {
			color = "\033[33m" // yellow
		}
		switch {
		case i == mark && mark >= fill:
			b.WriteString(color + "|" + "\033[0m")
		case i < fill:
			b.WriteString(color + "#" + "\033[0m")
		default:
			b.WriteString(" ")
		}
	}
	b.WriteString("]")
	return b.String()
}

func scale(db float64, w int) int {
	if db < minDB {
		db = minDB
	}
	if db > maxDB {
		db = maxDB
	}
	n := int((db - minDB) / (maxDB - minDB) * float64(w))
	if n > w {
		n = w
	}
	return n
}

var (
	pctRe    = regexp.MustCompile(`\[(\d+)%\]`)
	capPctRe = regexp.MustCompile(`Capture \d+ \[(\d+)%\]`)
)

// getVol returns the control's level as "NN%". When capture is true it reads
// the Capture side of the control (the RX gain); otherwise the first/Playback %.
func getVol(ctl string, capture bool) string {
	out, err := exec.Command("amixer", "-c", *card, "sget", ctl).Output()
	if err != nil {
		return "?"
	}
	re := pctRe
	if capture {
		re = capPctRe
	}
	if m := re.FindStringSubmatch(string(out)); m != nil {
		return m[1] + "%"
	}
	return "?"
}

// setVol nudges the control by delta (e.g. "2%+"). When capture is true the
// change is applied to the capture volume via amixer's "cap" modifier.
func setVol(ctl, delta string, capture bool) {
	args := []string{"-c", *card, "-q", "sset", ctl, delta}
	if capture {
		args = append(args, "cap")
	}
	_ = exec.Command("amixer", args...).Run()
}

// --- terminal helpers (via stty; no external Go modules) ---

func sttyState() string {
	cmd := exec.Command("stty", "-g")
	cmd.Stdin = os.Stdin
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func rawTerm() { runStty("-echo", "-icanon", "min", "1", "time", "0") }

func runStty(a ...string) {
	cmd := exec.Command("stty", a...)
	cmd.Stdin = os.Stdin
	_ = cmd.Run()
}

func clearScreen() { fmt.Print("\033[2J\033[H") }
func hideCursor()  { fmt.Print("\033[?25l") }
func showCursor()  { fmt.Print("\033[?25h") }
