# Proxmox Host Power Optimization (Phase 2)

**Date:** 2026-06-18
**Server:** carbon (Proxmox VE 7.0.6-2 on Debian 13 trixie, AMD Ryzen 9 3950X, 64GB DDR4)
**Goal:** Reduce idle wall power further after the 2026-06-14 Phase 1 work, with minimal performance cost and no hardcoded/manual tweaks.
**Companion spec:** `2026-06-18-gpu-dmc-firmware-design.md` (GPU runtime PM via DMC firmware).

## Context

Phase 1 (commits `d06ea0e`, `1dd2f96`, 2026-06-14) already applied: ASPM=force, TLP, powertop auto-tune, powersave governor + `balance_power` EPP, SATA link power `min_power`, WiFi rfkill block, postfix disabled, `hd-idle` installed, GPU telemetry exporter removed.

Measured via Home Assistant smart-plug sensor `sensor.serwer_current_consumption` (HA VM 102 at `192.168.1.186`, queried via HA REST API with the long-lived token):

| Window | Mean | Idle floor (min) |
|---|---|---|
| Before Phase 1 (Jun 10-14) | 147.4 W | 100.4 W |
| After Phase 1  (Jun 15-18) | 130.2 W | 83.3 W |

Phase 1 saved ~17 W mean / ~17 W idle floor. Current draw ~143 W (HDDs spinning).

## Current State (verified on carbon 2026-06-18)

**ZFS `Storage` pool (5x 3TB 7200RPM HDD, RAIDZ1):**
- `atime=on` (default) — **every read writes an access-time update, poking all 5 disks.** OpenZFS explicitly recommends `atime=off` or `relatime=on`.
- `recordsize=128K` (default) — fine for mixed workloads, suboptimal for large sequential media.
- `compression=zstd` (already set, `local` source) — good, no change needed. (zstd gives better ratio than lz4 with fast decompression; OpenZFS docs recommend lz4 as the safe default but zstd is equal or better here.)
- `zfs_txg_timeout=5` (default) — transaction group commits every 5s, writing to all vdevs.
- `hd-idle -i 600 -c scsi` — **`-c scsi` is wrong for these SATA drives**; it never issues real ATA STANDBY. `smartctl -n standby` confirms all 5 disks sit at `IDLE_A`/`IDLE_B` (heads parked, platters spinning), never `STANDBY`.
- **Dataset structure:** `Storage` is a single dataset (no children); `Media`, `Photos`, `personal` are directories, not child datasets. NFS exports: `/Storage` to talos nodes, `/Storage/Media` and `/Storage/Photos` to `192.168.1.0/24`.
- **qBittorrent downloads:** `downloads-pvc` (shared NFS PVC on `Storage`) is mounted at `/downloads` in qbittorrent, sonarr, and radarr. Bit Torrent's 16K random writes hit the spinning pool constantly while downloading.

**Unused USB devices (both `runtime_status=active`, no consumer):**
- `1462:7c37` MSI MYSTIC LIGHT (RGB controller) — no RGB daemon running.
- `1a86:7523` QinHeng CH340 serial converter — no getty, no UPS software (nut/apcupsd inactive), no `/dev/ttyUSB*` consumer.

**Unused NIC:**
- `nic0` (1GbE) — `state DOWN`, no carrier. `power/control=auto` but never suspends because it's a host NIC with no runtime PM partner.

**CPU:**
- Governor `powersave`, EPP `balance_power`, driver `amd-pstate-epp`. RAPL package ~42 W (cores ~1.8 W, uncore ~40 W). Uncore only reducible via BIOS undervolt — **out of scope** (not codifiable, risky).

## Research: How the community solves "ZFS keeps HDDs awake"

OpenZFS Workload Tuning docs (`https://openzfs.github.io/openzfs-docs/Performance%20and%20Tuning/Workload%20Tuning.html`) directly address this workload:

1. **`atime=off`** (or `relatime=on`) — "Set either relatime=on or atime=off to minimize IOs used to update access time stamps." Every read becomes a write otherwise. Zero perf cost, zero risk.
2. **Bit Torrent section** — "16KB writes cause read-modify-write overhead… can be avoided by using a dedicated dataset for bit torrent downloads with recordsize=16KB… configure your client to download the files to a temporary directory and then copy them into their final location." qBittorrent downloads should land on NVMe/SSD first, then Sonarr/Radarr "move" them to HDD on import — only bursty completed-file writes hit the spinning pool.
3. **Sequential workloads section** — "Set `recordsize=1M` on datasets that are subject to sequential workloads." Media streaming is the canonical case.
4. **`zfs_txg_timeout`** — not mentioned in Workload Tuning docs as a power lever; it's a transaction-delay tunable. Bumping it is a fine-tuning last step, not the primary fix. With `atime=off` + workload relocation, the only writes to `Storage` are infrequent imports + housekeeping, so a longer txg timeout lets disks sleep between bursts.

Community consensus (Proxmox/TrueNAS forums): `hdparm -S` + `hd-idle` only works if (a) the `-c` flag matches the transport (ATA for SATA, scsi for SAS), and (b) nothing is writing to the disks. Most "spindown doesn't work" reports trace to `atime=on` or background writes (scrubs, SMART polling, Docker/k8s volume housekeeping), not to `hd-idle` itself.

