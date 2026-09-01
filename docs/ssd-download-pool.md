# SSD download pool with HDD overflow

qBittorrent downloads and seeds from a mergerfs union that prefers the NVMe and
overflows to the HDD array. Radarr/Sonarr copy finished files into the library.
Unsafe ZFS settings are confined to two dedicated datasets holding nothing but
re-downloadable torrent data.

## Why this shape

Three branches, so that **every new download gets `sync=disabled` regardless of
which tier it lands on**, with no migration. The existing 2.4 TiB stays exactly
where it is and joins the union as a no-create branch: still readable and
writable for the torrents already there, never chosen for new files.

```
/downloads  (one NFS mount, mergerfs union)
├── /ssdstage/dl             RW  NVMe  sync=disabled   ← new, empty, priority
├── /Storage/dl              RW  HDD   sync=disabled   ← new, empty, overflow
└── /Storage/Media/Downloads NC  HDD   sync=standard   ← existing 2.4 TiB, drains over time

        ↓  Radarr/Sonarr copy (no hardlink — accepted)

/media/{Movies,TVShows}         HDD   sync=standard
```

Both unsafe datasets are created **empty**, so there is nothing to copy. `Storage`
itself keeps `sync=standard`, so every existing and future directory under it
inherits durable behaviour — `sync=disabled` is set locally on the two download
datasets and cannot spread by inheritance.

The `NC` branch is a drain-only tier: as old torrents finish seeding and are
removed it empties, and can eventually be dropped from the union entirely.

## Validated by test before rollout (2026-09-01)

Run against scratch datasets on carbon, then torn down completely:

| Behaviour | Result |
| --- | --- |
| `category.create=ff` places new files on the SSD branch | pass |
| `moveonenospc` relocates a file grown past SSD capacity, mid-write | pass |
| Same, driven through nfsd from a pod — checksum intact | pass |
| Inode stable across a mergerfs restart (`noforget` + `inodecalc=path-hash`) | pass |
| Client reads survive a mergerfs restart, no stale handles | pass |
| With the SSD full, new files go to the RW overflow branch, not the `NC` one | pass |
| Pre-existing files on the `NC` branch stay visible and writable | pass |

Throughput, 512 MiB sequential to the NVMe: 139 MB/s through FUSE+NFS versus
168 MB/s plain NFS — roughly 20% for FUSE, against a workload that peaks near
60 MB/s. Two to ten times more headroom than needed.

## As built (2026-09-01)

Implemented and live. The 37 incomplete torrents were relocated first — 25 onto
the NVMe (78 GiB, projected 157 GiB at completion) and 12 onto the HDD dataset
(396 GiB) — so nothing had to be re-fetched. 2.0 TiB of completed seeders stayed
on the legacy branch to drain.

After cutover: `write_cache_overload` 44% -> 0%, `queued_io_jobs` 6018 -> 0,
106 torrents resumed with zero rechecks and zero missing files.

Allocation to the NVMe was by *projected final* size, not current size: these
files are sparse, so packing by today's footprint would fill the pool as they
grow and trigger a `moveonenospc` copy per torrent.

## Steps

### 1. The two download datasets

```
zfs create -o sync=disabled -o recordsize=1M -o compression=off ssdstage/dl
zfs create -o sync=disabled -o recordsize=1M -o compression=off Storage/dl
```

`sync=disabled` is set **locally** on each, never inherited from a parent, so it
cannot spread to anything else. Both are created empty — no migration.

### 2. mergerfs on carbon

Package plus a systemd mount unit, both from `Ansible/setup-proxmox.yaml`.
Do not hand-install: the test copy was deliberately removed to leave no drift.

```
mergerfs -o category.create=ff,minfreespace=25G,moveonenospc=true,\
noforget,inodecalc=path-hash,cache.files=partial,dropcacheonclose=true,allow_other \
  '/ssdstage/dl=RW:/Storage/dl=RW:/Storage/Media/Downloads=NC'  /srv/downloads
```

Branch order is the create order: NVMe first, HDD overflow second. The `NC` mode
on the third branch is what keeps new downloads off the `sync=standard` dataset
while leaving the torrents already there fully functional.

`minfreespace=25G` exceeds the ~24 GiB average torrent, so a new torrent only
starts on the NVMe if it can plausibly finish there; `moveonenospc` catches the
rest.

### 3. Export and PV

The union needs an explicit `fsid` — nfsd cannot derive one for FUSE.

Add `/srv/downloads` to `nfs_exports` in `Ansible/vars/proxmox.yaml`, and add a
`downloads-pool-nfs-pv` + `downloads-pool-pvc` to
`Kubernetes/apps/common/media-pv.yaml` (server placeholder `REPLACED_BY_KUSTOMIZE`,
registered in the root `kustomization.yaml` replacement list).

Point qBittorrent, Radarr and Sonarr at the new PVC in place of `downloads-pvc`,
keeping the container path `/downloads` so no application config changes.

### 4. qBittorrent

`Session\TempPathEnabled` stays **false** — there is no temp/final split in this
design; torrents download and seed in place on whichever branch they landed on.
Enable recheck-on-completion so every file is hash-verified before Radarr copies
it, and set seeding limits so finished torrents are removed and the NVMe recycles.

### 5. Fix the export drift

`/etc/exports` carries six lines; `nfs_exports` declares three. `/Storage/Media`,
`/Storage/Photos` and `/ssdstage/downloads` are live but unmanaged — their
`192.168.1.0/24` host spec does not match the playbook's template, so the
`lineinfile` task never matches them. Bring all three under Ansible as part of
this work, and retire `/ssdstage/downloads` and `downloads-ssd-pvc`, which this
design supersedes.

## Verify

1. `findmnt /srv/downloads` shows `fuse.mergerfs`; `df` reports the combined size.
2. From the qBittorrent pod, a new file appears under `/ssdstage/dl` on carbon.
3. Existing torrents still seed — their files resolve through the HDD branch.
4. Fill the NVMe past `minfreespace` and confirm the next torrent lands on the
   HDD branch instead of erroring.
5. Confirm a completed torrent is copied into the library and plays in Jellyfin.

## Operational notes

- **A mergerfs restart is not a clean stop/start while exported.** knfsd holds a
  reference; `umount` fails with `EBUSY` until `exportfs -f` flushes the export
  cache. Sequence: `exportfs -u`, `exportfs -f`, `umount`, remount, re-export.
- **Upgrading the package does not restart the daemon.** mergerfs keeps serving
  from the deleted binary, so a version bump takes effect only on remount.
- `nconnect` cannot be set per-PV here. The NFS client keys transports per
  server, so the first mount to carbon wins and later mounts inherit its
  connection count. Using it at all would mean setting the same value on every
  carbon-backed PV.

## Rollback

Point the three deployments back at `downloads-pvc`, unmount mergerfs, then
destroy `ssdstage/dl` and `Storage/dl` once anything on them has finished seeding.
The pre-existing torrent data is untouched throughout — it never leaves
`/Storage/Media/Downloads`, which is why this is cheap to reverse.

## Deliberately not doing

- **Hardlinks.** Forgone in exchange for the SSD path; imports stay a full copy.
  Recoverable later by unioning the library into the same mount, at which point
  HDD-resident files could hardlink and SSD-resident ones would fall back to copy.
- **`sync=disabled` on `Storage`,** and the Photos/Media/Downloads dataset splits.
  All make future directories unsafe by omission or cost a long migration.
- **NFS tuning.** `rsize`/`wsize` are already at the 1 MiB maximum and nfsd runs
  16 threads measured idle. Jumbo frames remain untried but affect every VM on
  the bridge.
