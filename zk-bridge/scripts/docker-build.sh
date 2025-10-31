#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME=zk-dev:latest

# Allow skipping Solana installer for faster builds by setting SKIP_SOLANA=1
INSTALL_SOLANA_ARG="--build-arg INSTALL_SOLANA=true"
if [ "${SKIP_SOLANA:-0}" = "1" ] || [ "${SKIP_SOLANA:-false}" = "true" ]; then
	INSTALL_SOLANA_ARG="--build-arg INSTALL_SOLANA=false"
	echo "Building without Solana installer (SKIP_SOLANA=1)"
else
	echo "Building with Solana installer (default)"
fi

echo "Building Docker image ${IMAGE_NAME}..."
docker build -t ${IMAGE_NAME} ${INSTALL_SOLANA_ARG} .

echo "Build finished. To run verification: ./scripts/run-verify.sh"
