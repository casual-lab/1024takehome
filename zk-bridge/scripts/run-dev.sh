#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME=zk-dev:latest
MOUNT_DIR="$(pwd)"

# Usage:
# ./scripts/run-dev.sh            # run as image default user (dev), mount pwd -> /work
# ./scripts/run-dev.sh --as-host-user  # run container process as your host uid:gid (may affect HOME)

USER_FLAG=""
DETACH=0
CONTAINER_NAME="zk-dev-run"

# Parse args
while [ "$#" -gt 0 ]; do
  case "$1" in
    --as-host-user)
      USER_FLAG="--user $(id -u):$(id -g)"
      shift
      ;;
    --detach|-d)
      DETACH=1
      shift
      ;;
    --name)
      CONTAINER_NAME="$2"
      shift 2
      ;;
    --name=*)
      CONTAINER_NAME="${1#--name=}"
      shift
      ;;
    --) shift; break ;;
    *) echo "Unknown option: $1"; exit 2 ;;
  esac
done

if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
  echo "Image ${IMAGE_NAME} not found — building a fast image (skips Solana installer)..."
  SKIP_SOLANA=1 ./scripts/docker-build.sh
fi

echo "Mounting: ${MOUNT_DIR} -> /work"
if [ "${DETACH}" -eq 1 ]; then
  echo "Running container in background (detached) as name: ${CONTAINER_NAME}"
  CID=$(docker run -d ${USER_FLAG} \
    -v "${MOUNT_DIR}:/work" \
    -w /work \
    --name "${CONTAINER_NAME}" \
    ${IMAGE_NAME})
  echo "Started container ${CID} (name=${CONTAINER_NAME})"
  exit 0
else
  echo "Running container ${IMAGE_NAME} interactively"
  docker run --rm -it ${USER_FLAG} \
    -v "${MOUNT_DIR}:/work" \
    -w /work \
    --name "${CONTAINER_NAME}" \
    ${IMAGE_NAME}
fi
