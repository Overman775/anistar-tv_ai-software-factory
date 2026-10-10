#!/usr/bin/env bash
set -euo pipefail
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
command -v ffmpeg >/dev/null || { echo 'FFmpeg with libx264 is required.' >&2; exit 1; }
for quality in 360 720; do
  if [[ $quality == 360 ]]; then width=640; crf=36; frequency=440; else width=1280; crf=40; frequency=660; fi
  ffmpeg -y -hide_banner -loglevel error \
    -f lavfi -i "testsrc2=size=${width}x${quality}:rate=24" \
    -f lavfi -i "sine=frequency=$frequency:sample_rate=44100" -t 24 \
    -c:v libx264 -preset veryfast -crf "$crf" -pix_fmt yuv420p -g 48 -sc_threshold 0 \
    -c:a aac -b:a 32k -f hls -hls_time 2 -hls_playlist_type vod \
    -hls_segment_filename "tool/e2e/media/$quality/segment-%02d.ts" "tool/e2e/media/$quality/index.m3u8"
done
