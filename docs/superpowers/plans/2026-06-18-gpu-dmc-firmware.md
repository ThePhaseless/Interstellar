# GPU DMC Firmware Fix for xe Runtime PM Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore `xe` driver runtime PM on talos-1 by shipping the missing `i915/bmg_dmc.bin` firmware, recovering ~8W idle power with zero performance cost.

**Architecture:** Add the official `siderolabs/i915` extension to talos-1's schematic (ships the full `i915/` firmware dir, including `bmg_dmc.bin`) → rebuild installer via Terraform → upgrade talos-1 → verify DMC loads + runtime PM engages + ~8W drop → file upstream PR to fix the `xe` extension → once merged, remove the `i915` extension.

**Tech Stack:** Talos v1.13.4, Terraform `talos` provider, Image Factory, `talosctl`, siderolabs/extensions (upstream PR).

**Spec:** `docs/superpowers/specs/2026-06-18-gpu-dmc-firmware-design.md`

**Spec correction (discovered during planning):** Method A (`machine.files`) in the spec is infeasible — `machine.files.content` is a literal string with no base64 decode (can't write 45KB binary), and `/usr/lib/firmware` is on the Talos immutable rootfs. Method C (hostPath pod) is infeasible for the same rootfs-immutability reason. The viable path is adding the **official `siderolabs/i915` extension** (which copies `i915/` firmware including `bmg_dmc.bin`) to the GPU schematic. This is both the test and the interim codification. Image Factory schematics only support `officialExtensions` (no custom extensions), so the permanent fix is the upstream PR to `siderolabs/extensions drm/xe/pkg.yaml`.

**HA measurement command (same as Plan 1):**
```bash
HA_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiI5YjMzNzVkMjMzMDc0ZjE0OGRkOTMxYjM2YWU1MWIwNSIsImlhdCI6MTc4MTgwMDIzNywiZXhwIjoyMDk3MTYwMjM3fQ.XDs0wPukWHygi2LlrXF17bv-_x2DUNEmKISZSqZ90qU"
curl -s -H "Authorization: Bearer $HA_TOKEN" \
  "http://192.168.1.186:8123/api/history/period/<START_ISO>?filter_entity_id=sensor.serwer_current_consumption&end_time=<END_ISO>&minimal_response" \
  | python3 -c "import json,sys,statistics,collections; d=json.load(sys.stdin)[0]; b=collections.defaultdict(list); [b[s['last_changed'][:10]].append(float(s['state'])) for s in d if s['state'] not in ('unavailable','unknown','none','')]; [print(f'{day:12s} n={len(v):5d} min={min(v):6.1f} mean={statistics.mean(v):7.1f} med={statistics.median(v):7.1f} max={max(v):7.1f}') for day,v in sorted(b.items())]"
```

---

### Task 1: Record baseline + confirm the bug

- [ ] **Step 1: Confirm dmesg still shows the bug** — `talosctl --nodes 100.67.213.79 dmesg 2>/dev/null | grep -iE "dmc|runtime power management"`. Expect: `Failed to load DMC firmware i915/bmg_dmc.bin (-ENOENT). Disabling runtime power management.`
- [ ] **Step 2: Confirm GPU runtime_status is always active** — `talosctl --nodes 100.67.213.79 read /sys/bus/pci/devices/01:00.0/power/runtime_status` → `active`. And `talosctl --nodes 100.67.213.79 read /sys/bus/pci/devices/01:00.0/power/runtime_suspended_time` → near-zero (was 1423ms over 41h).
- [ ] **Step 3: Record HA power baseline** — use the HA measurement command for the last 24h. Record the idle floor (expect ~83W post-Phase-1, or whatever Plan 1 achieved if Plan 1 ran first).
- [ ] **Step 4: Confirm `/usr/lib/firmware/i915/` is absent on talos-1** — `talosctl --nodes 100.67.213.79 ls /usr/lib/firmware/i915 2>&1` → not found. And `talosctl --nodes 100.67.213.79 ls /usr/lib/firmware/xe` → shows `bmg_guc_70.bin` etc. but no `bmg_dmc.bin`.

### Task 2: Add `siderolabs/i915` to GPU extensions (test via Terraform)

**Files:**
- Modify: `Terraform/variables.tf:97-104` (`talos_gpu_extensions` default list)

**Why this works:** The `i915` extension (`drm/i915/pkg.yaml` in siderolabs/extensions) copies `/usr/lib/firmware/i915` (including `bmg_dmc.bin`) into the rootfs. The `xe` driver loads DMC firmware from `i915/bmg_dmc.bin` regardless of which extension shipped it. The i915 kernel module is also present in the extension but won't bind to the B580 (already bound to `xe`; `e20b` is a xe-driver device ID, not claimed by i915).

- [ ] **Step 1: Edit `Terraform/variables.tf`** — add `"siderolabs/i915"` to `talos_gpu_extensions`:
```hcl
variable "talos_gpu_extensions" {
  description = "TalosOS extensions to install only on GPU nodes"
  type        = list(string)
  default = [
    "siderolabs/mei",
    "siderolabs/xe",
    "siderolabs/i915",
  ]
}
```
- [ ] **Step 2: Plan Terraform** — `cd Terraform && terraform plan`. Confirm it shows: `talos_image_factory_schematic.gpu` will be replaced (new schematic ID due to changed extensions), and `talos_machine_configuration_apply.controlplane["talos-1"]` will be updated (new install image). **Other nodes (talos-2, talos-3) must NOT be affected** — they use the `base` schematic, not `gpu`. **Prerequisite:** `source scripts/setup-env.sh` for Bitwarden/Tailscale access; `export KUBE_CONFIG_PATH=~/.kube/config`.
- [ ] **Step 3: Apply Terraform** — `cd Terraform && terraform apply`. This: (a) creates a new GPU schematic in Image Factory, (b) updates talos-1's machine config with the new installer image, (c) `lifecycle.replace_triggered_by` fires the replacement.
- [ ] **Step 4: Upgrade talos-1 to the new image** — the Terraform apply updates the machine config's `install.image`, but talos-1 needs an actual upgrade to pull the new installer and rebuild the rootfs with the i915 extension:
```bash
NEW_INSTALLER=$(terraform -chdir=Terraform output -raw talos_schematic_id | python3 -c "import json,sys; print(f'factory.talos.dev/installer/{json.load(sys.stdin)[\"gpu\"]}:v1.13.4')")
talosctl --nodes 100.67.213.79 upgrade --image $NEW_INSTALLER
```
Wait for the upgrade to complete (talos-1 will reboot).
- [ ] **Step 5: Verify talos-1 rejoined the cluster** — `kubectl get node talos-1` → `Ready`. If not Ready after 5 min, check `talosctl --nodes 100.67.213.79 dmesg` for errors.

### Task 3: Verify the firmware fix worked

- [ ] **Step 1: Confirm DMC firmware loaded** — `talosctl --nodes 100.67.213.79 dmesg 2>/dev/null | grep -iE "dmc|runtime power management"`. Expect: a line like `DMC firmware i915/bmg_dmc.bin loaded` (or no error), and **no** "Disabling runtime power management" line.
- [ ] **Step 2: Confirm i915 firmware is present** — `talosctl --nodes 100.67.213.79 ls /usr/lib/firmware/i915` → should now list `bmg_dmc.bin` and other i915 firmware.
- [ ] **Step 3: Confirm GPU runtime PM engages** — wait 30s with no GPU workload (no Jellyfin transcode, no Immich ML). Then:
```bash
talosctl --nodes 100.67.213.79 read /sys/bus/pci/devices/01:00.0/power/runtime_status
# Expect: suspended
talosctl --nodes 100.67.213.79 read /sys/bus/pci/devices/01:00.0/power/runtime_suspended_time
# Expect: a number that increases over time (was 1423ms before; should now be seconds/minutes)
```
- [ ] **Step 4: Measure HA power** — run HA measurement for 2h. Compare idle floor to Task 1 baseline. Expect ~8W drop (e.g. 83W → ~75W, or less if Plan 1 already lowered it).
- [ ] **Step 5: Verify i915 module did NOT bind to the GPU** — `talosctl --nodes 100.67.213.79 ls /sys/bus/pci/devices/01:00.0/driver 2>/dev/null` → should resolve to the `xe` driver path, not `i915`. If i915 grabbed the GPU, that's a problem — revert (Task 8) and reconsider.

### Task 4: Performance verification (no regression)

- [ ] **Step 1: Jellyfin transcode test** — play a media item that requires transcoding in Jellyfin. Confirm: (a) GPU wakes (`runtime_status` → `active` within seconds), (b) transcode runs at full speed (no FPS drop vs baseline — check Jellyfin dashboard for transcoding speed), (c) after stopping, GPU returns to `suspended` within ~30s.
- [ ] **Step 2: Immich ML test** — upload a photo to Immich, trigger face detection / smart search. Confirm: GPU wakes, job completes normally, GPU returns to suspended.
- [ ] **Step 3: 24h stability check** — leave talos-1 running 24h. Confirm: no crashes, no GPU errors in dmesg, Jellyfin/Immich work normally, `kubectl get node talos-1` stays `Ready`.

### Task 5: File upstream PR to `siderolabs/extensions`

**Files:** (external repo — fork `siderolabs/extensions`)

- [ ] **Step 1: Fork and clone `siderolabs/extensions`** — `gh repo fork siderolabs/extensions --clone` (in a separate working directory outside the Interstellar repo, e.g. `/tmp/opencode/siderolabs-extensions`).
- [ ] **Step 2: Create branch** — `git checkout -b fix/xe-ship-i915-dmc-firmware`.
- [ ] **Step 3: Edit `drm/xe/pkg.yaml`** — add the `i915` firmware copy after the existing `xe` copy. Change:
```yaml
      - |
        mkdir -p /rootfs/usr/lib/firmware
        cp -R -p /usr/lib/firmware/xe /rootfs/usr/lib/firmware
```
to:
```yaml
      - |
        mkdir -p /rootfs/usr/lib/firmware
        cp -R -p /usr/lib/firmware/xe /rootfs/usr/lib/firmware
        cp -R -p /usr/lib/firmware/i915 /rootfs/usr/lib/firmware
```
- [ ] **Step 4: Commit + push + open PR** —
```bash
git add drm/xe/pkg.yaml
git commit -m "fix(xe): ship i915 DMC firmware to enable runtime PM

The xe driver loads Display Microcontroller (DMC) firmware from
i915/bmg_dmc.bin (legacy path). The xe extension currently only copies
/usr/lib/firmware/xe/, so DMC firmware is missing and the driver
hard-disables runtime power management — leaving Intel Arc GPUs (e.g.
Battlemage B580) at ~9W idle forever instead of reaching D3cold.

Add the i915/ firmware directory to the xe extension so DMC firmware is
available. The i915 kernel module is not added (only firmware files),
so there is no driver conflict.

Verified on Talos v1.13.4 with Intel Arc B580 (8086:e20b): without this,
dmesg shows 'Failed to load DMC firmware i915/bmg_dmc.bin (-ENOENT).
Disabling runtime power management.' With i915/ firmware present, DMC
loads and runtime PM engages (GPU reaches D3cold when idle, ~8W saving)."
git push -u origin fix/xe-ship-i915-dmc-firmware
gh pr create --title "fix(xe): ship i915 DMC firmware to enable runtime PM" --body "..."
```
- [ ] **Step 5: Record PR URL** — add the PR URL to the spec's "Success Criteria" and to `AGENTS.md` gotcha (next task).

### Task 6: Codify + update AGENTS.md (only if Task 3+4 pass)

**Files:**
- Modify: `Terraform/variables.tf` (i915 stays until upstream merges; add a comment)
- Modify: `AGENTS.md` (rewrite the GPU gotcha)

- [ ] **Step 1: Add a comment in `Terraform/variables.tf`** explaining the i915 extension is a temporary workaround:
```hcl
variable "talos_gpu_extensions" {
  description = "TalosOS extensions to install only on GPU nodes"
  type        = list(string)
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
- [ ] **Step 2: Rewrite the GPU gotcha in `AGENTS.md`** — replace the existing "Intel Arc GPU monitoring cost ~7-8W" bullet (around line 113) with:
```
- **Intel Arc GPU runtime PM requires DMC firmware**: The Talos `xe` extension historically omitted `i915/bmg_dmc.bin`, so `xe` hard-disabled runtime PM and the GPU sat at ~9W idle forever. This is a fixable extension bug, not a hardware limit. Fix: `siderolabs/i915` extension is added to GPU nodes (ships `i915/` firmware) pending upstream PR <URL> to `siderolabs/extensions drm/xe/pkg.yaml`. Do **not** re-add GPU metric exporters even with the fix — periodic sysfs reads from `/sys/class/drm/card0/device/tile0/gt*/freq0/cur_freq` or `throttle/reason_*` still wake the GT out of G2 and cost ~7-8W.
```
- [ ] **Step 3: Lint + commit** — `mise run lint-terraform` (for variables.tf) and `mise run lint` (for AGENTS.md format). `git add Terraform/variables.tf AGENTS.md && git commit -m "feat(talos): add i915 extension to GPU nodes for DMC firmware + runtime PM

The xe driver loads DMC firmware from i915/bmg_dmc.bin (legacy path), but
the Talos xe extension only ships /usr/lib/firmware/xe/, so runtime PM was
hard-disabled (~9W GPU idle floor). Adding siderolabs/i915 ships the missing
firmware; xe runtime PM now engages (GPU reaches D3cold when idle, ~8W saving).
Zero performance cost — GPU wakes in ms when Jellyfin/Immich need it.

Pending upstream PR to siderolabs/extensions to fix drm/xe/pkg.yaml directly."`
- [ ] **Step 4: Push + verify CI** — `git push origin main`. Watch `terraform.yaml` CI (plan on PR, apply on main — per AGENTS.md, main branch auto-applies).

### Task 7: Long-term — retire the i915 extension after upstream merge

**Precondition:** Upstream PR (Task 5) merged and a new `siderolabs/xe` extension version released that includes `i915/` firmware.

- [ ] **Step 1: Verify upstream fix shipped** — check the `siderolabs/xe` extension version available in Image Factory for the Talos version in use. Confirm `i915/bmg_dmc.bin` is now in the `xe` extension's manifest.
- [ ] **Step 2: Remove `siderolabs/i915` from `Terraform/variables.tf`** — delete the temporary entry (and its comment).
- [ ] **Step 3: Plan + apply Terraform** — `cd Terraform && terraform plan` (confirm only talos-1 affected, schematic changes), `terraform apply`. Upgrade talos-1 to the new installer image (same as Task 2 Step 4).
- [ ] **Step 4: Verify** — `talosctl --nodes 100.67.213.79 ls /usr/lib/firmware/i915/bmg_dmc.bin` still present (now from `xe` extension). `talosctl dmesg | grep -i dmc` — DMC still loads, runtime PM still works. `talosctl get extensions` — `i915` no longer listed, `xe` listed.
- [ ] **Step 5: Update AGENTS.md gotcha** — note the upstream fix has landed; remove the "temporary" framing.
- [ ] **Step 6: Commit + push** — `git add Terraform/variables.tf AGENTS.md && git commit -m "chore(talos): retire i915 extension workaround (upstream xe now ships DMC firmware)" && git push`.

### Task 8: Rollback (if Task 3 Step 5 shows i915 grabbed the GPU, or Task 4 shows perf regression)

- [ ] **Step 1: Revert `Terraform/variables.tf`** — remove `"siderolabs/i915"` from `talos_gpu_extensions`.
- [ ] **Step 2: Plan + apply Terraform** — `cd Terraform && terraform plan` (confirm schematic reverts), `terraform apply`.
- [ ] **Step 3: Re-upgrade talos-1 to the original GPU installer** — use the schematic ID without i915:
```bash
NEW_INSTALLER=$(terraform -chdir=Terraform output -raw talos_schematic_id | python3 -c "import json,sys; print(f'factory.talos.dev/installer/{json.load(sys.stdin)[\"gpu\"]}:v1.13.4')")
talosctl --nodes 100.67.213.79 upgrade --image $NEW_INSTALLER
```
- [ ] **Step 4: Verify reverted** — `talosctl dmesg | grep -i dmc` → "Disabling runtime power management" returns. GPU back to ~9W. No data loss (firmware-only change).
- [ ] **Step 5: Document why** — note in the spec/AGENTS.md that the i915-extension approach didn't work and a true custom extension (building only the firmware file, not the i915 kernel module) would be needed. File the upstream PR anyway (Task 5) since the root cause is the same.
