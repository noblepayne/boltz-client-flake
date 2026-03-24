#!/usr/bin/env bash
set -euo pipefail

echo "Updating boltz-client..."
nix-update boltz-client --flake --commit
