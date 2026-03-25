#!/usr/bin/env bash

set -euo pipefail

readonly REGION="us-east-1"
readonly TEXT_MODEL_ID="amazon.nova-2-lite-v1:0"
readonly DEFAULT_INFERENCE_PROFILE_ID="us.amazon.nova-2-lite-v1:0"
readonly INFERENCE_PROFILE_ID="${TEXT_INFERENCE_PROFILE_ID:-${BEDROCK_TEXT_INFERENCE_PROFILE_ID:-$DEFAULT_INFERENCE_PROFILE_ID}}"
readonly INVOKE_TARGET="${MODEL_ID:-$INFERENCE_PROFILE_ID}"
readonly MAX_TOKENS=1000
readonly TEMPERATURE=0.7
readonly TOP_P=0.9
readonly RESPONSE_PREFIX="response-"
readonly RESPONSE_SUFFIX=".md"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly OUTPUT_DIR="$SCRIPT_DIR/texts"

usage() {
  cat <<'EOF'
Usage:
  ./generate-text.sh "your prompt text"

Example:
  ./generate-text.sh "Summarize the main differences between REST and GraphQL."
EOF
}

require_command() {
  local cmd="$1"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command not found: $cmd" >&2
    if [[ "$OSTYPE" == msys* || "$OSTYPE" == cygwin* ]]; then
      echo "On Windows with Git Bash, install $cmd and restart Git Bash so PATH is refreshed." >&2
    fi
    exit 1
  fi
}

aws_cli_path() {
  local target_path="$1"

  if [[ "$OSTYPE" == msys* || "$OSTYPE" == cygwin* ]]; then
    if command -v cygpath >/dev/null 2>&1; then
      cygpath -w "$target_path"
      return 0
    fi
  fi

  printf '%s\n' "$target_path"
}

validate_invoke_target() {
  if [[ -n "${MODEL_ID:-}" ]]; then
    case "$MODEL_ID" in
      "$TEXT_MODEL_ID"|*.inference-profile/*|arn:aws*:bedrock:*:inference-profile/*|us.amazon.nova-2-lite-v1:0|eu.amazon.nova-2-lite-v1:0|apac.amazon.nova-2-lite-v1:0)
        ;;
      *)
        echo "Error: MODEL_ID=$MODEL_ID is not a supported Nova 2 Lite invoke target for this script." >&2
        echo "Use a Nova 2 Lite inference profile ID/ARN, or set TEXT_INFERENCE_PROFILE_ID instead." >&2
        exit 1
        ;;
    esac
  fi
}

next_response_name() {
  local max_num=0
  local file
  local base_name
  local num

  shopt -s nullglob
  for file in "$OUTPUT_DIR"/${RESPONSE_PREFIX}[0-9][0-9][0-9][0-9]${RESPONSE_SUFFIX}; do
    base_name="${file##*/}"
    num="${base_name#${RESPONSE_PREFIX}}"
    num="${num%${RESPONSE_SUFFIX}}"
    if (( 10#$num > max_num )); then
      max_num=$((10#$num))
    fi
  done
  shopt -u nullglob

  printf "%s/%s%04d%s\n" "$OUTPUT_DIR" "$RESPONSE_PREFIX" "$((max_num + 1))" "$RESPONSE_SUFFIX"
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

prompt_text="$*"

require_command aws
require_command jq
require_command mktemp
validate_invoke_target

mkdir -p "$OUTPUT_DIR"

output_text="$(next_response_name)"
request_file="$(mktemp "${TMPDIR:-/tmp}/bedrock-text-request.XXXXXX.json")"
response_file="$(mktemp "${TMPDIR:-/tmp}/bedrock-text-response.XXXXXX.json")"
aws_request_file="$(aws_cli_path "$request_file")"
aws_response_file="$(aws_cli_path "$response_file")"

cleanup() {
  rm -f "$request_file" "$response_file"
}

trap cleanup EXIT

jq -n \
  --arg text "$prompt_text" \
  --argjson maxTokens "$MAX_TOKENS" \
  --argjson temperature "$TEMPERATURE" \
  --argjson topP "$TOP_P" \
  '{
    messages: [
      {
        role: "user",
        content: [
          {
            text: $text
          }
        ]
      }
    ],
    inferenceConfig: {
      maxTokens: $maxTokens,
      temperature: $temperature,
      topP: $topP
    }
  }' > "$request_file"

aws bedrock-runtime invoke-model \
  --region "$REGION" \
  --model-id "$INVOKE_TARGET" \
  --body "file://$aws_request_file" \
  --cli-binary-format raw-in-base64-out \
  "$aws_response_file" >/dev/null

jq -r '.output.message.content[]? | select(has("text")) | .text' "$response_file" > "$output_text"

if [[ ! -s "$output_text" ]]; then
  echo "Error: Bedrock response did not contain output.message.content[].text." >&2
  echo "Response saved at: $response_file" >&2
  rm -f "$output_text"
  trap - EXIT
  rm -f "$request_file"
  exit 1
fi

echo "Created $output_text"
cat "$output_text"
