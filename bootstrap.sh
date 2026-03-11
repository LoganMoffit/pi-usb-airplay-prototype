#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${1:-}"
TARGET_DIR="${2:-$HOME/pi-usb-airplay-prototype}"

if [[ -z "$REPO_URL" ]]; then
  echo "Usage: $0 <repo-url> [target-dir]"
  exit 1
fi

if [[ -d "$TARGET_DIR/.git" ]]; then
  git -C "$TARGET_DIR" pull --ff-only
else
  git clone "$REPO_URL" "$TARGET_DIR"
fi

bash "$TARGET_DIR/install.sh"