## Design

### Workflow (per change)

1. Apply a reversible test fix on carbon via SSH (or talos-1 via `talosctl` for the GPU spec).
2. Allow stabilization (HDD changes: wait for a quiet window or overnight; USB/NIC: ~10 min).
3. Measure via HA `sensor.serwer_current_consumption` (REST API `GET /api/history/period/...` with the long-lived token; bucket by day, compare mean/min/max before vs after).
4. Verify no performance/stability regression (media streaming still responsive, no ZFS errors, no service breakage).
5. **Only if the test wins and is stable**, codify into the repo (`Ansible/setup-proxmox.yaml` `power` tag, plus NFS/K8s PVC changes for the workload relocation).
6. Final verification: confirm Ansible is idempotent and a re-run doesn't revert live state.

All measurement is ad-hoc HA queries. **No Grafana/Mimir/HA-Prometheus codification** (per user decision 2026-06-18).

### Changes (test order, cheapest/safest first)

#### Change 1 — ZFS hygiene on `Storage` (L1)

| Property | From | To | Why |
|---|---|---|---|
| `atime` | `on` | `off` | Stop every read from writing. Biggest free win. |
| `recordsize` on `Storage/Media` | (n/a — `Media` is a dir, not a dataset) | `1M` on a new `Storage/Media` child dataset | Large sequential media streaming → fewer IOs. **Optional/deferred:** requires creating a child dataset and moving media data into it (large `zfs send|recv` or `mv`). Only do this if Change 1 (`atime=off`) + Change 3 (workload relocation) aren't enough on their own. Setting `recordsize=1M` on `Storage` itself would also affect downloads (bad for BT 16K writes). |

**Test:** `zfs set atime=off Storage` (instant, reversible: `zfs set atime=on`). Wait 10 min, watch HA floor. Measure 24h overnight floor. (Compression is already `zstd` — no change.) The `recordsize=1M` change is deferred pending dataset restructure — see Change 3 notes.

**Expected:** Disks reach `STANDBY` during idle periods (verify `smartctl -n standby /dev/sd[a-e]` shows `STANDBY` not `IDLE_A/B`). HA floor drops significantly — `atime=off` alone may be the single biggest lever.

**Codify:** `Ansible/setup-proxmox.yaml` — add a `zfs set` task block under the `power` tag. These are pool-level, idempotent (`zfs set` is a no-op if already set).

#### Change 2 — Fix `hd-idle` to actually reach STANDBY (L4)

| Setting | From | To | Why |
|---|---|---|---|
| `HD_IDLE_OPTS` | `-i 600 -c scsi` | `-i 600 -c ata` | SATA drives need ATA standby, not SCSI. |
| `hdparm -S` per drive | (already `-S 120` in power-tuning.service) | keep, verify | 10-min standby timer at the drive level. |

**Test:** Edit `/etc/default/hd-idle`, `systemctl restart hd-idle`. Confirm with `smartctl -n standby /dev/sd[a-e]` after a 10-min idle window.

**Codify:** `Ansible/setup-proxmox.yaml` — change the `HD_IDLE_OPTS` line in the `hd-idle` defaults template.

#### Change 3 — Workload relocation: qBittorrent downloads off spinning pool (L2)

Only proceed if Change 1+2 leaves disks spinning too often (i.e. background downloads are still the culprit).

Move the shared `downloads-pvc` from NFS `Storage` (spinning HDD) to Longhorn on NVMe. **Blast radius:** `downloads-pvc` is mounted by qbittorrent (`/downloads`), sonarr, and radarr — all three read/write completed downloads through this PVC. Sonarr/Radarr already "move" completed files on import to `media-pvc` (NFS `Storage/Media`) — after relocation, only bursty completed-file writes hit the HDDs.

**Test:** Plan a PVC migration affecting all three pods: scale qbittorrent/sonarr/radarr to 0, create a new Longhorn PVC (`downloads-longhorn`) sized to hold active downloads, `cp -a` existing downloads from NFS to Longhorn via a temporary job, update the `downloads` volume in all three deployments to reference the new PVC, scale back up. Verify downloads + imports still work, then verify HDDs stay asleep during a download-only period (no imports). Check existing manifests in `Kubernetes/apps/{qbittorrent,sonarr,radarr}/deployment.yaml` for exact mount names before implementing.

**Codify:** `Kubernetes/apps/qbittorrent/deployment.yaml`, `Kubernetes/apps/sonarr/deployment.yaml`, `Kubernetes/apps/radarr/deployment.yaml` (change the `downloads` volume `claimName`); new `Kubernetes/apps/common/downloads-pvc-longhorn.yaml` (or extend `media-pv.yaml`). ArgoCD auto-syncs. **Observe AGENTS.md safety rule:** patch the existing PVC/deployments in-place, never delete+recreate.

**Risk:** Medium — touches 3 deployments and a shared PVC. Reversible by switching the volume back to `downloads-pvc`. Follow the Longhorn `emergency_ro` guidance in `Kubernetes/AGENTS.md` if any volume issues arise.

