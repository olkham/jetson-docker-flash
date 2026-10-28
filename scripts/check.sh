#!/usr/bin/env bash
set -Eeuo pipefail
source /workspace/scripts/lib.sh
load_board "$BOARD" /workspace
if ! id=$(find_recovery_device); then
  echo "No recovery-mode device matching ${RECOVERY_IDS[*]} is visible inside the container." >&2
  exit 1
fi
lsusb -d "$id"
echo "OK: $DESCRIPTION is in recovery mode and visible inside the container."
