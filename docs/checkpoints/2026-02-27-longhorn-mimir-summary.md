# Incident Summary 2026-02-27

## Problem
- Grafana, Longhorn, and observability alerts reported degraded volumes, full PVCs, and placeholder text because alert templates lacked label fallbacks.
- Longhorn nodes were under `DiskPressure` with disks unschedulable, resulting in degraded/faulted volumes and PVCs nearly full.
- Mimir (and other apps like Seerr) surfaced I/O errors because core PVCs were saturated and Longhorn replication/manager connectivity was unstable.

## What We Did
- Updated Grafana alert templates (`grafana-alerting.yaml`) to use label fallbacks, ensure meaningful summaries, and correct the `pod-not-ready` query logic.
- Tuned authentik worker probes to tolerate longer startup/response windows so readiness failures no longer flood alerts.
- Adjusted Longhorn defaults:
  - `defaultReplicaCount` → `2`
  - `storageOverProvisioningPercentage` → `200`
  - `numberOfReplicas` on both storage classes → `2`
- Resized `observability/data-mimir-0` PVC from `10Gi` to `16Gi` and restarted the pod so Longhorn and Linux recognized the new capacity.
- Documented the incident and disk states in `docs/checkpoints/2026-02-27-longhorn-storage-checkpoint.md`.

## Current State (2026-02-27)
| Node | Disk | Total | Free | Free % | Scheduled | Schedulable |
| talos-3eo-d4m | default-disk-080400000000 | 61.79 GiB | 19.73 GiB | 31.93% | 85 GiB | True |
| talos-hsi-gnb | default-disk-080400000000 | 61.79 GiB | 18.46 GiB | 29.87% | 84 GiB | True |
| talos-ueo-rhk | default-disk-080400000000 | 61.79 GiB | 19.14 GiB | 30.98% | 80 GiB | True |

Mimir `data-mimir-0` shows ~8.9 GiB actual usage but live filesystem only reports ~1 GiB; the gap comes from Longhorn snapshots (latest ~9.4 GiB) and backend copy-on-write layers.

## Next Steps
1. Monitor Longhorn volume health (especially `security/clamav-db`) until the controller stabilizes with the new replica counts.
2. Prioritize migrating oversized PVCs (e.g., Jellyfin config, Immich) into smaller claims if their usage stays low.
3. Re-roll Grafana/Longhorn manifests through ArgoCD so templated alert fixes and Longhorn adjustments remain durable.

## Update: Continued Investigation (2026-02-27)
- Live Mimir query at current time returns zero active series (`count({__name__!=""}) = 0`), but historical blocks still exist and consume Longhorn backend space.
- 72h historical cardinality scan (`step=30m`) found:
  - first non-zero point: `2026-02-25T00:29:59Z` (`36,939` series)
  - peak point: `2026-02-26T00:29:59Z` (`58,986` series)
  - last non-zero point: `2026-02-26T17:29:59Z` (`11,407` series)
- At `2026-02-26T15:28:58Z` (~58.9k series), top contributing jobs by series count were:
  - `prometheus.scrape.cadvisor`: `27,273`
  - `prometheus.scrape.longhorn`: `11,895`
  - `prometheus.scrape.pods`: `11,320`
  - `prometheus.scrape.kubelet`: `8,447`
- Top namespaces at the same timestamp:
  - `longhorn-system`: `19,235`
  - `<none>`: `12,598` (node/cadvisor style metrics without namespace label)
  - `kube-system`: `4,710`
  - `media`: `4,074`
  - `observability`: `3,140`
- Top high-cardinality metric families at that timestamp were mostly histogram/container internals:
  - `longhorn_rest_client_request_latency_seconds_bucket` (`3,410`)
  - `longhorn_rest_client_rate_limiter_latency_seconds_bucket` (`3,410`)
  - `container_tasks_state` (`2,005`)
  - `container_memory_failures_total` (`1,604`)
  - `storage_operation_duration_seconds_bucket` (`1,274`)
- Longhorn snapshot chain for Mimir volume (`pvc-1eeb6435-0965-4be3-92d2-5022f8da4244`) still shows backend overhead:
  - `e3556ce0-1cf6-48e6-8911-7ff8472997d6`: ~`8.78 GiB`, `markRemoved=true`, `readyToUse=false`
  - `expand-17179869184`: ~`0.00 GiB`, `readyToUse=true`, parent is previous snapshot
- Remaining non-healthy Longhorn volume is unchanged:
  - `security/clamav-db` -> `robustness=unknown`, `state=detached`.
