#!/usr/bin/env bash

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

require_commands() {
  local cmd

  for cmd in "$@"; do
    require_command "$cmd"
  done
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

next_numbered_path() {
  local output_dir="$1"
  local prefix="$2"
  local suffix="$3"
  local max_num=0
  local matches=()
  local file
  local base_name
  local num

  shopt -s nullglob
  matches=("$output_dir"/${prefix}[0-9][0-9][0-9][0-9]${suffix})
  shopt -u nullglob

  if ((${#matches[@]} > 0)); then
    for file in "${matches[@]}"; do
      base_name="${file##*/}"
      num="${base_name#${prefix}}"
      num="${num%${suffix}}"
      if [[ "$num" =~ ^[0-9]{4}$ ]] && (( 10#$num > max_num )); then
        max_num=$((10#$num))
      fi
    done
  fi

  printf "%s/%s%04d%s\n" "$output_dir" "$prefix" "$((max_num + 1))" "$suffix"
}
