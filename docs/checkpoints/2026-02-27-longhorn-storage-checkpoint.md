# Longhorn + Mimir Storage Incident Checkpoint (2026-02-27)

## Context
Cluster: `Interstellar` (Talos + Longhorn)

Primary symptoms:
- Longhorn `Volume Degraded/Faulted` alerts
- PVC pressure alerts
- Mimir instability and remote_write failures
- Alert summaries showing `[no value]` (template issue tracked separately in `grafana-alerting.yaml`)

## Root Cause Summary
1. **Longhorn disk scheduling pressure**: all 3 Longhorn disks were unschedulable for new replicas (`DiskPressure`) due scheduled bytes above provisioning limits.
2. **Replica/manager disruption window**: multiple replica failures occurred during manager/instance-manager/API connectivity instability, leaving many volumes degraded/faulted.
3. **Mimir PVC near full**: `data-mimir-0` was close to limit and Mimir had repeated failures earlier.

## Before (captured state)
### Disk schedulability
- `talos-3eo-d4m`: unschedulable (`DiskPressure`), scheduled ~80+ GiB on 61.79 GiB disk
- `talos-hsi-gnb`: unschedulable (`DiskPressure`), scheduled ~78+ GiB on 61.79 GiB disk
- `talos-ueo-rhk`: unschedulable (`DiskPressure`), scheduled ~74+ GiB on 61.79 GiB disk

### Longhorn settings (before)
- `storage-over-provisioning-percentage = 150`
- `default-replica-count = 3`

## Changes Applied (live cluster)
1. Set Longhorn `default-replica-count` to `2`.
2. Patched all existing Longhorn volumes from `numberOfReplicas: 3` to `2` (16 volumes).
3. Increased Longhorn `storage-over-provisioning-percentage` from `150` to `200`.
4. Resized Mimir PVC from `10Gi` to `16Gi`:
   - `observability/data-mimir-0` -> `spec=16Gi`, `status.capacity=16Gi`.

## GitOps / Manifest updates made
- `Kubernetes/bootstrap/longhorn/kustomization.yaml`
  - `defaultSettings.storageOverProvisioningPercentage: 200`
  - `defaultSettings.defaultReplicaCount: 2`
- `Kubernetes/bootstrap/longhorn/storageclass.yaml`
  - `longhorn` + `longhorn-rwx` `parameters.numberOfReplicas: "2"`
- `Kubernetes/bootstrap/observability/mimir.yaml`
  - PVC request increased to `16Gi`

## Current Disk Showdown (after changes)

| Node | Disk | Total GiB | Free GiB | Free % | Scheduled GiB | Schedulable |
|---|---|---:|---:|---:|---:|---|
| talos-3eo-d4m | default-disk-080400000000 | 61.79 | 19.82 | 32.09% | 85 | True |
| talos-hsi-gnb | default-disk-080400000000 | 61.79 | 18.46 | 29.87% | 84 | True |
| talos-ueo-rhk | default-disk-080400000000 | 61.79 | 19.14 | 30.98% | 80 | True |

## Remaining non-healthy Longhorn volume
- `security/clamav-db` (`pvc-9b7a05da-6cda-4673-8c71-c052c9385f55`): `robustness=unknown`, `state=detached`, replicas=2

## Mimir “what clogs it” breakdown
Mimir volume inspected directly by mounting `data-mimir-0` in a debug pod.

### Filesystem usage inside `/data`
- `/data` total visible: **~1007.5 MiB**
- `/data/blocks`: **~998.6 MiB**
- `/data/tsdb-sync`: ~5.9 MiB
- `/data/tsdb`: ~2.7 MiB
- `/data/compactor`: ~52 KiB

### Largest block directories (`/data/blocks/anonymous`)
- `01KJBSJBHBBGQR06AT34FTJ6J0`: ~631.1 MiB
- `01KJD4SNEF2YRS7X4XZXWG0KCN`: ~143.4 MiB
- `01KJBY85QC82Z53CTFEV7XNXM9`: ~64.2 MiB
- `01KJC53WZCN59Y1MA7MXYJVXQE`: ~34.3 MiB
- multiple blocks around ~17 MiB each
- total block dirs counted: 16

### Why Longhorn showed much larger “actual size” than visible `/data`
- Longhorn snapshot for Mimir volume:
  - snapshot `e3556ce0-1cf6-48e6-8911-7ff8472997d6`
  - reported size around **~9.4 GiB**
- Conclusion: most occupied backend space was snapshot/layer overhead, not just live files currently visible in `/data`.

## Volume right-sizing matrix (recommendation checkpoint)
> Note: Kubernetes/Longhorn does **not** support shrinking bound PVCs in place. Downsize requires migration to new PVCs.

| Namespace | PVC | Requested GiB | Used GiB | Used % | Replicas (now) | Recommended GiB |
|---|---|---:|---:|---:|---:|---:|
| media | radarr-config | 5 | 0.40 | 7.94% | 2 | 2 |
| media | seerr-config | 2 | 0.00 | 0.00% | 2 | 2 |
| media | qbittorrent-config | 1 | 0.06 | 6.40% | 2 | 2 |
| home | adguard-data | 5 | 0.19 | 3.77% | 2 | 2 |
| observability | data-mimir-0 | 16 | 8.78 | 54.88% | 2 | 16 |
| crowdsec | crowdsec-data | 5 | 0.17 | 3.34% | 2 | 2 |
| authentik | data-authentik-postgresql-0 | 5 | 0.25 | 4.99% | 2 | 2 |
| traefik | traefik | 1 | 0.05 | 4.76% | 2 | 2 |
| media | prowlarr-config | 2 | 0.24 | 12.01% | 2 | 2 |
| observability | grafana-data | 5 | 0.33 | 6.56% | 2 | 2 |
| utilities | mcpjungle-config | 1 | 0.05 | 4.75% | 2 | 2 |
| media | jellyfin-config | 10 | 2.07 | 20.69% | 2 | 8 |
| media | bazarr-config | 2 | 0.10 | 4.86% | 2 | 2 |
| security | clamav-db | 1 | 0.05 | 4.76% | 2 | 2 |
| utilities | immich-postgres | 10 | 0.52 | 5.21% | 2 | 2 |
| media | sonarr-config | 5 | 0.56 | 11.21% | 2 | 2 |
| observability | data-loki-0 | 10 | 0.56 | 5.55% | 2 | 2 |

## Important constraints / notes
- In-place PVC shrink is not possible; only expansion is supported.
- True right-sizing down requires per-app migration (new smaller PVC + data copy + swap).
- `storage-over-provisioning-percentage=200` improves schedulability but increases overcommit risk.

## Suggested next checkpoint tasks
1. Migrate oversized PVCs (10Gi/5Gi classes with <1Gi usage) to smaller claims in maintenance windows.
2. Repair `security/clamav-db` detached/unknown volume.
3. Recheck alert noise after Longhorn settles and Grafana alert templates are re-applied via Argo.
