#!/usr/bin/env bash
# Installs the amber-lsp release this repository is checked with. The download
# is verified against the hash below, so a changed release asset stops the run.
set -euo pipefail

amber_cli_release=v2.0.10
archive_name=amber_cli-linux-x86_64.tar.gz
archive_sha256=54d19a30a650ad46962f1f6a122e7aa4c3144254db9ddd9348bc3c6dea2b20fa
install_root="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/micrate-pinned-amber-lsp"

mkdir -p "$install_root"
curl --fail --silent --show-error --location \
  --output "$install_root/$archive_name" \
  "https://github.com/amberframework/amber_cli/releases/download/$amber_cli_release/$archive_name"
echo "$archive_sha256  $install_root/$archive_name" | sha256sum --check --quiet
tar -xzf "$install_root/$archive_name" -C "$install_root"
"$install_root/amber-lsp" --version

if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$install_root" >> "$GITHUB_PATH"
else
  echo "Add $install_root to PATH before running amber-lsp."
fi
