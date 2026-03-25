#!/usr/bin/env bash

set -euo pipefail

readonly REGION="us-east-1"
readonly MODEL_ID="${MODEL_ID:-amazon.nova-canvas-v1:0}"
readonly WIDTH=1024
readonly HEIGHT=1024
readonly QUALITY="standard"
readonly IMAGE_PREFIX="image-"
readonly IMAGE_SUFFIX=".png"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly OUTPUT_DIR="$SCRIPT_DIR/images"

usage() {
  cat <<'EOF'
Usage:
  ./generate-image.sh "your prompt text"

Example:
  ./generate-image.sh "A green parrot sitting on a tree branch, tropical jungle, photorealistic, high detail"
EOF
}

require_command() {
  local cmd="$1"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command not found: $cmd" >&2
    exit 1
  fi
}

validate_model_id() {
  case "$MODEL_ID" in
    amazon.nova-canvas-v1:0)
      ;;
    *)
      echo "Error: MODEL_ID=$MODEL_ID is not an image-generation model for this script." >&2
      echo "Use Amazon Nova Canvas instead: amazon.nova-canvas-v1:0" >&2
      exit 1
      ;;
  esac
}

next_image_name() {
  local max_num=0
  local file
  local base_name
  local num

  shopt -s nullglob
  for file in "$OUTPUT_DIR"/${IMAGE_PREFIX}[0-9][0-9][0-9][0-9]${IMAGE_SUFFIX}; do
    base_name="${file##*/}"
    num="${base_name#${IMAGE_PREFIX}}"
    num="${num%${IMAGE_SUFFIX}}"
    if (( 10#$num > max_num )); then
      max_num=$((10#$num))
    fi
  done
  shopt -u nullglob

  printf "%s/%s%04d%s\n" "$OUTPUT_DIR" "$IMAGE_PREFIX" "$((max_num + 1))" "$IMAGE_SUFFIX"
}

decode_base64_to_file() {
  local encoded_text="$1"
  local output_file="$2"

  if printf '%s' "$encoded_text" | base64 --decode > "$output_file" 2>/dev/null; then
    return 0
  fi

  if printf '%s' "$encoded_text" | base64 -d > "$output_file" 2>/dev/null; then
    return 0
  fi

  echo "Error: unable to decode base64 output with the available base64 command." >&2
  exit 1
}

open_file() {
  local target_file="$1"

  if command -v open >/dev/null 2>&1; then
    open "$target_file" >/dev/null 2>&1 || true
    return 0
  fi

  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$target_file" >/dev/null 2>&1 || true
    return 0
  fi

  if command -v cmd.exe >/dev/null 2>&1; then
    if command -v cygpath >/dev/null 2>&1; then
      cmd.exe /c start "" "$(cygpath -w "$target_file")" >/dev/null 2>&1 || true
    else
      cmd.exe /c start "" "$target_file" >/dev/null 2>&1 || true
    fi
  fi
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

prompt_text="$*"

require_command aws
require_command jq
require_command base64
require_command mktemp
validate_model_id

mkdir -p "$OUTPUT_DIR"

output_image="$(next_image_name)"
request_file="$(mktemp "${TMPDIR:-/tmp}/bedrock-request.XXXXXX.json")"
response_file="$(mktemp "${TMPDIR:-/tmp}/bedrock-response.XXXXXX.json")"

cleanup() {
  rm -f "$request_file" "$response_file"
}

trap cleanup EXIT

jq -n \
  --arg text "$prompt_text" \
  --arg quality "$QUALITY" \
  --argjson width "$WIDTH" \
  --argjson height "$HEIGHT" \
  '{
    taskType: "TEXT_IMAGE",
    textToImageParams: {
      text: $text
    },
    imageGenerationConfig: {
      numberOfImages: 1,
      quality: $quality,
      height: $height,
      width: $width
    }
  }' > "$request_file"

aws bedrock-runtime invoke-model \
  --region "$REGION" \
  --model-id "$MODEL_ID" \
  --body "file://$request_file" \
  --cli-binary-format raw-in-base64-out \
  "$response_file" >/dev/null

image_b64="$(jq -r '.images[0] // empty' "$response_file")"

if [[ -z "$image_b64" ]]; then
  echo "Error: Bedrock response did not contain .images[0]." >&2
  echo "Response saved at: $response_file" >&2
  trap - EXIT
  rm -f "$request_file"
  exit 1
fi

decode_base64_to_file "$image_b64" "$output_image"

echo "Created $output_image"
open_file "$output_image"
