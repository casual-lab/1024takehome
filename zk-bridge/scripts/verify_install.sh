#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/share/solana/install/active_release/bin:$HOME/.cargo/bin:$PATH"

# Load nvm if present so `node` and `npm` are available in this script
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  # shellcheck disable=SC1090
  . "$NVM_DIR/nvm.sh"
fi

echo "===== Verifying installed tool versions ====="

missing=0

echo -n "rustc: " && (rustc --version || { echo "(missing)"; missing=1; })
echo -n "solana: " && (solana --version || { echo "(missing)"; missing=1; })
echo -n "anchor: " && (anchor --version || { echo "(missing or install failed)"; })
echo -n "node: " && (node --version || { echo "(missing)"; missing=1; })
echo -n "npm: " && (npm --version || { echo "(missing)"; missing=1; })
echo -n "yarn: " && (yarn --version || { echo "(missing)"; missing=1; })

if [ "$missing" -ne 0 ]; then
  echo "One or more required tools are missing. See output above." >&2
  exit 2
fi

echo "All required tools detected (rustc, solana, node, yarn). Anchor may be optional depending on installer." 
exec /bin/bash
