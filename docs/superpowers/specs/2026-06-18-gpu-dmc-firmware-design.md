# GPU DMC Firmware Fix for xe Runtime Power Management

**Date:** 2026-06-18
**Server:** carbon (Proxmox VE) → talos-1 VM (110) → Intel Arc B580 GPU (PCI `2f:00.0` on host, `01:00.0` in VM via `vfio-pci` passthrough)
**Goal:** Restore `xe` driver runtime PM by shipping the missing DMC firmware, recovering ~8W idle power with zero performance cost.
**Companion spec:** `2026-06-18-proxmox-host-power-design.md` (host-side HDD/USB/NIC changes).

## Context

The root `AGENTS.md` records (Key Gotchas):

> **Intel Arc GPU monitoring cost ~7-8W**: The Xe driver's `disable_display=1` plus PCIe L1.2 gets the GPU to ~9W idle on Talos (DMC firmware is missing, so full D3cold/runtime PM is hard-disabled). Any periodic sysfs reads from `/sys/class/drm/card0/device/tile0/gt*/freq0/cur_freq` or `throttle/reason_*` wake the GT out of G2 — don't add GPU metric exporters or scrapers.

This framed the missing DMC firmware as a permanent condition. **It is not — it is a fixable bug in the Talos `xe` system extension.**

## Root Cause (confirmed 2026-06-18)

`talosctl --nodes 100.67.213.79 dmesg` on talos-1 shows:

```
xe 0000:01:00.0: Direct firmware load for i915/bmg_dmc.bin failed with error -2
xe 0000:01:00.0: [drm] Failed to load DMC firmware i915/bmg_dmc.bin (-ENOENT). Disabling runtime power management.
```

The `xe` driver looks for the Display Microcontroller (DMC) firmware at the legacy path `i915/bmg_dmc.bin`. Missing file → the driver **hard-disables runtime PM** → the GPU can never reach D3cold and sits at ~9W forever, even when idle.

### Why the firmware is missing

The Sidero Labs `xe` Talos system extension (`drm/xe/pkg.yaml` in `siderolabs/extensions`) only copies the `xe/` firmware subdir into the image:

```yaml
# drm/xe/pkg.yaml (current)
- install:
    - |
      mkdir -p /rootfs/usr/lib/firmware
      cp -R -p /usr/lib/firmware/xe /rootfs/usr/lib/firmware
```

It ships GuC (`bmg_guc_70.bin`), HuC (`bmg_huc.bin`), GSC, and fan-control firmware under `xe/`, but **not** the `i915/` directory. The `xe` driver, however, still loads DMC firmware from `i915/bmg_dmc.bin`.

Verified on talos-1: `/usr/lib/firmware/xe/` contains `bmg_guc_70.bin`, `bmg_huc.bin`, `fan_control_8086_e20b_8086_1100.bin`, `lnl_gsc_1.bin`, `lnl_guc_70.bin`, `lnl_huc.bin`, `ptl_gsc_1.bin`, `ptl_guc_70.bin`, `ptl_huc.bin`. `/usr/lib/firmware/i915/` **does not exist**.

