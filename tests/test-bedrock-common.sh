#!/usr/bin/env bash

set -euo pipefail

readonly TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd -- "$TEST_DIR/.." && pwd)"
readonly COMMON_LIB="$PROJECT_DIR/lib/bedrock-common.sh"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/bedrock-common-test.XXXXXX")"

cleanup() {
  rm -rf "$work_dir"
}

trap cleanup EXIT

source "$COMMON_LIB"

empty_dir="$work_dir/empty"
mkdir -p "$empty_dir"

next_path="$(next_numbered_path "$empty_dir" "image-" ".png")"
[[ "$next_path" == "$empty_dir/image-0001.png" ]]

mixed_dir="$work_dir/mixed"
mkdir -p "$mixed_dir"
printf 'a' > "$mixed_dir/image-0002.png"
printf 'b' > "$mixed_dir/image-0010.png"
printf 'c' > "$mixed_dir/image-10000.png"
printf 'd' > "$mixed_dir/image-abcd.png"
printf 'e' > "$mixed_dir/other-0009.png"

next_path="$(next_numbered_path "$mixed_dir" "image-" ".png")"
[[ "$next_path" == "$mixed_dir/image-0011.png" ]]

temp_json="$(make_temp_file "bedrock-common-test" ".json")"
[[ "$temp_json" == *.json ]]
[[ -f "$temp_json" ]]
