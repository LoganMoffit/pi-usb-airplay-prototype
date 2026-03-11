#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-}"
G=/sys/kernel/config/usb_gadget/ampusb
UDC_NAME="$(ls /sys/class/udc | head -n1 || true)"
IMG_FILE="${IMG_FILE:-/home/${SUDO_USER:-$USER}/usb-amp/amp-drive.img}"
VENDOR="${VENDOR:-0x1d6b}"   # Linux Foundation (prototype only)
PRODUCT="${PRODUCT:-0x0104}" # Multifunction Composite Gadget
SERIAL="${SERIAL:-0001}"
MANUF="${MANUF:-PiAirplayLab}"
PRODUCT_STR="${PRODUCT_STR:-Amp USB Bridge}"

if [[ -z "$ACTION" || ("$ACTION" != "start" && "$ACTION" != "stop") ]]; then
  echo "Usage: sudo $0 {start|stop}"
  exit 1
fi

if [[ -z "$UDC_NAME" ]]; then
  echo "No UDC found. Are you on a Pi with USB gadget support enabled (dwc2)?"
  exit 1
fi

start() {
  if [[ ! -f "$IMG_FILE" ]]; then
    echo "Image not found: $IMG_FILE"
    exit 1
  fi

  modprobe libcomposite

  if [[ -d "$G" ]]; then
    echo "Gadget already exists. Reusing."
  else
    mkdir -p "$G"
    echo "$VENDOR" > "$G/idVendor"
    echo "$PRODUCT" > "$G/idProduct"
    echo 0x0100 > "$G/bcdDevice"
    echo 0x0200 > "$G/bcdUSB"

    mkdir -p "$G/strings/0x409"
    echo "$SERIAL" > "$G/strings/0x409/serialnumber"
    echo "$MANUF" > "$G/strings/0x409/manufacturer"
    echo "$PRODUCT_STR" > "$G/strings/0x409/product"

    mkdir -p "$G/configs/c.1/strings/0x409"
    echo "MSC" > "$G/configs/c.1/strings/0x409/configuration"
    echo 250 > "$G/configs/c.1/MaxPower"

    mkdir -p "$G/functions/mass_storage.0"
    echo 1 > "$G/functions/mass_storage.0/stall"
    echo 1 > "$G/functions/mass_storage.0/lun.0/removable"
    echo 1 > "$G/functions/mass_storage.0/lun.0/ro"
    echo "$IMG_FILE" > "$G/functions/mass_storage.0/lun.0/file"

    ln -s "$G/functions/mass_storage.0" "$G/configs/c.1/"
  fi

  echo "$UDC_NAME" > "$G/UDC"
  echo "USB gadget started on UDC: $UDC_NAME"
}

stop() {
  if [[ ! -d "$G" ]]; then
    echo "Gadget not present."
    return 0
  fi

  echo "" > "$G/UDC" || true
  rm -f "$G/configs/c.1/mass_storage.0" || true
  rmdir "$G/functions/mass_storage.0" || true
  rmdir "$G/configs/c.1/strings/0x409" || true
  rmdir "$G/configs/c.1" || true
  rmdir "$G/strings/0x409" || true
  rmdir "$G" || true
  echo "USB gadget stopped."
}

case "$ACTION" in
  start) start ;;
  stop) stop ;;
esac
