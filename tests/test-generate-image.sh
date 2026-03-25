#!/bin/zsh

set -euo pipefail

readonly TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly PROJECT_DIR="$(cd "$TEST_DIR/.." && pwd)"
readonly SOURCE_SCRIPT="$PROJECT_DIR/generate-image.sh"

work_dir="$(mktemp -d "/tmp/bedrock-generate-image-test.XXXXXX")"

cleanup() {
  rm -rf "$work_dir"
}

trap cleanup EXIT

cp "$SOURCE_SCRIPT" "$work_dir/generate-image.sh"
chmod +x "$work_dir/generate-image.sh"

mkdir -p "$work_dir/mock-bin"

cat > "$work_dir/mock-bin/aws" <<'EOF'
#!/bin/zsh
set -euo pipefail

response_file="${@: -1}"
image_b64="$(printf 'fake-image-data' | base64)"

printf '{"images":["%s"]}\n' "$image_b64" > "$response_file"
EOF

cat > "$work_dir/mock-bin/open" <<'EOF'
#!/bin/zsh
set -euo pipefail

exit 0
EOF

chmod +x "$work_dir/mock-bin/aws" "$work_dir/mock-bin/open"

PATH="$work_dir/mock-bin:$PATH" "$work_dir/generate-image.sh" "first prompt" >/dev/null
[[ -f "$work_dir/images/image-0001.png" ]]
[[ "$(cat "$work_dir/images/image-0001.png")" == "fake-image-data" ]]

PATH="$work_dir/mock-bin:$PATH" "$work_dir/generate-image.sh" "second prompt" >/dev/null
[[ -f "$work_dir/images/image-0002.png" ]]

if PATH="$work_dir/mock-bin:$PATH" MODEL_ID="amazon.nova-2-lite-v1:0" \
  "$work_dir/generate-image.sh" "third prompt" >/dev/null 2>"$work_dir/invalid-model.err"; then
  echo "Expected generate-image.sh to reject non-image model IDs" >&2
  exit 1
fi

grep -q "not an image-generation model" "$work_dir/invalid-model.err"
