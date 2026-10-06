#!/usr/bin/env bash
set -euo pipefail

script_directory="$(dirname "$0")"
repository_root="$(cd "$script_directory/.." && pwd)"
probe_directory="$repository_root/spec/api_card_probes"

cd "$repository_root"

export CRYSTAL_PATH="$repository_root/src:$repository_root/lib"
export CRYSTAL_WORKERS=1
export CRYSTAL_CACHE_DIR="$repository_root/.crystal-cache/api-card-probes"

probe_count=0
error_count=0
warning_count=0

while IFS= read -r probe_path; do
  probe_count=$((probe_count + 1))
  if output=$(crystal-alpha build --no-codegen --no-color "$probe_path" 2>&1); then
    warning_lines=$(printf '%s\n' "$output" | grep -Eic 'warning:' || true)
    warning_count=$((warning_count + warning_lines))
    if (( warning_lines > 0 )); then
      printf 'Warnings in %s:\n%s\n' "$(basename "$probe_path")" "$output"
    fi
  else
    error_count=$((error_count + 1))
    printf 'Compile error in %s:\n%s\n' "$(basename "$probe_path")" "$output"
  fi
done < <(find "$probe_directory" -type f -name '*.cr' -print | sort)

if (( probe_count == 0 )); then
  printf 'Probe compile result: RED (0 probe files found)\n'
  exit 1
elif (( error_count > 0 )); then
  printf 'Probe compile result: RED (errors=%d, warnings=%d, probes=%d)\n' "$error_count" "$warning_count" "$probe_count"
  exit 1
elif (( warning_count > 0 )); then
  printf 'Probe compile result: YELLOW (errors=0, warnings=%d, probes=%d)\n' "$warning_count" "$probe_count"
  exit 1
else
  printf 'Probe compile result: GREEN (errors=0, warnings=0, probes=%d)\n' "$probe_count"
fi
