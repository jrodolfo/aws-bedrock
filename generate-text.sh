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
readonly COMMON_LIB="$SCRIPT_DIR/lib/bedrock-common.sh"

source "$COMMON_LIB"

usage() {
  cat <<'EOF'
Usage:
  ./generate-text.sh "your prompt text"

Example:
  ./generate-text.sh "Summarize the main differences between REST and GraphQL."
EOF
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

output_text="$(next_numbered_path "$OUTPUT_DIR" "$RESPONSE_PREFIX" "$RESPONSE_SUFFIX")"
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