The `i915` extension (`drm/i915/pkg.yaml`) does copy `i915/` — so this is an oversight in the `xe` extension, which was copied from `i915` (PR #845, merged Oct 2025) but only kept the `xe/` subdir.

`bmg_dmc.bin` exists upstream in `intel-gpu/intel-gpu-firmware` and in `linux-firmware` (the package the Talos pkgs chain builds from).

### Expected impact of the fix

With DMC firmware loaded, `xe` runtime PM engages. When no GPU workload is running (no Jellyfin transcode, no Immich ML), the GPU drops from ~9W to <1W (D3cold). GPU workloads wake it in milliseconds — **zero performance cost**. Expected HA wall-power drop: ~8W at idle and during non-GPU periods.

## Design

### Workflow (test-first, then codify — per user decision 2026-06-18)

1. **Test-inject** `i915/bmg_dmc.bin` onto talos-1 via the least-invasive method that works.
2. **Reboot** talos-1 (firmware is loaded at driver init).
3. **Verify** the fix worked: dmesg shows DMC loaded (no "Disabling runtime PM"), `/sys/bus/pci/devices/01:00.0/power/runtime_status` cycles to `suspended` when GPU is idle.
4. **Measure** HA wall power: expect ~8W drop at idle floor.
5. **Verify perf** unchanged: Jellyfin transcode + Immich ML still wake the GPU instantly and run at full speed.
6. **Only if the test wins**, codify: build a minimal custom Talos system extension that ships `i915/bmg_dmc.bin`, register it in the Image Factory schematic, add to `Terraform/variables.tf` `talos_gpu_extensions`.
7. **File upstream PR** to `siderolabs/extensions` adding `cp -R -p /usr/lib/firmware/i915 ...` to `drm/xe/pkg.yaml` so the custom extension can eventually be retired.
8. **Update the root `AGENTS.md` GPU gotcha** to reflect that this is a fixable bug, not a permanent condition (after the fix is confirmed in production).

### Test-injection methods (try in order)

#### Method A — Talos `machine.files` URL patch (preferred if `/usr/lib/firmware` is writable)

Talos machine config supports `machine.files` entries that write files at boot. Check whether a `machine.files` entry with `path: /usr/lib/firmware/i915/bmg_dmc.bin`, `op: append`, and a `content`/URL source works on talos-1. If `/usr/lib/firmware` is part of the writable overlay (not the immutable squashfs), this is the cleanest test path — no image rebuild.

**Test:**
```bash
# Fetch the firmware from intel-gpu/intel-gpu-firmware (verify checksum)
curl -L -o /tmp/bmg_dmc.bin https://github.com/intel-gpu/intel-gpu-firmware/raw/main/firmware/bmg_dmc.bin
sha256sum /tmp/bmg_dmc.bin
# Expected: 76e3ec6ea3a53ce727e43b84f5ea14c55400a2d118dac356d4e12a3cfac06b4d (45964 bytes)

# Patch talos-1 machine config to write the file (test via talosctl patch)
# Note: op=overwrite for a new file (op=append would append to an existing file)
# The firmware is ~45KB → base64 is ~60KB inline, feasible in a machine.files content entry.
talosctl --nodes 100.67.213.79 patch machineconfig --patch='[{"op":"add","path":"/machine/files/-","value":{"path":"/usr/lib/firmware/i915/bmg_dmc.bin","permissions":420,"op":"overwrite","content":"<base64-encoded-firmware>"}}]'
# Reboot talos-1
talosctl --nodes 100.67.213.79 reboot
```

If `machine.files` `content` must be a string (not base64), encode the 45KB firmware as base64 and inline it. If Talos rejects writes to `/usr/lib/firmware/` (immutable rootfs), fall back to Method B. **Verify `machine.files` schema in Talos v1.13 docs before patching** — the `op` field values and `content` encoding may differ from the example above.

#### Method B — Custom system extension (if rootfs is immutable)

Build a minimal Talos system extension that ships only `i915/bmg_dmc.bin`:
- `pkg.yaml` modeled on `drm/xe/pkg.yaml` but copying `i915/bmg_dmc.bin` (and ideally the whole `i915/` DMC subset) into `/usr/lib/firmware/i915/`.
- Push to a registry the Image Factory can pull (or use the Talos `imager` tool to build a custom installer image directly).
- Test by applying a new schematic to talos-1 only, reinstalling the node, rebooting.

This is more work but is the production-grade path and what we'd codify anyway. If Method A works, we still need this for the codified state (Method A's `machine.files` is a test convenience; the durable fix is an extension so it survives upgrades).

#### Method C — Privileged pod with hostPath (last resort, not durable)

Run a privileged pod on talos-1 (GPU node) with `hostPath: /usr/lib/firmware` mounted RW, copy the file in, reboot the node. Not codifiable (the file lives on the ephemeral overlay and is lost on upgrade), but confirms the fix works before investing in extension build. Only use if A and B are blocked.

### Verification (all three must pass before codifying)

