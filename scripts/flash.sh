#!/usr/bin/env bash
set -Eeuo pipefail
source /workspace/scripts/lib.sh
load_board "$BOARD" /workspace
cd "$L4T_DIR" 2>/dev/null || { echo "Run prepare first: ./jetson-flash.sh prepare $BOARD" >&2; exit 1; }
[[ -f ./$BOARD_CONFIG.conf ]] || { echo "Board config $BOARD_CONFIG.conf not found." >&2; exit 1; }
# Some BSPs ship l4t_initrd_flash.sh only under tools/kernel_flash/.
if [[ ! -e ${FLASH_CMD[0]} && -e tools/kernel_flash/${FLASH_CMD[0]#./} ]]; then
  FLASH_CMD[0]=./tools/kernel_flash/${FLASH_CMD[0]#./}
fi
[[ -e ${FLASH_CMD[0]} ]] || { echo "${FLASH_CMD[0]} not found in this BSP." >&2; exit 1; }
if ! find_recovery_device >/dev/null; then
  echo "No recovery-mode device matching ${RECOVERY_IDS[*]} is visible inside the container." >&2
  exit 1
fi
install_prerequisites
mkdir -p /workspace/logs
echo "Running: ${FLASH_CMD[*]}"
"${FLASH_CMD[@]}" 2>&1 | tee "/workspace/logs/$BOARD-flash-$(date +%Y%m%d-%H%M%S).log"
