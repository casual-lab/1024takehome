#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME=zk-dev:latest

echo "Running container to verify installation (interactive)..."
docker run --rm -it ${IMAGE_NAME}
