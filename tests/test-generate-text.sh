#!/bin/zsh

set -euo pipefail

readonly TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly PROJECT_DIR="$(cd "$TEST_DIR/.." && pwd)"
readonly SOURCE_SCRIPT="$PROJECT_DIR/generate-text.sh"

work_dir="$(mktemp -d "/tmp/bedrock-generate-text-test.XXXXXX")"

cleanup() {
  rm -rf "$work_dir"
}

trap cleanup EXIT

cp "$SOURCE_SCRIPT" "$work_dir/generate-text.sh"
chmod +x "$work_dir/generate-text.sh"

mkdir -p "$work_dir/mock-bin"

cat > "$work_dir/mock-bin/aws" <<'EOF'
#!/bin/zsh
set -euo pipefail

printf '%s\n' "$*" > "$TMPDIR/aws-bedrock-last-args.txt"

response_file="${@: -1}"

printf '%s\n' \
  '{"output":{"message":{"content":[{"text":"fake-text-response"}]}}}' > "$response_file"
EOF

cat > "$work_dir/mock-bin/open" <<'EOF'
#!/bin/zsh
set -euo pipefail

exit 0
EOF

chmod +x "$work_dir/mock-bin/aws" "$work_dir/mock-bin/open"

export TMPDIR="$work_dir/tmp"
mkdir -p "$TMPDIR"

PATH="$work_dir/mock-bin:$PATH" "$work_dir/generate-text.sh" "first prompt" >"$work_dir/first.out"
[[ -f "$work_dir/texts/response-0001.md" ]]
[[ "$(cat "$work_dir/texts/response-0001.md")" == "fake-text-response" ]]
grep -q "Created .*response-0001.md" "$work_dir/first.out"
grep -q "fake-text-response" "$work_dir/first.out"
grep -q -- '--model-id us.amazon.nova-2-lite-v1:0' "$TMPDIR/aws-bedrock-last-args.txt"

PATH="$work_dir/mock-bin:$PATH" TEXT_INFERENCE_PROFILE_ID="eu.amazon.nova-2-lite-v1:0" \
  "$work_dir/generate-text.sh" "second prompt" >/dev/null
[[ -f "$work_dir/texts/response-0002.md" ]]
grep -q -- '--model-id eu.amazon.nova-2-lite-v1:0' "$TMPDIR/aws-bedrock-last-args.txt"

if PATH="$work_dir/mock-bin:$PATH" MODEL_ID="amazon.nova-canvas-v1:0" TEXT_INFERENCE_PROFILE_ID="us.amazon.nova-2-lite-v1:0" \
  "$work_dir/generate-text.sh" "third prompt" >/dev/null 2>"$work_dir/invalid-model.err"; then
  echo "Expected generate-text.sh to reject non-text model IDs" >&2
  exit 1
fi

grep -q "not a supported Nova 2 Lite invoke target" "$work_dir/invalid-model.err"
