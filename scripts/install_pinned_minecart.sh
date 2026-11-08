#!/usr/bin/env bash
set -euo pipefail

# The source commit is verified by its Git tree before it can install dependencies.
minecart_commit=ec4ec4d4434a92308f99de11ac907fc8a21e7a79
minecart_tree=dd6c0d1cfdfe1c1b78dd515a3117088b31416f2e
minecart_repository="${MINECART_SOURCE_REPOSITORY:-https://github.com/crimson-knight/shards.git}"
minecart_source_ref="${MINECART_SOURCE_REF:-refs/tags/v2025.11.25.9}"
install_root="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/micrate-pinned-minecart"

mkdir -p "$install_root"
git -C "$install_root" init -q
if git -C "$install_root" remote get-url origin >/dev/null 2>&1; then
  git -C "$install_root" remote set-url origin "$minecart_repository"
else
  git -C "$install_root" remote add origin "$minecart_repository"
fi
git -C "$install_root" fetch --depth=1 origin "$minecart_source_ref"
git -C "$install_root" checkout -q --detach FETCH_HEAD
test "$(git -C "$install_root" rev-parse HEAD)" = "$minecart_commit"
test "$(git -C "$install_root" rev-parse 'HEAD^{tree}')" = "$minecart_tree"

# crystal-alpha is preferred; CI runners and Homebrew have stock crystal.
if [[ -z "${CRYSTAL:-}" ]]; then
  if command -v crystal-alpha >/dev/null 2>&1; then CRYSTAL=crystal-alpha; else CRYSTAL=crystal; fi
fi
make -C "$install_root" bin/minecart bin/shards-alpha CRYSTAL="$CRYSTAL"
test -x "$install_root/bin/minecart"
test -x "$install_root/bin/shards-alpha"
"$install_root/bin/minecart" --version | grep -F "Minecart 2025.11.25.9"
"$install_root/bin/shards-alpha" --version | grep -F "Minecart 2025.11.25.9"

if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$install_root/bin" >> "$GITHUB_PATH"
else
  echo "Add $install_root/bin to PATH before installing dependencies."
fi
