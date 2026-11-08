#!/usr/bin/env bash
# Compiles every program Micrate ships, with warnings treated as errors.
#
# Crystal only type-checks the code a program reaches, so a defect in a method
# that no spec calls stays hidden until the program that calls it is built.
set -euo pipefail

repository_root="$(cd "$(dirname "$0")/.." && pwd)"
crystal_compiler="${CRYSTAL:-crystal}"

cd "$repository_root"

for entry_point in src/micrate.cr src/micrate-cli.cr src/micrate-wrapper.cr; do
  echo "Compiling $entry_point"
  "$crystal_compiler" build --no-codegen --error-on-warnings "$entry_point"
done
