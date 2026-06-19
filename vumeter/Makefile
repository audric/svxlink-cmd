# svx-vumeter — build a static, stripped Linux binary for a Raspberry Pi.
#
#   make                         cross-compile ./svx-vumeter (ARCH=armv7, default)
#   make ARCH=arm64              cross-compile for 64-bit ARM (aarch64)
#   make native                  build for the host (test/dev)
#   make deploy HOST=user@pi     build + scp to the Pi
#   make deploy ARCH=arm64 HOST=user@pi
#   make release                 build every published arch as svx-vumeter-linux-<arch>
#   make clean
#
# Override HOST (required for deploy), and optionally PORT, KEY and DEST:
#   make deploy HOST=pi@repeater.local PORT=2233 KEY=~/.ssh/id_rsa

BIN  := svx-vumeter
HOST ?= pi@raspberrypi.local
PORT ?= 22
KEY  ?=
DEST ?= /usr/local/bin/$(BIN)

# Target architecture for single-arch builds: armv6 (Pi 1/Zero), armv7
# (32-bit Pi 2/3/4, default), arm64 (64-bit Pi 3/4/5), or amd64.
ARCH ?= armv7
ifeq ($(ARCH),armv6)
GOARCH := arm
GOARM  := 6
else ifeq ($(ARCH),armv7)
GOARCH := arm
GOARM  := 7
else ifeq ($(ARCH),arm64)
GOARCH := arm64
GOARM  :=
else ifeq ($(ARCH),amd64)
GOARCH := amd64
GOARM  :=
else
$(error unknown ARCH '$(ARCH)' — use armv6, armv7, arm64 or amd64)
endif

# Single source of truth for the version: the svx script's VERSION (so there is
# no second number to keep in sync). Injected into the binary via -X.
VERSION := $(shell sed -n 's/.*readonly VERSION="\([^"]*\)".*/\1/p' ../svx 2>/dev/null)

# -s -w strips the symbol table and DWARF debug info at link time, so the
# resulting binary is stripped (no separate strip(1) / cross-strip needed).
LDFLAGS := -s -w $(if $(VERSION),-X main.version=$(VERSION))
BUILD    = GOOS=linux GOARCH=$(1) $(if $(2),GOARM=$(2)) CGO_ENABLED=0 go build -ldflags="$(LDFLAGS)" -o $(3) .

.PHONY: all native deploy release clean
all:
	$(call BUILD,$(GOARCH),$(GOARM),$(BIN))

native:
	go build -ldflags="$(LDFLAGS)" -o $(BIN) .

deploy: all
	scp -P $(PORT) $(if $(KEY),-i $(KEY),) $(BIN) $(HOST):$(DEST)

# Build the binaries published as GitHub release assets (one per arch).
release:
	$(call BUILD,arm,6,$(BIN)-linux-armv6)
	$(call BUILD,arm,7,$(BIN)-linux-armv7)
	$(call BUILD,arm64,,$(BIN)-linux-arm64)
	$(call BUILD,amd64,,$(BIN)-linux-amd64)

clean:
	rm -f $(BIN) $(BIN)-linux-*
