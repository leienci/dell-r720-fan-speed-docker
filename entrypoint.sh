#!/usr/bin/env bash
set -uo pipefail

: "${BMC_IP:?Missing required env var BMC_IP}"
: "${BMC_USER:?Missing required env var BMC_USER}"
: "${BMC_PASS:?Missing required env var BMC_PASS}"
: "${FAN_SPEED:?Missing required env var FAN_SPEED}"

if (( FAN_SPEED < 0 || FAN_SPEED > 100 )); then
  echo "ERROR: FAN_SPEED must be between 0 and 100 (got ${FAN_SPEED})" >&2
  exit 1
fi

SPEED_HEX=$(printf '0x%02x' "${FAN_SPEED}")
RETRY_COUNT="${RETRY_COUNT:-10}"
RETRY_INTERVAL="${RETRY_INTERVAL:-5}"

echo "[INFO] Starting Dell R720 fan control"
echo "[INFO] BMC: ${BMC_IP}, User: ${BMC_USER}, Speed: ${FAN_SPEED}% (${SPEED_HEX})"
echo "[INFO] Retry settings: attempts=${RETRY_COUNT}, interval=${RETRY_INTERVAL}s"

run_with_retry() {
  local attempt=1
  local max_attempts="${1}"
  local description="${2}"
  shift 2
  local cmd=("$@")

  while (( attempt <= max_attempts )); do
    echo "[INFO] [${attempt}/${max_attempts}] ${description}..."
    if "${cmd[@]}" >/dev/null 2>&1; then
      echo "[INFO] ${description} succeeded"
      return 0
    fi
    echo "[WARN] ${description} failed, retrying in ${RETRY_INTERVAL}s..."
    sleep "${RETRY_INTERVAL}"
    attempt=$((attempt + 1))
  done

  echo "[ERROR] ${description} failed after ${max_attempts} attempts" >&2
  return 1
}

select_interface() {
  local iface="${1}"
  ipmitool -I "${iface}" -H "${BMC_IP}" -U "${BMC_USER}" -P "${BMC_PASS}" mc info >/dev/null 2>&1
}

IPMI_IF="lanplus"
if ! select_interface "${IPMI_IF}"; then
  echo "[INFO] lanplus (encrypted) failed, falling back to lan (unencrypted)"
  IPMI_IF="lan"
fi

echo "[INFO] Using IPMI interface: ${IPMI_IF}"

IPMITOOL_BASE=(ipmitool -I "${IPMI_IF}" -H "${BMC_IP}" -U "${BMC_USER}" -P "${BMC_PASS}")

run_with_retry "${RETRY_COUNT}" "Set manual fan control mode" \
  "${IPMITOOL_BASE[@]}" raw 0x30 0x30 0x01 0x00

run_with_retry "${RETRY_COUNT}" "Set fan speed to ${FAN_SPEED}%" \
  "${IPMITOOL_BASE[@]}" raw 0x30 0x30 0x02 0xff "${SPEED_HEX}"

echo "[INFO] Fan control configured successfully."
exit 0
