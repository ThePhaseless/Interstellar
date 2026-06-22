#!/usr/bin/env bash
# check-gpu-state.sh
#
# Checks the current power state and metrics of the Intel Arc GPU on talos-1.
# This is a manual diagnostic tool — NOT for automated monitoring.
#
# WARNING: Reading some sysfs files may wake the GPU from low-power states.
# Use this script sparingly for debugging, not for continuous monitoring.
#
# Usage:
#   ./scripts/check-gpu-state.sh
#   ./scripts/check-gpu-state.sh --node 192.168.1.110
#   ./scripts/check-gpu-state.sh --measure-power  # 5-second power sample
#
# Exit codes:
#   0  Success
#   1  Cannot reach GPU node
#   2  GPU device not found

set -euo pipefail

GPU_NODE="${GPU_NODE:-192.168.1.110}"
MEASURE_POWER="${MEASURE_POWER:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) sed -n '2,/^# Exit codes/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --node=*)  GPU_NODE="${1#*=}" ;;
    --node)    GPU_NODE="$2"; shift ;;
    --measure-power) MEASURE_POWER=1 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
  shift
done

# Check if talosctl can reach the node
if ! talosctl -n "$GPU_NODE" version >/dev/null 2>&1; then
  echo "ERROR: Cannot reach GPU node $GPU_NODE via talosctl" >&2
  exit 1
fi

echo "=== GPU State on $GPU_NODE ==="
echo

# PCI power state
echo "## PCI Power State:"
power_state=$(talosctl -n "$GPU_NODE" read /sys/bus/pci/devices/0000:01:00.0/power_state 2>/dev/null | tail -1 || echo "unknown")
echo "  $power_state"
case "$power_state" in
  *D0*)    echo "  → GPU is active (transcoding or idle with power)" ;;
  *D3hot*) echo "  → GPU is in hot standby (runtime PM suspended, ~9-11W)" ;;
  *D3cold*) echo " → GPU is in cold standby (lowest power, <1W)" ;;
  *)       echo "  → Unknown state" ;;
esac
echo

# Runtime PM status
echo "## Runtime PM Status:"
pm_status=$(talosctl -n "$GPU_NODE" read /sys/class/drm/card0/device/power/runtime_status 2>/dev/null | tail -1 || echo "unknown")
echo "  $pm_status"
case "$pm_status" in
  *active*)     echo "  → Device is active and drawing power" ;;
  *suspended*)  echo "  → Device is runtime-suspended (good for power savings)" ;;
  *)            echo "  → Unknown status" ;;
esac
echo

# Temperature
echo "## GPU Temperature:"
temp_raw=$(talosctl -n "$GPU_NODE" read /sys/class/drm/card0/device/hwmon/hwmon0/temp2_input 2>/dev/null | tail -1 || echo "")
if [[ -n "$temp_raw" ]]; then
  temp_c=$(( temp_raw / 1000 ))
  echo "  ${temp_c}°C"
  if [[ "$temp_c" -lt 40 ]]; then
    echo "  → Cool (idle or suspended)"
  elif [[ "$temp_c" -lt 60 ]]; then
    echo "  → Warm (light workload)"
  else
    echo "  → Hot (active transcoding)"
  fi
else
  echo "  Unable to read temperature"
fi
echo

# Fan speed (if available)
fan_raw=$(talosctl -n "$GPU_NODE" read /sys/class/drm/card0/device/hwmon/hwmon0/fan1_input 2>/dev/null | tail -1 || echo "")
if [[ -n "$fan_raw" ]]; then
  echo "## Fan Speed:"
  echo "  ${fan_raw} RPM"
  echo
fi

# Power measurement (optional, takes 5 seconds)
if [[ "$MEASURE_POWER" -eq 1 ]]; then
  echo "## Power Consumption (5-second sample):"
  energy_start=$(talosctl -n "$GPU_NODE" read /sys/class/drm/card0/device/hwmon/hwmon0/energy1_input 2>/dev/null | tail -1 || echo "")
  if [[ -n "$energy_start" ]]; then
    sleep 5
    energy_end=$(talosctl -n "$GPU_NODE" read /sys/class/drm/card0/device/hwmon/hwmon0/energy1_input 2>/dev/null | tail -1 || echo "")
    if [[ -n "$energy_end" ]]; then
      # energy1_input is in microjoules (µJ), divide by time to get watts
      power_w=$(python3 -c "print(f'{($energy_end - $energy_start) / 5e6:.2f}')" 2>/dev/null || echo "error")
      echo "  ${power_w}W"
      if [[ "$power_w" == "error" ]]; then
        echo "  Unable to calculate power"
      elif (( $(echo "$power_w < 2" | bc -l 2>/dev/null || echo 0) )); then
        echo "  → Very low power (suspended or idle)"
      elif (( $(echo "$power_w < 20" | bc -l 2>/dev/null || echo 0) )); then
        echo "  → Low power (idle with power)"
      else
        echo "  → Active (transcoding or compute)"
      fi
    else
      echo "  Unable to read energy counter (second sample)"
    fi
  else
    echo "  Unable to read energy counter (first sample)"
  fi
  echo
fi

# D3cold allowed
echo "## D3cold Configuration:"
d3cold=$(talosctl -n "$GPU_NODE" read /sys/bus/pci/devices/0000:01:00.0/d3cold_allowed 2>/dev/null | tail -1 || echo "unknown")
echo "  d3cold_allowed: $d3cold"
case "$d3cold" in
  *1*) echo "  → D3cold is allowed (GPU can enter deepest sleep state)" ;;
  *0*) echo "  → D3cold is disabled (GPU limited to D3hot)" ;;
  *)   echo "  → Unknown" ;;
esac
echo

# Kernel command line (check for console=ttyS0)
echo "## Kernel Command Line:"
cmdline=$(talosctl -n "$GPU_NODE" read /proc/cmdline 2>/dev/null | tail -1 || echo "unable to read")
echo "  $cmdline"
if echo "$cmdline" | grep -q "console=ttyS0"; then
  echo "  ✓ Serial console enabled (console=ttyS0)"
else
  echo "  ✗ Serial console NOT enabled (missing console=ttyS0)"
  echo "  → Node needs rebuild with new schematic to apply console=ttyS0"
fi
echo

echo "=== End GPU State ==="