#### Change 4 — Disable unused USB devices

| Device | ID | Method | Why |
|---|---|---|---|
| MSI MYSTIC LIGHT (RGB) | `1462:7c37` | udev rule: `ACTION=="add", ATTR{idVendor}=="1462", ATTR{idProduct}=="7c37", RUN+="/bin/sh -c 'echo > /sys$DEVPATH/driver/unbind'"` | No RGB daemon; pure power waste. |
| CH340 serial | `1a86:7523` | udev rule: same pattern with `1a86`/`7523` | No getty, no UPS, no consumer. |

**Test:** Manually unbind each (`echo > /sys/bus/usb/devices/<dev>/driver/unbind`), measure ~10 min each, confirm no service breaks (check `journalctl -u getty@tty*`, `systemctl status nut-server nut-driver apcupsd` all still inactive).

**Codify:** `Ansible/setup-proxmox.yaml` — add a `copy` task for `/etc/udev/rules.d/99-power-usb-unbind.rules` under the `power` tag.

**Expected:** ~1-3 W combined.

#### Change 5 — Power off unused `nic0`

`nic0` (1GbE) is `DOWN` with no carrier. Already `power/control=auto`, but host NICs don't runtime-suspend. Options:
- (a) Unbind the driver (if removable) — `echo > /sys/bus/pci/devices/<addr>/driver/unbind`, then PCI PM kicks in.
- (b) If unbind breaks something (it shouldn't — it's down), leave it and accept the small draw.

**Test:** Unbind, measure, verify no network breakage (`ip link` still shows `nic1`/`vmbr0`/`tailscale0` up).

**Codify:** `Ansible/setup-proxmox.yaml` — udev rule or a one-shot systemd service.

**Expected:** ~1-2 W.

#### Change 6 — (Optional, test-only) EPP `balance_power`→`power`

**Test:** `cpupower set -b power` (all cores), measure HA power for 30 min, run a quick CPU bench (e.g. a Jellyfin transcode sample or `sysbench cpu run`). If no measurable perf drop and a measurable power drop, keep. Else revert to `balance_power`.

**Codify:** Only if it helps — update the TLP config `CPU_ENERGY_PERF_POLICY_ON_AC` line in `Ansible/setup-proxmox.yaml`.

**Expected:** 0-2 W. Likely small because the CPU is already at the floor.

### Explicitly out of scope

- **BIOS undervolt** — not codifiable, risky, violates "no hardcoding".
- **ZFS prefetch disable** — hurts media-streaming throughput (violates "minimal perf loss").
- **PSU right-sizing** — hardware change, not codifiable.
- **Measurement codification** (Grafana/Mimir/HA-Prometheus) — per user decision 2026-06-18, ad-hoc HA queries only.
- **GPU** — handled in the companion spec `2026-06-18-gpu-dmc-firmware-design.md`.

## Rollback

| Change | Revert |
|---|---|
| 1 ZFS hygiene | `zfs set atime=on Storage` (compression already zstd, no change) |
| 2 hd-idle | `HD_IDLE_OPTS=-i 600 -c scsi`; `systemctl restart hd-idle` |
| 3 Workload relocation | Switch qBittorrent PVC back to NFS `Storage` |
| 4 USB unbind | `udevadm trigger --action=add` rebinds; remove udev rule |
| 5 nic0 unbind | `udevadm trigger` or `echo > /sys/bus/pci/drivers/<drv>/bind` |
| 6 EPP | `cpupower set -b balance_power` |

All changes are reversible in seconds to minutes.

## Success Criteria

- Measurable reduction in HA idle floor: target ~83 W → ~55-60 W (HDD spindown + USB + NIC).
- Mean power: target ~130 W → ~110-115 W (depending on how often media stack lets HDDs sleep).
- No ZFS errors (`zpool status Storage` clean) over 1 week.
- Media streaming still responsive (Jellyfin/Jellyfin transcoding unaffected; cold-access latency of 5-10s on first NFS access after idle is acceptable — per user decision 2026-06-18).
- qBittorrent downloads still work after workload relocation.
- Ansible playbook idempotent: re-run produces no changes once applied.

## Key Gotchas (to append to root AGENTS.md after implementation)

- **`hd-idle -c scsi` never spins down SATA drives** — must use `-c ata` for SATA, `-c scsi` for SAS. The original Phase 1 config used `-c scsi` on SATA HDDs, so disks sat at `IDLE_A/B` (heads parked, platters spinning) forever, never reaching `STANDBY`.
- **ZFS `atime=on` prevents HDD spindown** — every read writes an atime update to all vdevs in the pool. Set `atime=off` (or `relatime=on`) on any pool where spindown matters. This is the single biggest free lever for ZFS-on-HDD power, and it's a default-`on` footgun.
- **qBittorrent downloads on a spinning ZFS pool keep disks awake** — Bit Torrent's 16K random writes are the exact pattern OpenZFS docs call out as preventing idle. Relocate downloads to NVMe/SSD; Sonarr/Radarr "move" on import already handles the bursty completed-file writes to HDD.
