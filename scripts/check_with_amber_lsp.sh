#!/usr/bin/env bash
# Checks every source file with amber-lsp, the Amber ecosystem's linter.
#
# amber-lsp checks one file at a time. It exits 1 for an error-level finding and
# 2 when it cannot analyze a file, and both fail this script: a file the linter
# could not read is a file nobody checked. Warnings print without failing.
set -uo pipefail

repository_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repository_root"

failed_file_count=0
checked_file_count=0

while IFS= read -r source_file; do
  checked_file_count=$((checked_file_count + 1))
  if ! amber-lsp --check "$source_file"; then
    failed_file_count=$((failed_file_count + 1))
  fi
done < <(find src -type f -name '*.cr' | sort)

echo "amber-lsp checked $checked_file_count files, $failed_file_count failed"
if (( checked_file_count == 0 || failed_file_count > 0 )); then
  exit 1
fi
