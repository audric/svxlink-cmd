# svx-vumeter — build a static ARM binary for the Raspberry Pi (armv7).
#
#   make                       cross-compile ./svx-vumeter for linux/armv7
#   make native                build for the host (test/dev)
#   make deploy HOST=user@pi   scp the ARM binary to the Pi
#   make clean
#
# Override HOST (required for deploy), and optionally PORT, KEY and DEST:
#   make deploy HOST=pi@repeater.local PORT=22 KEY=~/.ssh/id_rsa

BIN  := svx-vumeter
HOST ?= pi@raspberrypi.local
PORT ?= 22
KEY  ?=
DEST ?= /usr/local/bin/$(BIN)

# -s -w strips the symbol table and DWARF debug info at link time, so the
# resulting binary is stripped (no separate strip(1) / cross-strip needed).
LDFLAGS := -s -w

.PHONY: all native deploy clean
all:
	GOOS=linux GOARCH=arm GOARM=7 CGO_ENABLED=0 go build -ldflags="$(LDFLAGS)" -o $(BIN) .

native:
	go build -ldflags="$(LDFLAGS)" -o $(BIN) .

deploy: all
	scp -P $(PORT) $(if $(KEY),-i $(KEY),) $(BIN) $(HOST):$(DEST)

clean:
	rm -f $(BIN)
