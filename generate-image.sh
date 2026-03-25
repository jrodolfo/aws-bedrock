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
readonly COMMON_LIB="$SCRIPT_DIR/lib/bedrock-common.sh"

source "$COMMON_LIB"

usage() {
  cat <<'EOF'
Usage:
  ./generate-image.sh "your prompt text"

Example:
  ./generate-image.sh "A green parrot sitting on a tree branch, tropical jungle, photorealistic, high detail"
EOF
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
  local windows_target

  if [[ "$OSTYPE" == msys* || "$OSTYPE" == cygwin* ]]; then
    if command -v powershell.exe >/dev/null 2>&1; then
      windows_target="$(aws_cli_path "$target_file")"
      powershell.exe -NoProfile -NonInteractive -Command "Start-Process -FilePath '$windows_target'" >/dev/null 2>&1 || true
      return 0
    fi

    if command -v explorer.exe >/dev/null 2>&1; then
      windows_target="$(aws_cli_path "$target_file")"
      explorer.exe "$windows_target" >/dev/null 2>&1 || true
      return 0
    fi
  fi

  if command -v open >/dev/null 2>&1; then
    open "$target_file" >/dev/null 2>&1 || true
    return 0
  fi

  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$target_file" >/dev/null 2>&1 || true
    return 0
  fi

  if command -v powershell.exe >/dev/null 2>&1; then
    windows_target="$(aws_cli_path "$target_file")"
    powershell.exe -NoProfile -NonInteractive -Command "Start-Process -FilePath '$windows_target'" >/dev/null 2>&1 || true
    return 0
  fi

  if command -v explorer.exe >/dev/null 2>&1; then
    windows_target="$(aws_cli_path "$target_file")"
    explorer.exe "$windows_target" >/dev/null 2>&1 || true
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

output_image="$(next_numbered_path "$OUTPUT_DIR" "$IMAGE_PREFIX" "$IMAGE_SUFFIX")"
request_file="$(mktemp "${TMPDIR:-/tmp}/bedrock-request.XXXXXX.json")"
response_file="$(mktemp "${TMPDIR:-/tmp}/bedrock-response.XXXXXX.json")"
aws_request_file="$(aws_cli_path "$request_file")"
aws_response_file="$(aws_cli_path "$response_file")"

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
  --body "file://$aws_request_file" \
  --cli-binary-format raw-in-base64-out \
  "$aws_response_file" >/dev/null

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
