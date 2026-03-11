#!/usr/bin/env bash
set -euo pipefail

IMG_DIR="${IMG_DIR:-$HOME/usb-amp}"
IMG_FILE="${IMG_FILE:-$IMG_DIR/amp-drive.img}"
MOUNT_POINT="${MOUNT_POINT:-/mnt/amp-drive}"
SIZE_MB="${SIZE_MB:-1024}"

mkdir -p "$IMG_DIR"
mkdir -p "$MOUNT_POINT"

if [[ ! -f "$IMG_FILE" ]]; then
  echo "Creating ${SIZE_MB}MB image: $IMG_FILE"
  dd if=/dev/zero of="$IMG_FILE" bs=1M count="$SIZE_MB" status=progress
  mkfs.vfat -F 32 -n AMPUSB "$IMG_FILE"
else
  echo "Using existing image: $IMG_FILE"
fi

if ! mountpoint -q "$MOUNT_POINT"; then
  echo "Mounting image at $MOUNT_POINT"
  sudo mount -o loop,rw,uid="$(id -u)",gid="$(id -g)",umask=0022 "$IMG_FILE" "$MOUNT_POINT"
fi

mkdir -p "$MOUNT_POINT/AIRPLAY"
echo "USB AirPlay prototype drive" > "$MOUNT_POINT/README.TXT"
sync

echo "Done."
echo "Image: $IMG_FILE"
echo "Mount: $MOUNT_POINT"
