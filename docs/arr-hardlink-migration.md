# Enabling \*arr hardlinks (eliminating the duplicate-write on import)

## Problem

Radarr and Sonarr have `copyUsingHardlinks: true`, attempt a hardlink on every
import, get `EXDEV`, and silently fall back to a **full copy**. Every finished
download is therefore written to the `Storage` RAIDZ1 a second time.

Measured on the running cluster:

```
/media       st_dev=1048746   192.168.1.10:/Storage/Media
/downloads   st_dev=1048746   192.168.1.10:/Storage/Media/Downloads
ln /downloads/<file> /media/.probe  →  EXDEV: Cross-device link
```

The `st_dev` values are identical — same server, same export, shared superblock.
The link still fails because Linux `do_linkat()` and `do_renameat2()` compare the
**vfsmount**, not the device. Two PersistentVolumes are two mounts, so any link or
rename between them is `EXDEV` no matter what the backing storage is.

## The lever

`/Storage/Media/Downloads` is a *subdirectory* of `/Storage/Media`. Radarr and
Sonarr already mount `/Storage/Media` at `/media`, so **the downloads are already
reachable at `/media/Downloads` on the same vfsmount as `/media/Movies`.** Nothing
has to move on disk. Only the path \*arr resolves the download to has to change.

## Current state

| Setting | Radarr | Sonarr |
| --- | --- | --- |
| Root folder | `/media/Movies` | `/media/TVShows` |
| Download client host | `qbittorrent.media.svc.cluster.local` | same |
| Category | `movies` | `tv` |
| Remote path mappings | none | none |
| `copyUsingHardlinks` | `true` | `true` |

qBittorrent: `save_path=/downloads`, `auto_tmm_enabled=true`, categories `movies`
and `tv` with empty `savePath` (so paths derive as `/downloads/<category>`).
`temp_path=/downloads-ssd` with `temp_path_enabled=false`.

On-disk layout (`/Storage/Media`):

```
Downloads/   2.4 TiB   ← mounted separately as /downloads
  movies/ tv/ tv-sonarr/ radarr/ Minerva_Myrient/
  temp/{movies,tv}      ← qBittorrent incomplete files
Movies/  TVShows/  Scans/
```

## Phase 1 — add remote path mappings (delivers the entire win)

Add to `Terraform/apps/servarr.tf`:

```hcl
resource "radarr_remote_path_mapping" "qbittorrent_downloads" {
  host         = "qbittorrent.media.svc.cluster.local"
  remote_path  = "/downloads/"
  local_path   = "/media/Downloads/"
}

resource "sonarr_remote_path_mapping" "qbittorrent_downloads" {
  host         = "qbittorrent.media.svc.cluster.local"
  remote_path  = "/downloads/"
  local_path   = "/media/Downloads/"
}
```

`host` must match the configured download client's host string exactly or the
mapping is ignored silently.

qBittorrent keeps reporting `/downloads/movies/X`; \*arr now resolves that to
`/media/Downloads/movies/X`, which shares a vfsmount with `/media/Movies`, so
`link()` succeeds and the import writes **zero bytes**.

Run `./scripts/port-forward-apps.sh` first, then `terraform plan` locally before
pushing — CI auto-applies on `main`.

### Verify

1. Hardlink probe from the radarr pod — must now succeed:
   `ln /media/Downloads/movies/<file> /media/.probe && rm /media/.probe`
2. Import one item, then `stat -c '%h %n'` the resulting library file: link
   count must be `2`, not `1`.
3. Radarr log should no longer show a copy for that import.
4. Watch `zpool iostat Storage` during an import — write bytes should stay flat.

## Phase 2 — drop the redundant `/downloads` mount (cleanup)

Remove the `downloads-pvc` volume and its `/downloads` mount from
`Kubernetes/apps/radarr/deployment.yaml` and `Kubernetes/apps/sonarr/deployment.yaml`.
qBittorrent keeps its own `/downloads` mount — do not touch it, and do not delete
the PV or PVC.

Do this only after Phase 1 is verified. While both paths exist the mapping already
routes through `/media/Downloads`; removing the mount just prevents a silent
regression back to the `EXDEV` path.

## Phase 3 (optional, later) — reclaim existing duplicates

Every previously imported file exists twice: once under `Downloads/`, once in the
library. `jdupes -L` can relink them in place and reclaim that space. Do this only
after Phases 1–2 are stable, with a dry run first, and note that relinking a file
an active torrent is seeding is safe (same inode, same content) but deleting one
of the links later is what must be reasoned about carefully.

## What deliberately does not change

- qBittorrent's config, save paths, categories, temp path
- Root folders (`/media/Movies`, `/media/TVShows`) and the on-disk library layout
- `bazarr`, `jellyfin`, `decluttarr`, `copyparty` — they mount only `/media`
- NFS exports, PersistentVolumes, PersistentVolumeClaims

## Rollback

Delete the two Terraform resources. \*arr reverts to resolving `/downloads`, and
the copy-on-import behaviour returns. No data is moved or rewritten at any point,
so rollback is free.

## Relationship to the ZFS/NFS tuning

Independent and complementary:

- **This change** removes an entire duplicate write of every import — the largest
  reduction in write *bytes* available.
- **`sync=disabled` / `async` export** removes NFS COMMIT latency (34.8 ms/commit,
  matching the 25–36 ms HDD flush) — a reduction in write *latency*.
- **NVMe staging** (`Session\TempPathEnabled`) stays blocked: 384 GiB of
  already-downloaded incomplete data against a 231 GiB pool.

Do this one first: biggest effect, no data movement, trivially reversible.
