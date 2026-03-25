#!/usr/bin/env bash

set -euo pipefail

readonly TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd -- "$TEST_DIR/.." && pwd)"
readonly SOURCE_SCRIPT="$PROJECT_DIR/generate-image.sh"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/bedrock-generate-image-test.XXXXXX")"

cleanup() {
  rm -rf "$work_dir"
}

trap cleanup EXIT

cp "$SOURCE_SCRIPT" "$work_dir/generate-image.sh"
chmod +x "$work_dir/generate-image.sh"

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
image_b64="$(printf 'fake-image-data' | base64)"

printf '{"images":["%s"]}\n' "$image_b64" > "$response_file"
EOF

cat > "$work_dir/mock-bin/open" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

exit 0
EOF

cat > "$work_dir/mock-bin/powershell.exe" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" > "$TMPDIR/powershell-last-args.txt"
exit 0
EOF

chmod +x "$work_dir/mock-bin/aws" "$work_dir/mock-bin/open" "$work_dir/mock-bin/powershell.exe"

export TMPDIR="$work_dir/tmp"
mkdir -p "$TMPDIR"

expected_request_path="$TMPDIR/bedrock-request"
if [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* ]]; then
  expected_request_path="$(cygpath -w "$expected_request_path")"
fi

PATH="$work_dir/mock-bin:$PATH" "$work_dir/generate-image.sh" "first prompt" >/dev/null
[[ -f "$work_dir/images/image-0001.png" ]]
[[ "$(cat "$work_dir/images/image-0001.png")" == "fake-image-data" ]]
grep -Fq -- "file://$expected_request_path" "$TMPDIR/aws-bedrock-last-args.txt"

PATH="$work_dir/mock-bin:$PATH" "$work_dir/generate-image.sh" "second prompt" >/dev/null
[[ -f "$work_dir/images/image-0002.png" ]]

printf 'older-image' > "$work_dir/images/image-0007.png"
PATH="$work_dir/mock-bin:$PATH" "$work_dir/generate-image.sh" "third prompt" >/dev/null
[[ -f "$work_dir/images/image-0008.png" ]]

if PATH="$work_dir/mock-bin:$PATH" MODEL_ID="amazon.nova-2-lite-v1:0" \
  "$work_dir/generate-image.sh" "fourth prompt" >/dev/null 2>"$work_dir/invalid-model.err"; then
  echo "Expected generate-image.sh to reject non-image model IDs" >&2
  exit 1
fi

grep -q "not an image-generation model" "$work_dir/invalid-model.err"

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

if PATH="$work_dir/mock-bin:$PATH" "$work_dir/generate-image.sh" "broken response" \
  >/dev/null 2>"$work_dir/malformed-response.err"; then
  echo "Expected generate-image.sh to reject malformed Bedrock responses" >&2
  exit 1
fi

grep -q 'did not contain .images\[0\]' "$work_dir/malformed-response.err"

mkdir -p "$work_dir/missing-aws-bin"
ln -sf "$(command -v bash)" "$work_dir/missing-aws-bin/bash"
ln -sf "$(command -v dirname)" "$work_dir/missing-aws-bin/dirname"
ln -sf "$(command -v jq)" "$work_dir/missing-aws-bin/jq"
ln -sf "$(command -v base64)" "$work_dir/missing-aws-bin/base64"
ln -sf "$(command -v mktemp)" "$work_dir/missing-aws-bin/mktemp"
ln -sf "$(command -v rm)" "$work_dir/missing-aws-bin/rm"
ln -sf "$(command -v mkdir)" "$work_dir/missing-aws-bin/mkdir"

if PATH="$work_dir/missing-aws-bin" "$work_dir/generate-image.sh" "missing aws" \
  >/dev/null 2>"$work_dir/missing-aws.err"; then
  echo "Expected generate-image.sh to fail when aws is unavailable" >&2
  exit 1
fi

grep -q 'required command not found: aws' "$work_dir/missing-aws.err"

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
image_b64="$(printf 'fake-image-data' | base64)"

printf '{"images":["%s"]}\n' "$image_b64" > "$response_file"
EOF

chmod +x "$work_dir/mock-bin/aws"

cat > "$work_dir/mock-bin/cygpath" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  -w)
    unix_path="$2"
    printf 'C:\\gitbash%s\n' "${unix_path//\//\\}"
    ;;
  -u)
    windows_path="$2"
    windows_path="${windows_path#C:\\gitbash}"
    printf '%s\n' "${windows_path//\\//}"
    ;;
  *)
    echo "unexpected cygpath arguments: $*" >&2
    exit 1
    ;;
esac
EOF

chmod +x "$work_dir/mock-bin/cygpath"

if [[ "${OSTYPE:-}" != msys* && "${OSTYPE:-}" != cygwin* ]]; then
  PATH="$work_dir/mock-bin:$PATH" OSTYPE=msys "$work_dir/generate-image.sh" "windows prompt" >/dev/null
  grep -Fq -- 'file://C:\gitbash' "$TMPDIR/aws-bedrock-last-args.txt"
fi
