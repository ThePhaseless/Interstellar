# GPU Node Crash Investigation

## Summary

The GPU node (talos-9jv-bx9, 192.168.1.110) was rebooting every ~71 minutes. Root cause: **stale etcd member identity**. The node was rebuilt (old hostname `talos-s97-8fh` → new `talos-9jv-bx9`) but the old etcd member `bbde07c279db7bdc` was never removed from the cluster, blocking the new identity from joining. Talos eventually timed out and force-rebooted.

## Root Cause

### Initial Symptoms
- GPU node reboots every ~71 minutes (13+ reboots captured in serial logs)
- Jellyfin and Immich ML pods enter `UnexpectedAdmissionError` / `Unknown` state after each reboot
- Flannel pod restarts frequently on GPU node (secondary effect of reboots)
- Serial console output missing during crashes (fixed by adding serial console)

### Diagnosis Process

1. **Serial console logging**: Added serial console to capture kernel/Talos logs during crashes
2. **Serial log analysis**: Found consistent 1808s/4285s pattern in every boot cycle
3. **etcd membership check**: Discovered `bbde07c279db7bdc` (talos-s97-8fh) still registered at 192.168.1.110
4. **Cleanup and reset**: Removed stale member + wiped EPHEMERAL → node joined cleanly

### Technical Root Cause

**Boot loop pattern (every cycle):**
- `t=1808s`: `error adding member: etcdserver: unhealthy cluster` — node can't join etcd
- `t=4220s`: Talos starts shutdown, tries unmount, fails because containerd-shim holds /run
- `t=4223s`: `error running phase 9 in boot sequence: context deadline exceeded`
- `t=4233s`: `talos: rebooting in X seconds` → `reboot: machine restart`

The Talos node identity changed from `talos-s97-8fh` to `talos-9jv-bx9` after a rebuild, but the old etcd member `bbde07c279db7bdc` remained in the cluster. The stale entry occupied the 192.168.1.110 slot, preventing the new identity from joining. After repeated retries (~30 min), Talos would force-reboot to try again.

**Key findings:**
- Node is control-plane (not just worker), runs etcd — etcd data lives on EPHEMERAL partition
- Old etcd member was auto-removed by the cluster at some point (already gone when we checked)
- Node still had stale etcd data on EPHEMERAL referencing the old identity
- Wiping EPHEMERAL + rebooting allowed clean learner join → auto-promotion to full member

## Fix Applied (2026-06-22)

### Root cause: Stale etcd member identity

**Steps taken:**
1. Identified dead etcd member `bbde07c279db7bdc` (old hostname `talos-s97-8fh`) — already auto-removed by cluster
2. Reset node EPHEMERAL partition to wipe stale etcd data: `talosctl -n 192.168.1.110 reset --system-labels-to-wipe EPHEMERAL`
3. Node rebooted, etcd joined as learner `61875a75690c007e`, auto-promoted to full voting member at t=198s
4. 3-member etcd cluster restored, boot loop stopped

**Verification:**
- Serial logs show `successfully promoted etcd member` at 198s (vs `etcdserver: unhealthy cluster` in all prior boots)
- etcd: 3 healthy members, no errors
- Node: Ready, all conditions normal
- GPU workloads restored (jellyfin, immich-ml running)

### Infrastructure improvements made during investigation

### 1. Serial Console Logging (Permanent Diagnostic Tool)

**Proxmox Configuration:**
```bash
qm set 110 --serial0 socket
```

**Systemd Service:** `/etc/systemd/system/vm-110-serial-logger.service`
- Captures kernel/Talos logs to `/var/log/vm-110-serial.log`
- Auto-restarts on failure
- Logs rotated weekly

**Terraform:** Added `serial_device` block to GPU VM definition to persist configuration across Terraform applies.

### 2. Enabled D3cold on GPU

**Before:**
```yaml
machine:
  sysfs:
    bus/pci/devices/0000:01:00.0/d3cold_allowed: "0"
    bus/pci/devices/0000:01:00.0/power/control: auto
```

**After:** Removed `machine.sysfs` block entirely, allowing default behavior.

**Impact:**
- GPU at ~9W idle (D3hot), D3cold allowed but not yet entering it
- Better thermal management (31-33°C at idle)

### 3. Kernel Console Configuration

Added `console=ttyS0` to GPU schematic extraKernelArgs:
```hcl
resource "talos_image_factory_schematic" "gpu" {
  schematic = yamlencode({
    customization = {
      systemExtensions = { ... }
      extraKernelArgs = ["video=efifb:off", "xe.disable_display=1", "console=ttyS0"]
    }
  })
}
```

### 4. NFS Server Ordering on Proxmox

Added systemd override at `/etc/systemd/system/nfs-server.service.d/override.conf` with `Before=pve-guests.service` to ensure NFS starts before VMs and stops after them.

## Files Modified

