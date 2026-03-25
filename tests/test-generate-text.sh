#!/usr/bin/env bash

set -euo pipefail

readonly TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd -- "$TEST_DIR/.." && pwd)"
readonly SOURCE_SCRIPT="$PROJECT_DIR/generate-text.sh"
readonly COMMON_LIB="$PROJECT_DIR/lib/bedrock-common.sh"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/bedrock-generate-text-test.XXXXXX")"

cleanup() {
  rm -rf "$work_dir"
}

trap cleanup EXIT

cp "$SOURCE_SCRIPT" "$work_dir/generate-text.sh"
chmod +x "$work_dir/generate-text.sh"
mkdir -p "$work_dir/lib"
cp "$COMMON_LIB" "$work_dir/lib/bedrock-common.sh"

mkdir -p "$work_dir/mock-bin"

cat > "$work_dir/mock-bin/aws" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" > "$TMPDIR/aws-bedrock-last-args.txt"

response_file="${!#}"
if [[ "$response_file" == [A-Za-z]:\\* ]]; then
  if command -v cygpath >/dev/null 2>&1; then
    response_file="$(cygpath -u "$response_file")"
  else
    response_file="${response_file#C:\\gitbash}"
    response_file="${response_file//\\//}"
  fi
fi

printf '%s\n' \
  '{"output":{"message":{"content":[{"text":"fake-text-response"}]}}}' > "$response_file"
EOF

chmod +x "$work_dir/mock-bin/aws"

export TMPDIR="$work_dir/tmp"
mkdir -p "$TMPDIR"

PATH="$work_dir/mock-bin:$PATH" "$work_dir/generate-text.sh" --help >"$work_dir/help.out"
grep -q -- '--region REGION' "$work_dir/help.out"
grep -q -- '--output-dir DIR' "$work_dir/help.out"

expected_request_path="$TMPDIR/bedrock-text-request"
if [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* ]]; then
  expected_request_path="$(cygpath -w "$expected_request_path")"
fi

custom_text_dir="$work_dir/custom-texts"
PATH="$work_dir/mock-bin:$PATH" "$work_dir/generate-text.sh" --region us-west-2 --output-dir "$custom_text_dir" "first prompt" >"$work_dir/first.out"
[[ -f "$custom_text_dir/response-0001.md" ]]
[[ "$(cat "$custom_text_dir/response-0001.md")" == "fake-text-response" ]]
grep -q "Created .*response-0001.md" "$work_dir/first.out"
grep -q "fake-text-response" "$work_dir/first.out"
grep -q -- '--model-id us.amazon.nova-2-lite-v1:0' "$TMPDIR/aws-bedrock-last-args.txt"
grep -Fq -- "file://$expected_request_path" "$TMPDIR/aws-bedrock-last-args.txt"
grep -q -- '--region us-west-2' "$TMPDIR/aws-bedrock-last-args.txt"

PATH="$work_dir/mock-bin:$PATH" TEXT_INFERENCE_PROFILE_ID="eu.amazon.nova-2-lite-v1:0" \
  "$work_dir/generate-text.sh" --output-dir "$custom_text_dir" "second prompt" >/dev/null
[[ -f "$custom_text_dir/response-0002.md" ]]
grep -q -- '--model-id eu.amazon.nova-2-lite-v1:0' "$TMPDIR/aws-bedrock-last-args.txt"

PATH="$work_dir/mock-bin:$PATH" BEDROCK_REGION="eu-central-1" \
  "$work_dir/generate-text.sh" --output-dir "$custom_text_dir" "env region prompt" >/dev/null
grep -q -- '--region eu-central-1' "$TMPDIR/aws-bedrock-last-args.txt"

printf 'older-response' > "$custom_text_dir/response-0007.md"
PATH="$work_dir/mock-bin:$PATH" "$work_dir/generate-text.sh" --output-dir "$custom_text_dir" "third prompt" >/dev/null
[[ -f "$custom_text_dir/response-0008.md" ]]

if PATH="$work_dir/mock-bin:$PATH" MODEL_ID="amazon.nova-canvas-v1:0" TEXT_INFERENCE_PROFILE_ID="us.amazon.nova-2-lite-v1:0" \
  "$work_dir/generate-text.sh" "fourth prompt" >/dev/null 2>"$work_dir/invalid-model.err"; then
  echo "Expected generate-text.sh to reject non-text model IDs" >&2
  exit 1
fi

grep -q "not a supported Nova 2 Lite invoke target" "$work_dir/invalid-model.err"

cat > "$work_dir/mock-bin/aws" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

response_file="${!#}"
if [[ "$response_file" == [A-Za-z]:\\* ]]; then
  if command -v cygpath >/dev/null 2>&1; then
    response_file="$(cygpath -u "$response_file")"
  else
    response_file="${response_file#C:\\gitbash}"
    response_file="${response_file//\\//}"
  fi
fi

printf '{}' > "$response_file"
EOF

chmod +x "$work_dir/mock-bin/aws"

if PATH="$work_dir/mock-bin:$PATH" "$work_dir/generate-text.sh" "broken response" \
  >/dev/null 2>"$work_dir/malformed-response.err"; then
  echo "Expected generate-text.sh to reject malformed Bedrock responses" >&2
  exit 1
fi

grep -q 'did not contain output.message.content\[\].text' "$work_dir/malformed-response.err"

mkdir -p "$work_dir/missing-jq-bin"
ln -sf "$(command -v bash)" "$work_dir/missing-jq-bin/bash"
ln -sf "$(command -v dirname)" "$work_dir/missing-jq-bin/dirname"
ln -sf "$(command -v aws)" "$work_dir/missing-jq-bin/aws"
ln -sf "$(command -v mktemp)" "$work_dir/missing-jq-bin/mktemp"
ln -sf "$(command -v mkdir)" "$work_dir/missing-jq-bin/mkdir"
ln -sf "$(command -v rm)" "$work_dir/missing-jq-bin/rm"
ln -sf "$(command -v cat)" "$work_dir/missing-jq-bin/cat"

if PATH="$work_dir/missing-jq-bin" "$work_dir/generate-text.sh" "missing jq" \
  >/dev/null 2>"$work_dir/missing-jq.err"; then
  echo "Expected generate-text.sh to fail when jq is unavailable" >&2
  exit 1
fi

[[ -s "$work_dir/missing-jq.err" ]]

cat > "$work_dir/mock-bin/aws" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" > "$TMPDIR/aws-bedrock-last-args.txt"

response_file="${!#}"
if [[ "$response_file" == [A-Za-z]:\\* ]]; then
  if command -v cygpath >/dev/null 2>&1; then
    response_file="$(cygpath -u "$response_file")"
  else
    response_file="${response_file#C:\\gitbash}"
    response_file="${response_file//\\//}"
  fi
fi

printf '%s\n' \
  '{"output":{"message":{"content":[{"text":"fake-text-response"}]}}}' > "$response_file"
EOF

chmod +x "$work_dir/mock-bin/aws"
