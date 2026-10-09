#!/usr/bin/env bash
# Transcode a Playwright recording to QuickTime/ADO-safe MP4 + a short GIF, attach both.
# MP4: baseline H.264 + silent AAC + curl --data-binary (plays inline in ADO).
# GIF: cheap glance. Do not use -an or az rest --body @file — those break playback.
# Usage: publish-demo.sh <ADO> <input-video> [pr-id]
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: publish-demo.sh <ADO> <input-video> [pr-id]" >&2
  exit 2
fi

ADO="$1"
INPUT="$2"
PR_ID="${3:-}"

if [[ ! -f "$INPUT" ]]; then
  echo "ERROR: no input video at ${INPUT}" >&2
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ERROR: ffmpeg not on PATH — cannot produce a playable MP4" >&2
  exit 1
fi

if ! command -v az >/dev/null 2>&1; then
  echo "ERROR: az not on PATH" >&2
  exit 1
fi

ORG="$(az devops configure -l -o tsv 2>/dev/null | awk -F'[[:space:]]*=[[:space:]]*' '/^organization/{print $2}' || true)"
PROJ="$(az devops configure -l -o tsv 2>/dev/null | awk -F'[[:space:]]*=[[:space:]]*' '/^project/{print $2}' || true)"
if [[ -z "$ORG" || -z "$PROJ" ]]; then
  echo "ERROR: set az devops defaults (az devops configure --defaults organization=... project=...)" >&2
  exit 1
fi
ORG="${ORG%/}"

OUT_DIR="$(cd "$(dirname "$INPUT")" && pwd)"
OUT_MP4="${OUT_DIR}/AB-${ADO}-demo.mp4"
OUT_GIF="${OUT_DIR}/AB-${ADO}-demo.gif"

# QuickTime rejects video-only MP4s (`-an`). Silent AAC + baseline H.264.
echo "Transcoding ${INPUT} -> ${OUT_MP4} (h264 baseline + silent aac +faststart)"
ffmpeg -y -i "$INPUT" -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
  -c:v libx264 -pix_fmt yuv420p -profile:v baseline -level 3.1 \
  -c:a aac -map 0:v:0 -map 1:a:0 -shortest -movflags +faststart \
  "$OUT_MP4" </dev/null

if [[ ! -s "$OUT_MP4" ]]; then
  echo "ERROR: ffmpeg produced an empty mp4" >&2
  exit 1
fi
if command -v ffprobe >/dev/null 2>&1; then
  ffprobe -v error -show_entries stream=codec_name,codec_type -of csv=p=0 "$OUT_MP4"
fi

# Short, small GIF so ADO's image preview can actually show it (max ~15s, 800px, 8fps).
echo "Transcoding ${INPUT} -> ${OUT_GIF} (inline preview)"
ffmpeg -y -i "$INPUT" -t 15 -vf "fps=8,scale=800:-1:flags=lanczos" -an "$OUT_GIF" </dev/null

ADO_RES="499b84ac-1321-427f-aa17-267ca6975798"

# az rest --body @file can mangle binary. curl --data-binary keeps the bytes intact.
TOKEN="$(az account get-access-token --resource "$ADO_RES" --query accessToken -o tsv)"

upload_and_link() {
  local file="$1" name="$2" comment="$3"
  echo "Uploading ${name} to ${ORG} (curl --data-binary)"
  local json url
  json="$(curl -sS -X POST \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@${file}" \
    "${ORG}/_apis/wit/attachments?fileName=${name}&api-version=7.1")"
  url="$(printf '%s\n' "$json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("url",""))')"
  if [[ -z "$url" ]]; then
    echo "ERROR: upload response had no url for ${name}" >&2
    printf '%s\n' "$json" >&2
    return 1
  fi
  python3 -c '
import json, sys
print(json.dumps([{
  "op": "add",
  "path": "/relations/-",
  "value": {
    "rel": "AttachedFile",
    "url": sys.argv[1],
    "attributes": {"comment": sys.argv[2]}
  }
}]))
' "$url" "$comment" > /tmp/ado-crew-demo-link.json
  az rest --method patch --resource "$ADO_RES" \
    --uri "${ORG}/${PROJ}/_apis/wit/workitems/${ADO}?api-version=7.1" \
    --headers "Content-Type=application/json-patch+json" \
    --body @/tmp/ado-crew-demo-link.json -o json >/dev/null
  printf '%s\n' "$url"
}

GIF_URL="$(upload_and_link "$OUT_GIF" "AB-${ADO}-demo.gif" "ado-crew demo preview (gif — plays inline)")"
MP4_URL="$(upload_and_link "$OUT_MP4" "AB-${ADO}-demo.mp4" "ado-crew demo (mp4)")"

echo "PREVIEW_GIF_URL=${GIF_URL}"
echo "ATTACHMENT_URL=${MP4_URL}"
echo "LOCAL_GIF=${OUT_GIF}"
echo "LOCAL_MP4=${OUT_MP4}"
if [[ -n "$PR_ID" ]]; then
  echo "PR_ID=${PR_ID}"
  echo "PR thread: link the MP4 (inline) and the GIF (glance)."
fi