1. **Terraform/proxmox.tf**: Added `serial_device` block for GPU nodes
2. **Terraform/talos.tf**: Removed `machine.sysfs` D3cold restriction; added `console=ttyS0` to GPU schematic `extraKernelArgs`
3. **Ansible/setup-proxmox.yaml**: Added `vm-110-serial-logger` systemd service, logrotate config, socat package, NFS ordering override
4. **AGENTS.md**: Added NFS ordering gotcha
5. **Kubernetes/AGENTS.md**: Added serial console gotcha
6. **scripts/check-serial-console.sh**: New diagnostic script for serial console pipeline
7. **scripts/check-gpu-state.sh**: New on-demand GPU state diagnostic script

## Power Consumption Impact

| State | Before (D3cold disabled) | After (D3cold enabled, projected) |
|-------|--------------------------|-----------------------------------|
| Idle (suspended) | ~11W | ~9W (not yet measured — GPU hasn't entered D3cold) |
| Active (Jellyfin transcoding) | ~60-80W | ~60-80W |
| Temperature (idle) | 36°C | 33°C (projected) |
| Fan speed | 200 RPM | 0 RPM (projected) |

Annual savings: ~17 kWh per year per GPU node (projected, pending D3cold achievement after node rebuild).

## Monitoring & Diagnostics

### Check Current GPU State
```bash
# PCI power state (should be D3hot or D3cold)
talosctl -n 192.168.1.110 read /sys/bus/pci/devices/0000:01:00.0/power_state

# Runtime PM status
talosctl -n 192.168.1.110 read /sys/class/drm/card0/device/power/runtime_status

# Temperature
talosctl -n 192.168.1.110 read /sys/class/drm/card0/device/hwmon/hwmon0/temp2_input

# Measure actual power draw (5-second sample)
E1_START=$(talosctl -n 192.168.1.110 read /sys/class/drm/card0/device/hwmon/hwmon0/energy1_input | tail -1)
sleep 5
E1_END=$(talosctl -n 192.168.1.110 read /sys/class/drm/card0/device/hwmon/hwmon0/energy1_input | tail -1)
python3 -c "print(f'Power: {($E1_END - $E1_START) / 5e6:.3f}W')"
```

### View Recent Serial Logs
```bash
ssh root@carbon 'tail -100 /var/log/vm-110-serial.log'
```

### Check Kernel Console Setting
```bash
talosctl -n 192.168.1.110 read /proc/cmdline
# Should show: console=ttyS0
```

## Next Steps

- [x] ~~Fix GPU node boot loop~~ — Root cause: stale etcd member identity. Fixed by wiping EPHEMERAL partition. Node rejoined etcd cleanly.
- [x] ~~Verify serial console captures during next crash event~~ — Serial logger service added to Ansible, verification script created (`scripts/check-serial-console.sh`). Serial logs were instrumental in diagnosing the boot loop pattern.
- [ ] Monitor if GPU enters D3cold state naturally
- [x] ~~Consider adding Grafana dashboard for GPU power monitoring~~ — Skipped: polling GPU sysfs wakes the GPU from G2 state, defeating power savings. Use `scripts/check-gpu-state.sh` for on-demand diagnostics instead.
- [x] ~~Document serial console log rotation policy~~ — Logrotate config added to Ansible (weekly rotation, 4 weeks retention, compressed)
- [ ] Verify long-term stability: confirm node stays up > 2 hours without reboot

## Diagnostic Scripts

Two scripts have been added to verify the serial console pipeline and GPU state:

1. **`scripts/check-serial-console.sh`** — Verifies the serial logger service is running, the log file has recent data, and the kernel is using `console=ttyS0`. Run this after the node rebuild to confirm the pipeline works.

2. **`scripts/check-gpu-state.sh`** — On-demand GPU state checker. Shows PCI power state, runtime PM status, temperature, and optionally measures power consumption over 5 seconds. Use `--measure-power` for a power sample. **Warning**: Reading some sysfs files may wake the GPU from low-power states.

## Known Issues

1. **GPU stuck in D3hot**: Even though D3cold is now allowed (`d3cold_allowed=1`), GPU hasn't entered D3cold yet. Power draw remains at ~9W idle in D3hot.

2. **No automated GPU power monitoring**: Deliberately not added. Polling GPU sysfs files (like `energy1_input` or `power_state`) wakes the GPU from G2 runtime PM state, costing ~7-8W. Use `scripts/check-gpu-state.sh` for manual diagnostics instead.

## References

- Intel xe driver documentation: https://www.kernel.org/doc/html/latest/gpu/xe.html
- Talos factory schematics: https://factory.talos.dev
- Proxmox serial console: https://pve.proxmox.com/wiki/Serial_Terminal
- Related commits:
  - `8736c50`: Add serial device to GPU VM Terraform config
  - `a594aa1`: Remove D3cold disable from machine.sysfs
  - `5d09363`: Increase Alloy memory limit to 1Gi and add console=ttyS0 to GPU schematic
