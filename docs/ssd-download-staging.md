# Plan: NVMe staging for incomplete torrent downloads

## Problem

qBittorrent writes incomplete torrents directly to `Storage` (5x 2.7 TB HDD,
RAIDZ1) over NFS. Dozens of torrents each dribble out-of-order pieces into
different files, which turns what should be sequential writes into small random
ones. Measured under load before any tuning:

| metric | value |
|---|---|
| write latency (`await`) | 32-37 ms |
| writes/s per disk | ~207 |
| bytes per write | ~52 KiB |
| qBittorrent `write_cache_overload` | 35% of samples |
| throughput | 33.8 MB/s avg, collapsing to 0.3 |

Peers can deliver 122-162 MB/s. The array absorbs ~35. libtorrent throttles
every peer at once when its write queue fills, which is the "speed constantly
jumping" symptom.

Tuning already applied (commits `4a50f3f`, `f7ad39e`, `61c109d`) improved
latency to 13-21 ms and eliminated the worst collapses, but throughput now
plateaus at ~34 MB/s whether 50 or 91 torrents write concurrently. The disks
are saturated. Further parameter tuning cannot fix a random-write workload on
spinning disks.

## Proposal

Stage incomplete downloads on NVMe, move completed files to the HDD array as a
single sequential stream.

This is what qBittorrent's `TempPath` does natively. It writes incomplete data
to the download path and relocates each torrent to the save path on completion.

## Hardware: dedicated 256 GB SSD

A 256 GB SSD is available to install in carbon. This is preferable to carving
space out of `rpool`, which is already thin-overcommitted: 904 GB of VM volumes
plus a 61 GB root on a 928 GB pool, with the three Longhorn data disks
(`vm-11X-disk-2`) able to grow another 242 GB on their own. Any staging quota
there competes directly with Longhorn.

A dedicated disk avoids that entirely and needs no quota tuning.

`Ansible/setup-proxmox.yaml` notes a free SATA port: the FCH controller at
`2b:00.0` has host 2 empty, while `sda`/`sdb` sit on the ASMedia ASM1062 at
`26:00.0`. Either SATA or an NVMe slot works; NVMe is preferable for write
latency but SATA SSD is far beyond what the HDD array manages.

### Redundancy

A single non-redundant disk is the correct choice here. Staging holds only
incomplete downloads, which are re-downloadable by definition. Losing the disk
costs download progress, not data. Do NOT use this disk as a `special` vdev for
`Storage` - a single-disk allocation class becomes part of the pool, cannot be
removed from RAIDZ, and its loss destroys the entire array.

### Capacity

256 GB stages roughly 3-5 concurrent 4K remuxes (40-70 GB each), or a large
number of TV episodes. It does not cover the full active set at
`MaxActiveDownloads=50`, so pair it with one of:

- Lower `MaxActiveDownloads`. Note 20 slots measured only 12-21 MB/s, so this
  costs throughput.
- Stage only TV and smaller downloads via a qBittorrent category with its own
  save path, leaving large movie remuxes writing straight to the array. Most of
  the random-write pressure measured (91 concurrent writers) was TV episodes,
  so this captures most of the benefit.

The second is the better fit for what was measured.

## What already exists

`/SSDStorage` on carbon is already exported over NFS to all three Talos nodes
and consumed by copyparty via `personal-nfs-pv`:

```
/etc/exports:  /SSDStorage 127.0.0.1(rw,...) 192.168.1.110(rw,...) .111 .112
personal-nfs-pv -> 192.168.1.10:/SSDStorage
```

It is a directory on `rpool/ROOT/pve-1`, not its own dataset, and has no quota.
The export pattern and PV wiring are a working template to copy; the new disk
gets its own pool and export rather than sharing this one.

## Steps

1. Install the SSD, then create a pool on it:
   ```
   zpool create -o ashift=12 ssdstage /dev/disk/by-id/<the-new-disk>
   zfs set recordsize=1M compression=off atime=off ssdstage
   zfs create ssdstage/downloads
   ```
   `compression=off` because the measured `compressratio` on media is 1.01x -
   zstd achieves nothing on video and costs CPU per write.

2. Export it in `Ansible/setup-proxmox.yaml`, mirroring the existing
   `/SSDStorage` entry (same three Talos hosts, `rw,sync,no_subtree_check,
   no_root_squash`).

3. Add `downloads-ssd-nfs-pv` and its PVC under `Kubernetes/apps/common/`,
   copying the shape of `personal-nfs-pv`.

4. Mount it in the qBittorrent deployment at `/downloads-ssd`.

5. In `Kubernetes/apps/qbittorrent/scripts/config-init.sh`:
   ```
   'Session\\TempPathEnabled': 'true',
   'Session\\TempPath': '/downloads-ssd',
   ```

6. Verify under load: `write_cache_overload` stays at 0, HDD `await` drops
   toward the 0.7-3.7 ms measured at low concurrency, and completed torrents
   land on `Storage` rather than staying on the SSD.

7. Add the new PVC to the existing `PVC Almost Full` alert coverage. This
   matters more than it looks - see below.

## What happens if staging fills

libtorrent pauses the affected torrent and qBittorrent logs it:

```cpp
// If the storage fails to read or write files that it needs access to,
// this alert is generated and the torrent is paused.
struct TORRENT_EXPORT file_error_alert final : torrent_alert
```

Graceful in isolation: other torrents keep running, nothing is corrupted, and
space frees as completed torrents move to `Storage`.

The second-order effect is not graceful. A paused-with-error torrent surfaces in
Sonarr/Radarr as failed, and decluttarr's `remove_failed_downloads` job removes
it and triggers a re-search. So a full staging disk silently discards downloads
rather than merely pausing them. Alerting on the PVC before it fills is
therefore load-bearing, not cosmetic.

## Open question

Whether to stage everything at a lower `MaxActiveDownloads`, or stage only TV
and smaller downloads by category. The measurements favour the category split,
but it is a preference about which content gets the fast path, not a technical
conclusion.
