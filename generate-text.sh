#!/usr/bin/env bash

set -euo pipefail

readonly DEFAULT_REGION="${AWS_REGION:-us-east-1}"
readonly TEXT_MODEL_ID="amazon.nova-2-lite-v1:0"
readonly DEFAULT_INFERENCE_PROFILE_ID="us.amazon.nova-2-lite-v1:0"
readonly INFERENCE_PROFILE_ID="${TEXT_INFERENCE_PROFILE_ID:-$DEFAULT_INFERENCE_PROFILE_ID}"
readonly INVOKE_TARGET="${MODEL_ID:-$INFERENCE_PROFILE_ID}"
readonly MAX_TOKENS=1000
readonly TEMPERATURE=0.7
readonly TOP_P=0.9
readonly RESPONSE_PREFIX="response-"
readonly RESPONSE_SUFFIX=".md"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly COMMON_LIB="$SCRIPT_DIR/lib/bedrock-common.sh"

source "$COMMON_LIB"

usage() {
  cat <<'EOF'
Usage:
  ./generate-text.sh [--region REGION] [--output-dir DIR] [--debug] "your prompt text"
  ./generate-text.sh --help

Example:
  ./generate-text.sh "Summarize the main differences between REST and GraphQL."

Options:
  --help              Show this help message
  --region REGION     AWS region to use (default: us-east-1)
  --output-dir DIR    Directory for generated text files (default: ./texts)
  --debug             Preserve temp request/response files and print their paths
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

region="$DEFAULT_REGION"
output_dir="$SCRIPT_DIR/texts"
debug_mode=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      usage
      exit 0
      ;;
    --region)
      if [[ $# -lt 2 ]]; then
        echo "Error: --region requires a value." >&2
        exit 1
      fi
      region="$2"
      shift 2
      ;;
    --output-dir)
      if [[ $# -lt 2 ]]; then
        echo "Error: --output-dir requires a value." >&2
        exit 1
      fi
      output_dir="$2"
      shift 2
      ;;
    --debug)
      debug_mode=1
      shift
      ;;
    --*)
      echo "Error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

prompt_text="$*"

require_commands aws jq mktemp
validate_invoke_target

mkdir -p "$output_dir"

output_text="$(next_numbered_path "$output_dir" "$RESPONSE_PREFIX" "$RESPONSE_SUFFIX")"
request_file="$(mktemp "${TMPDIR:-/tmp}/bedrock-text-request.XXXXXX.json")"
response_file="$(mktemp "${TMPDIR:-/tmp}/bedrock-text-response.XXXXXX.json")"
aws_request_file="$(aws_cli_path "$request_file")"
aws_response_file="$(aws_cli_path "$response_file")"

cleanup() {
  if [[ "$debug_mode" -eq 0 ]]; then
    rm -f "$request_file" "$response_file"
  fi
}

trap cleanup EXIT

if [[ "$debug_mode" -eq 1 ]]; then
  echo "Debug: region=$region" >&2
  echo "Debug: invoke_target=$INVOKE_TARGET" >&2
  echo "Debug: output_text=$output_text" >&2
  echo "Debug: request_file=$request_file" >&2
  echo "Debug: response_file=$response_file" >&2
fi

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

echo "Invoking Amazon Bedrock text generation..." >&2

aws bedrock-runtime invoke-model \
  --region "$region" \
  --model-id "$INVOKE_TARGET" \
  --body "file://$aws_request_file" \
  --cli-binary-format raw-in-base64-out \
  "$aws_response_file" >/dev/null

jq -r '.output.message.content[]? | select(has("text")) | .text' "$response_file" > "$output_text"

if [[ ! -s "$output_text" ]]; then
  echo "Error: Bedrock response did not contain output.message.content[].text." >&2
  echo "Response saved at: $response_file" >&2
  rm -f "$output_text"
  if [[ "$debug_mode" -eq 0 ]]; then
    trap - EXIT
    rm -f "$request_file"
  fi
  exit 1
fi

echo "Created $output_text"
cat "$output_text"
