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

### Firmware injection method (revised during planning)

**Methods A and C below were ruled out during planning.** Method B is simplified: no custom extension build is needed because the **official `siderolabs/i915` extension** already ships the full `i915/` firmware dir (including `bmg_dmc.bin`). Image Factory schematics only support `officialExtensions`, so a truly custom extension would require running a private Image Factory — not worth it when the official i915 extension solves the problem.

#### Method A — Talos `machine.files` (RULED OUT)

Investigated during planning: `machine.files.content` is a **literal string** with no base64 decode path (confirmed by generating a sample config with `talosctl gen config --with-examples`). A 45KB binary firmware cannot be expressed as a literal string. Additionally, `/usr/lib/firmware` is on the Talos immutable rootfs, so `machine.files` cannot write there. **Not viable.**

#### Method B — Official `siderolabs/i915` extension (the path we use)

The `i915` extension (`drm/i915/pkg.yaml` in `siderolabs/extensions`) runs `cp -R -p /usr/lib/firmware/i915 /rootfs/usr/lib/firmware` — exactly the line missing from `drm/xe/pkg.yaml`. Adding `siderolabs/i915` to `talos_gpu_extensions` in `Terraform/variables.tf` makes Image Factory include the i915 extension in the GPU schematic, which ships `bmg_dmc.bin` (and the rest of the `i915/` firmware dir) into talos-1's rootfs.

**Why this is safe (no driver conflict):** The i915 extension also ships the i915 kernel module, but the B580 (device ID `8086:e20b`) is claimed by the `xe` driver, not `i915`. The `xe` driver binds first (it's in the GPU schematic already), and `i915` does not claim `e20b`. So i915's kernel module loads but does not bind to the GPU; only its firmware files are used (by `xe`, which loads DMC from the `i915/` path regardless of which extension shipped it). Verify post-upgrade that `xe` is still the bound driver (Task 3 Step 5 of the plan).

This is both the **test** and the **interim codification** — no separate test-injection step needed. The permanent fix is the upstream PR (Task 5 of the plan) to add the `i915/` copy to `drm/xe/pkg.yaml` directly, after which the `i915` extension can be removed from `talos_gpu_extensions`.

#### Method C — Privileged pod with hostPath (RULED OUT)

`/usr/lib/firmware` is on the immutable rootfs; a hostPath mount + write would fail or be lost on reboot. **Not viable.**

Run a privileged pod on talos-1 (GPU node) with `hostPath: /usr/lib/firmware` mounted RW, copy the file in, reboot the node. Not codifiable (the file lives on the ephemeral overlay and is lost on upgrade), but confirms the fix works before investing in extension build. Only use if A and B are blocked.

### Verification (all three must pass before codifying)

1. **Dmesg:** `talosctl --nodes 100.67.213.79 dmesg | grep -i dmc` shows DMC firmware loaded, **no** "Disabling runtime power management" line.
2. **Runtime PM:** `talosctl --nodes 100.67.213.79 read /sys/bus/pci/devices/01:00.0/power/runtime_status` returns `suspended` when GPU is idle (wait ~30s after no GPU workload); `suspended_time` increments.
3. **Wall power:** HA `sensor.serwer_current_consumption` idle floor drops ~8W vs the pre-fix baseline (measure over the same idle window as the host spec).

### Performance verification (no regression)

- Jellyfin: trigger a transcode (play a media item requiring transcode), confirm GPU wakes (`runtime_status` → `active`) within seconds and transcode runs at full speed (no FPS drop vs baseline).
- Immich: trigger an ML job (e.g. face detection on a new upload), confirm GPU wakes and completes normally.

### Codification (only after test passes)

1. **Interim: keep `siderolabs/i915` in `Terraform/variables.tf` `talos_gpu_extensions`** (this is the same change as the test — no custom extension build needed). Add a comment explaining it's a temporary workaround:
   ```hcl
   variable "talos_gpu_extensions" {
     default = [
       "siderolabs/mei",
       "siderolabs/xe",
       # Temporary: ships i915/bmg_dmc.bin so xe runtime PM works.
       # Remove once siderolabs/extensions PR #<N> merges and the xe
       # extension includes i915/ firmware by default.
       "siderolabs/i915",
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
