#!/usr/bin/env bash
# check-serial-console.sh
#
# Verifies that the GPU node serial console is receiving data.
# This script checks:
#   1. The vm-110-serial-logger service is running on Proxmox
#   2. The serial log file exists and has recent data
#   3. The kernel is actually using console=ttyS0 (requires node rebuild)
#
# Usage:
#   ./scripts/check-serial-console.sh
#   ./scripts/check-serial-console.sh --proxmox-host carbon
#   ./scripts/check-serial-console.sh --threshold 300  # 5 minutes
#
# Exit codes:
#   0  Serial console is working
#   1  Serial console service not running
#   2  Serial log file missing or empty
#   3  No recent data in serial log
#   4  Kernel not using console=ttyS0 (requires node rebuild)

set -euo pipefail

PROXMOX_HOST="${PROXMOX_HOST:-carbon}"
THRESHOLD="${THRESHOLD:-60}"  # seconds of staleness before warning
VERBOSE="${VERBOSE:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) sed -n '2,/^# Exit codes/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --proxmox-host=*) PROXMOX_HOST="${1#*=}" ;;
    --proxmox-host)   PROXMOX_HOST="$2"; shift ;;
    --threshold=*)    THRESHOLD="${1#*=}" ;;
    --threshold)      THRESHOLD="$2"; shift ;;
    --verbose)        VERBOSE=1 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
  shift
done

log()  { [[ "$VERBOSE" -eq 1 ]] && echo "$*" || true; }
warn() { echo "WARNING: $*" >&2; }
err()  { echo "ERROR: $*" >&2; }

# Check if we can reach the Proxmox host
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "root@$PROXMOX_HOST" "echo ok" >/dev/null 2>&1; then
  err "Cannot reach Proxmox host $PROXMOX_HOST via SSH"
  exit 1
fi

# Check if the serial logger service is running
log "Checking vm-110-serial-logger service status..."
service_status=$(ssh "root@$PROXMOX_HOST" "systemctl is-active vm-110-serial-logger.service" 2>/dev/null || echo "unknown")
if [[ "$service_status" != "active" ]]; then
  err "Serial logger service is not active (status: $service_status)"
  err "Run: systemctl start vm-110-serial-logger.service"
  exit 1
fi
log "✓ Serial logger service is active"

# Check if the serial log file exists and has content
log "Checking serial log file..."
log_info=$(ssh "root@$PROXMOX_HOST" "ls -lh /var/log/vm-110-serial.log 2>/dev/null || echo 'missing'" 2>/dev/null)
if [[ "$log_info" == "missing" ]]; then
  err "Serial log file /var/log/vm-110-serial.log does not exist"
  err "The service may not have started yet, or the VM serial socket is not available"
  exit 2
fi
log "✓ Serial log file exists: $log_info"

# Check if the log file has recent data
log "Checking for recent data in serial log..."
last_modified=$(ssh "root@$PROXMOX_HOST" "stat -c %Y /var/log/vm-110-serial.log" 2>/dev/null)
now=$(date +%s)
age=$(( now - last_modified ))

if [[ "$age" -gt "$THRESHOLD" ]]; then
  warn "Serial log has not been updated in ${age}s (threshold: ${THRESHOLD}s)"
  warn "This may indicate the serial console is not receiving data"
  warn "Last modified: $(ssh "root@$PROXMOX_HOST" "date -d @$last_modified" 2>/dev/null)"

  # Check if the VM is running
  vm_status=$(ssh "root@$PROXMOX_HOST" "qm status 110" 2>/dev/null || echo "unknown")
  if [[ "$vm_status" != "status: running" ]]; then
    err "GPU VM (110) is not running (status: $vm_status)"
    exit 3
  fi

  # Check if the serial socket exists
  socket_exists=$(ssh "root@$PROXMOX_HOST" "test -S /var/run/qemu-server/110.serial0 && echo yes || echo no" 2>/dev/null)
  if [[ "$socket_exists" != "yes" ]]; then
    err "Serial socket /var/run/qemu-server/110.serial0 does not exist"
    err "The VM may not have serial0 configured, or QEMU is not running"
    exit 3
  fi

  warn "Serial socket exists and VM is running, but no recent data"
  warn "This likely means the kernel is not outputting to console=ttyS0"
  warn "The node needs to be rebuilt with the new schematic containing console=ttyS0"
  exit 4
fi

log "✓ Serial log has recent data (last updated ${age}s ago)"

# Check if kernel is using console=ttyS0
log "Checking kernel console configuration on GPU node..."
if command -v talosctl >/dev/null 2>&1; then
  cmdline=$(talosctl -n 192.168.1.110 read /proc/cmdline 2>/dev/null | tail -1 || echo "")
  if [[ -n "$cmdline" ]]; then
    if echo "$cmdline" | grep -q "console=ttyS0"; then
      log "✓ Kernel is using console=ttyS0"
    else
      warn "Kernel is NOT using console=ttyS0"
      warn "Current cmdline: $cmdline"
      warn "The node needs to be rebuilt with the new schematic to apply console=ttyS0"
      exit 4
    fi
  else
    warn "Could not read /proc/cmdline from GPU node (talosctl may not be configured)"
  fi
else
  log "talosctl not found, skipping kernel console check"
fi

echo "✓ Serial console is working correctly"
echo "  Service: active"
echo "  Log file: /var/log/vm-110-serial.log (updated ${age}s ago)"
[[ "${cmdline:-}" =~ console=ttyS0 ]] && echo "  Kernel: console=ttyS0"

exit 0
