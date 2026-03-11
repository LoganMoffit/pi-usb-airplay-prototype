#!/usr/bin/env bash
set -euo pipefail

PCM_PIPE="${PCM_PIPE:-/tmp/shairport/airplay.pcm}"
MOUNT_POINT="${MOUNT_POINT:-/mnt/amp-drive}"
OUT_DIR="${OUT_DIR:-$MOUNT_POINT/AIRPLAY}"
SEGMENT_SECONDS="${SEGMENT_SECONDS:-8}"
LIST_SIZE="${LIST_SIZE:-40}"
BITRATE="${BITRATE:-192k}"
SAMPLE_RATE="${SAMPLE_RATE:-44100}"
CHANNELS="${CHANNELS:-2}"

mkdir -p "$OUT_DIR"

if [[ ! -p "$PCM_PIPE" ]]; then
  echo "Waiting for shairport-sync pipe: $PCM_PIPE"
  echo "Make sure shairport-sync is configured with output_backend=pipe and pipe.name=$PCM_PIPE"
fi

while [[ ! -p "$PCM_PIPE" ]]; do
  sleep 1
done

echo "Starting AirPlay -> MP3 segment writer"
echo "Input pipe: $PCM_PIPE"
echo "Output dir: $OUT_DIR"

# Write a small marker file the amp may show.
echo "AirPlay bridge active $(date -Iseconds)" > "$MOUNT_POINT/NOWPLAY.TXT"
sync

# Segmenter runs continuously and replaces older segments as index wraps.
ffmpeg -hide_banner -loglevel warning -fflags +nobuffer \
  -f s16le -ar "$SAMPLE_RATE" -ac "$CHANNELS" -i "$PCM_PIPE" \
  -c:a libmp3lame -b:a "$BITRATE" \
  -f segment \
  -segment_time "$SEGMENT_SECONDS" \
  -segment_wrap "$LIST_SIZE" \
  -segment_start_number 0 \
  -reset_timestamps 1 \
  "$OUT_DIR/seg-%04d.mp3"
