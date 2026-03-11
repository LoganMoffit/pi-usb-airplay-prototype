#!/usr/bin/env bash
set -euo pipefail

# Installs and configures the Pi USB AirPlay prototype on Raspberry Pi OS.
# Run as: curl -fsSL <raw-url>/install.sh | bash

REPO_DIR="${REPO_DIR:-$HOME/pi-usb-airplay-prototype}"
AUTO_REBOOT="${AUTO_REBOOT:-1}"
BOOT_CONFIG="/boot/firmware/config.txt"
BOOT_CMDLINE="/boot/firmware/cmdline.txt"
if [[ ! -f "$BOOT_CONFIG" ]]; then
  BOOT_CONFIG="/boot/config.txt"
fi
if [[ ! -f "$BOOT_CMDLINE" ]]; then
  BOOT_CMDLINE="/boot/cmdline.txt"
fi

log() { printf '[install] %s\n' "$*"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    log "Missing required command: $1"
    exit 1
  }
}

log "Checking prerequisites"
require_cmd sudo
require_cmd apt

log "Installing OS packages"
sudo apt update
sudo apt install -y ffmpeg dosfstools util-linux shairport-sync

log "Ensuring repo directory exists: $REPO_DIR"
mkdir -p "$REPO_DIR"

# If installer was piped from curl, scripts may not exist yet.
if [[ ! -f "$REPO_DIR/scripts/create_usb_image.sh" ]]; then
  log "Scripts not found in $REPO_DIR"
  log "Clone repo first, e.g. git clone <repo-url> $REPO_DIR"
  exit 1
fi

log "Enabling dwc2 overlay in $BOOT_CONFIG"
if ! grep -q '^dtoverlay=dwc2$' "$BOOT_CONFIG"; then
  echo 'dtoverlay=dwc2' | sudo tee -a "$BOOT_CONFIG" >/dev/null
fi

log "Adding modules-load=dwc2 to $BOOT_CMDLINE"
if ! grep -q 'modules-load=dwc2' "$BOOT_CMDLINE"; then
  sudo sed -i '0,/rootwait/s//rootwait modules-load=dwc2/' "$BOOT_CMDLINE" || true
  if ! grep -q 'modules-load=dwc2' "$BOOT_CMDLINE"; then
    log "Could not auto-edit cmdline safely. Add modules-load=dwc2 manually to the single cmdline line."
  fi
fi

log "Installing shairport-sync pipe config"
if [[ -d /etc/shairport-sync/conf.d ]]; then
  sudo cp "$REPO_DIR/config/shairport-sync-pipe.conf" /etc/shairport-sync/conf.d/pipe.conf
else
  log "/etc/shairport-sync/conf.d not found. Merge $REPO_DIR/config/shairport-sync-pipe.conf into /etc/shairport-sync.conf manually."
fi

log "Making scripts executable"
chmod +x "$REPO_DIR/scripts/"*.sh

log "Creating USB image"
"$REPO_DIR/scripts/create_usb_image.sh"

log "Installing systemd services"
sudo tee /etc/systemd/system/pi-usb-gadget.service >/dev/null <<EOM
[Unit]
Description=USB mass storage gadget for amp thumb-drive emulation
After=local-fs.target
Wants=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$REPO_DIR/scripts/setup_usb_gadget.sh start
ExecStop=$REPO_DIR/scripts/setup_usb_gadget.sh stop
TimeoutStartSec=30
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOM

sudo tee /etc/systemd/system/airplay-to-usb.service >/dev/null <<EOM
[Unit]
Description=AirPlay PCM to rolling MP3 files on emulated USB drive
After=shairport-sync.service pi-usb-gadget.service
Requires=shairport-sync.service pi-usb-gadget.service

[Service]
Type=simple
ExecStart=$REPO_DIR/scripts/airplay_to_usb.sh
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOM

log "Enabling services"
sudo systemctl daemon-reload
sudo systemctl enable shairport-sync pi-usb-gadget.service airplay-to-usb.service

log "Restarting shairport-sync now (gadget services will come up after reboot)"
sudo systemctl restart shairport-sync

cat <<EOM

Install complete.

Services enabled:
  - shairport-sync
  - pi-usb-gadget.service
  - airplay-to-usb.service

Reboot required for dwc2/cmdline changes to take effect.
EOM

if [[ "$AUTO_REBOOT" == "1" ]]; then
  log "Rebooting in 5 seconds..."
  sleep 5
  sudo reboot
else
  log "AUTO_REBOOT=0 set, skipping reboot."
fi
