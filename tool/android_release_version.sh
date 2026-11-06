#!/usr/bin/env bash
set -euo pipefail

pubspec_file="${1:-pubspec.yaml}"
run_number="${GITHUB_RUN_NUMBER:-}"

if [[ ! "$run_number" =~ ^[1-9][0-9]{0,9}$ ]]; then
  printf 'GITHUB_RUN_NUMBER deve ser um inteiro positivo.\n' >&2
  exit 1
fi

if ((run_number > 2099999995)); then
  printf 'O código do build excede o limite do Google Play.\n' >&2
  exit 1
fi

version="$(sed -nE 's/^version:[[:space:]]+([^[:space:]]+)[[:space:]]*$/\1/p' "$pubspec_file")"

if [[ ! "$version" =~ ^([0-9]+\.[0-9]+\.[0-9]+)(\+[0-9]+)?$ ]]; then
  printf 'O pubspec deve declarar version: major.minor.patch[+build].\n' >&2
  exit 1
fi

build_name="${BASH_REMATCH[1]}"
build_number=$((run_number + 5))

printf 'build_name=%s\nbuild_number=%s\n' "$build_name" "$build_number"
