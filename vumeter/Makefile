# svx-vumeter — build a static, stripped Linux ARM binary for a Raspberry Pi.
#
#   make                         cross-compile ./svx-vumeter (ARCH=armv7, default)
#   make ARCH=arm64              cross-compile for 64-bit ARM (aarch64)
#   make native                  build for the host (test/dev)
#   make deploy HOST=user@pi     build + scp to the Pi
#   make deploy ARCH=arm64 HOST=user@pi
#   make clean
#
# Override HOST (required for deploy), and optionally PORT, KEY and DEST:
#   make deploy HOST=pi@repeater.local PORT=2233 KEY=~/.ssh/id_rsa

BIN  := svx-vumeter
HOST ?= pi@raspberrypi.local
PORT ?= 22
KEY  ?=
DEST ?= /usr/local/bin/$(BIN)

# Target architecture: armv7 (32-bit Pi, default) or arm64 (64-bit Pi / aarch64).
ARCH ?= armv7
ifeq ($(ARCH),armv7)
GOARCH := arm
GOARM  := 7
else ifeq ($(ARCH),arm64)
GOARCH := arm64
GOARM  :=
else
$(error unknown ARCH '$(ARCH)' — use armv7 or arm64)
endif

# -s -w strips the symbol table and DWARF debug info at link time, so the
# resulting binary is stripped (no separate strip(1) / cross-strip needed).
LDFLAGS := -s -w

.PHONY: all native deploy clean
all:
	GOOS=linux GOARCH=$(GOARCH) $(if $(GOARM),GOARM=$(GOARM)) CGO_ENABLED=0 go build -ldflags="$(LDFLAGS)" -o $(BIN) .

native:
	go build -ldflags="$(LDFLAGS)" -o $(BIN) .

deploy: all
	scp -P $(PORT) $(if $(KEY),-i $(KEY),) $(BIN) $(HOST):$(DEST)

clean:
	rm -f $(BIN)