1. **Dmesg:** `talosctl --nodes 100.67.213.79 dmesg | grep -i dmc` shows DMC firmware loaded, **no** "Disabling runtime power management" line.
2. **Runtime PM:** `talosctl --nodes 100.67.213.79 read /sys/bus/pci/devices/01:00.0/power/runtime_status` returns `suspended` when GPU is idle (wait ~30s after no GPU workload); `suspended_time` increments.
3. **Wall power:** HA `sensor.serwer_current_consumption` idle floor drops ~8W vs the pre-fix baseline (measure over the same idle window as the host spec).

### Performance verification (no regression)

- Jellyfin: trigger a transcode (play a media item requiring transcode), confirm GPU wakes (`runtime_status` → `active`) within seconds and transcode runs at full speed (no FPS drop vs baseline).
- Immich: trigger an ML job (e.g. face detection on a new upload), confirm GPU wakes and completes normally.

### Codification (only after test passes)

1. **Custom extension** — create a `siderolabs/intel-dmc-firmware` (or local) extension image shipping `i915/bmg_dmc.bin`. Add to `Terraform/variables.tf` `talos_gpu_extensions`:
   ```hcl
   variable "talos_gpu_extensions" {
     default = [
       "siderolabs/mei",
       "siderolabs/xe",
       "<registry>/intel-dmc-firmware",  # new
     ]
   }
   ```
   The `talos_image_factory_schematic.gpu` in `Terraform/talos.tf` already rebuilds when `talos_gpu_extensions` changes (`lifecycle.replace_triggered_by`), so the schematic + installer image update automatically on `terraform apply`.

2. **Upstream PR** — file a PR to `siderolabs/extensions` modifying `drm/xe/pkg.yaml`:
   ```yaml
   - install:
       - |
         mkdir -p /rootfs/usr/lib/firmware
         cp -R -p /usr/lib/firmware/xe /rootfs/usr/lib/firmware
         cp -R -p /usr/lib/firmware/i915 /rootfs/usr/lib/firmware  # ADD THIS LINE
   ```
   Once merged and released, drop the custom extension from `talos_gpu_extensions`.

3. **AGENTS.md update** — rewrite the GPU gotcha from "DMC firmware is missing, so full D3cold/runtime PM is hard-disabled" to "The Talos `xe` extension historically omitted `i915/` DMC firmware; the fix ships it via a custom extension pending upstream merge. Do not re-add GPU metric exporters — periodic sysfs reads still wake the GT."

### Rollback

- **Test-injection:** `talosctl revert` or reboot without the patch (file is on ephemeral overlay for Method A; remove extension + reinstall for Method B).
- **Codified:** remove the custom extension from `talos_gpu_extensions`, `terraform apply` (rebuilds schematic, reinstall talos-1). GPU returns to ~9W, no data loss.

## Success Criteria

- `xe` driver loads DMC firmware at boot (dmesg confirmed).
- GPU `runtime_status` reaches `suspended` when idle.
- HA wall power drops ~8W at idle (measured alongside the host spec).
- Jellyfin transcode and Immich ML performance unchanged (GPU wakes instantly, full speed).
- Custom extension (if used) survives `terraform apply` idempotently and a Talos upgrade.
- Upstream PR filed (link to be added here once opened).

## Key Gotchas (to append to root AGENTS.md after implementation)

- **The Talos `xe` extension omits `i915/` DMC firmware** — the `xe` driver still loads DMC from `i915/bmg_dmc.bin`, so without it runtime PM is hard-disabled and the GPU sits at ~9W forever. This is a fixable extension bug, not a hardware limit. Fix: ship `i915/bmg_dmc.bin` via a custom extension (pending upstream PR to `drm/xe/pkg.yaml`).
- **Do not re-add GPU metric exporters even after the DMC fix** — periodic sysfs reads from `/sys/class/drm/card0/device/tile0/gt*/freq0/cur_freq` or `throttle/reason_*` still wake the GT out of G2 and cost ~7-8W. The DMC fix enables *idle* runtime suspend; it does not make the GPU immune to polling-induced wakeups.
