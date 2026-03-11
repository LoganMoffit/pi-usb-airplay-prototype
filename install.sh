#!/usr/bin/env bash
set -euo pipefail

# Installs and configures the Pi USB AirPlay prototype on Raspberry Pi OS.
# Run as: curl -fsSL <raw-url>/install.sh | bash

REPO_DIR="${REPO_DIR:-$HOME/pi-usb-airplay-prototype}"
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
  sudo sed -i 's/ rootwait\( .*\)*/ rootwait modules-load=dwc2\1/' "$BOOT_CMDLINE" || true
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

log "Enabling and restarting shairport-sync"
sudo systemctl enable shairport-sync
sudo systemctl restart shairport-sync

cat <<'EOM'

Install complete.

Next steps after reboot:
  1) sudo ~/pi-usb-airplay-prototype/scripts/setup_usb_gadget.sh start
  2) ~/pi-usb-airplay-prototype/scripts/airplay_to_usb.sh

Reboot required for dwc2/cmdline changes to take effect.
EOM
