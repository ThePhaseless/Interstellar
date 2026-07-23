# Project Guidelines

## Architecture

GitOps homelab: TalosOS Kubernetes on Proxmox, public access via Oracle HAProxy → Tailscale → Traefik. All infrastructure is declarative and version-controlled.

| Layer                | Tool                                     | Location                                                         |
| -------------------- | ---------------------------------------- | ---------------------------------------------------------------- |
| Cluster provisioning | Terraform + Talos                        | `Terraform/`                                                     |
| VM & cloud infra     | Terraform                                | `Terraform/`                                                     |
| App configuration    | Terraform                                | `Terraform/apps/`                                                |
| Kubernetes manifests | Kustomize                                | `Kubernetes/`                                                    |
| GitOps delivery      | ArgoCD (app-of-apps)                     | `Kubernetes/bootstrap/argocd/`                                   |
| Server setup         | Ansible                                  | `Ansible/`                                                       |
| Secrets              | Bitwarden SM + External Secrets Operator | `Terraform/secrets.tf`, `Kubernetes/bootstrap/external-secrets/` |

## Conventions

Detailed conventions and gotchas live in `Kubernetes/AGENTS.md` and `Terraform/AGENTS.md`. Key cross-cutting rules:

- **Ingress**: Use Traefik `IngressRoute` CRD (`traefik.io/v1alpha1`), never standard `networking.k8s.io/v1 Ingress`
- **Namespaces**: `media`, `utilities`, `home` — declared in `Kubernetes/apps/namespaces.yaml`
- **Secrets**: Bitwarden SM + External Secrets Operator; stores are `bitwarden-store` (manual) / `bitwarden-store-generated` (Terraform-created)
- **Storage**: NFS v4.2 for shared media (`media-pvc`, `downloads-pvc`, `personal-pvc`), Longhorn CSI for app config/databases
- **Terraform naming**: Resources `kebab-case`, locals `snake_case`; secrets use `random_password` → `bitwarden-secrets_secret` with `lifecycle { ignore_changes = [value] }`

## Build & Test

```bash
# Environment (requires BWS_ACCESS_TOKEN in .env or exported)
mise trust
mise install
mise run install                          # uv sync --frozen into .venv
source scripts/setup-env.sh               # when Bitwarden-backed secrets are needed in this shell

# Linting (also runs in CI)
mise run lint                             # all linters
mise run lint-kubernetes                  # kustomize build | kube-linter
mise run lint-terraform                   # tflint
mise run lint-ansible                     # ansible-lint

# Apply
cd Terraform && terraform plan            # IaC preview
scripts/apply-kubernetes.sh               # Safe kustomize apply with diff
```

Pre-commit hooks enforce: ruff (Python), terraform fmt/validate, yaml/json formatting, secret detection.

## Maintaining These Docs

When you discover a non-obvious project behavior — something that caused a mistake, required trial-and-error, or contradicts common defaults — append it to the **Key Gotchas** section of the nearest `AGENTS.md` file (root for cross-cutting, `Kubernetes/AGENTS.md` for manifest-specific, etc.).

**Write if** the fact would prevent a future agent from making the same mistake (e.g., a port that isn't the upstream default, a resource name that must match a hardcoded reference elsewhere, an ordering dependency between resources).

**Don't write** obvious conventions already enforced by linters, information already present in these docs, temporary debugging context, or anything derivable by reading the manifest it applies to.

Keep entries to one bullet point. If a section grows beyond ~15 bullets, consolidate or remove items that have become obvious through established patterns in the codebase.

## Key Gotchas

- **Grafana's alerting provisioning file must be valid plain YAML**: Go-template expressions like `{{ printf "%.1f" $values.C }}` contain a colon (`:`) that YAML interprets as a key separator if the `summary` value is unquoted, causing Grafana to fail on startup with `mapping values are not allowed in this context`. Always quote `summary` lines that contain `printf` templates.
- **TLS terminates at Traefik**, not at the app or HAProxy. Apps serve plain HTTP internally. ArgoCD runs with `--insecure`.
- **Tailscale DNS split-horizon**: Public DNS (Cloudflare) only has Oracle VPS IP. Tailscale clients use AdGuard as their DNS (configured in `tailscale.tf`), which rewrites `*.nerine.dev` to Traefik's Tailscale IP via client-based rules in `adguard.tf`.
- **Kubernetes pods do not automatically get the same split-horizon behavior as Tailscale clients**: In-cluster server-side calls to `*.nerine.dev` still follow normal cluster DNS unless CoreDNS is explicitly taught otherwise, so OIDC discovery from pods can hit the public Oracle IP and fail even when browser-based access works.
- **For a single workload that must call a public `*.nerine.dev` hostname from inside the cluster, prefer pod-level `hostAliases` to Traefik's declarative MetalLB IP over a cluster-wide CoreDNS override**: this fixes split-horizon only where needed and keeps global DNS untouched.
- **Tailscale exit nodes on Proxmox need kernel forwarding enabled**: Advertising `0.0.0.0/0` and `::/0` is not enough; `net.ipv4.ip_forward=1` and `net.ipv6.conf.all.forwarding=1` must be set or clients lose internet when selecting the exit node.
- **Sonarr/Radarr external auth**: Init containers write `config.xml` with `<AuthenticationMethod>External</AuthenticationMethod>` — Traefik forward-auth injects `Remote-User`.
- **Longhorn `emergency_ro` recovery**: If apps report `Read-only file system`, check `/proc/mounts` for `emergency_ro`. Full recovery procedure in `Kubernetes/AGENTS.md` → Emergency Recovery.
- **Talos control-plane etcd lives under `/var/lib/etcd` inside `EPHEMERAL` on these nodes, not a dedicated `ETCD` partition**: `talosctl reset --system-labels-to-wipe ETCD` fails here; rebuilding a removed etcd member needs a broader maintenance plan than a partition-only wipe.
- **NFS server IP**: Injected via ConfigMap replacement in root `Kubernetes/kustomization.yaml`, not hardcoded.
- **Middleware namespaces matter**: When referencing a middleware from another namespace, include `namespace: <ns>` in the IngressRoute.
- **Terraform CI auto-applies on main branch**: Apply runs on any `main` branch event (push or workflow_dispatch) where the plan detects changes. Drift from manual recovery (e.g., reinstalled GPU node) can make the plan destructive on the next push; run `terraform plan` locally and reconcile state before pushing after any out-of-band node rebuild.
- **Mise only auto-loads static repo env**: `.env` and the uv-managed `.venv` come from `.mise.toml`, but Bitwarden/Tailscale exports still require `source scripts/setup-env.sh` in the shell that will run Terraform or Ansible commands.
- **Main Terraform CI uses a GitHub App token for API access**: `terraform.yaml` uses `actions/create-github-app-token@v3` to generate a token with `repo` scope for Terraform's `github_actions_variable`/`github_actions_secret` data sources. The default `GITHUB_TOKEN` with `permissions: write-all` is **insufficient** for reading repository variables and secrets via the API. The GH App ID and private key are stored in Bitwarden as `GH_APP_ID` and `GH_APP_PRIVATE_KEY`.
- **Longhorn volumes with `recurring-job-group.longhorn.io/default: enabled` auto-delete user-created snapshots**: The Longhorn admission webhook re-adds this label if removed, so snapshots created via `kubectl apply` are deleted within seconds. For migrations requiring persistent snapshots, use direct data copy via a temporary Job (mount old PVC read-only, new PVC read-write, `cp -a`) instead of the snapshot/restore flow.
- **Intel Arc GPU runtime PM requires DMC firmware**: The Talos `xe` extension historically omitted `i915/bmg_dmc.bin`, so `xe` hard-disabled runtime PM and the GPU sat at ~9W idle forever. This is a fixable extension bug, not a hardware limit. Fix: `siderolabs/i915` extension is added to GPU nodes (ships `i915/` firmware) — pending upstream PR to `siderolabs/extensions drm/xe/pkg.yaml`. Do **not** re-add GPU metric exporters even with the fix — periodic sysfs reads from `/sys/class/drm/card0/device/tile0/gt*/freq0/cur_freq` or `throttle/reason_*` still wake the GT out of G2 and cost ~7-8W.
- **Longhorn PV `nodeAffinity` is immutable**: When a workload moves to a node added after the volume was created, `dataLocality: best-effort` alone cannot overcome stale node affinity. The fix is to add a replica on the new node, detach the volume, delete the PV (after setting `reclaimPolicy: Retain`), then use Longhorn's `pvCreate` action to recreate it so the workload can schedule.
- **`hd-idle -c scsi` never spins down SATA drives** — must use `-c ata` for SATA, `-c scsi` for SAS. The original Phase 1 config used `-c scsi` on SATA HDDs, so disks sat at `IDLE_A/B` (heads parked, platters spinning) forever, never reaching `STANDBY`.
- **ZFS `atime=on` prevents HDD spindown** — every read writes an atime update to all vdevs in the pool. Set `atime=off` (or `relatime=on`) on any pool where spindown matters. This is the single biggest free lever for ZFS-on-HDD power, and it's a default-`on` footgun.
- **ZFS `zfs_txg_timeout=5` (default) prevents HDD spindown** — transaction group commits every 5s write metadata to all vdevs, keeping platters spinning. Bump to 30s via `/etc/modprobe.d/zfs.conf` to allow spindown between commits. Up to 30s of writes at risk on crash; ZFS is crash-consistent (no corruption, just replay).
- **The `1a86:7523` CH340 serial converter is the Home Assistant Zigbee coordinator** — it is passed through to the HA VM via the Proxmox `Zigbee` USB mapping (`usb0`). Do **not** unbind it in a power-optimization udev rule; doing so breaks Zigbee and requires cycling USB bus 1 (or rebooting `carbon`) to recover.
- **Talos `exec format error` with a 0-byte binary is usually corrupted containerd overlay snapshots, not wrong CPU arch**: On a fresh node, CRI can mount `/jellyfin/jellyfin` at size 0 while `talosctl debug` (inmem namespace) shows the correct binary. `talosctl image remove` + re-pull may not fix it if the overlay snapshot metadata is stuck. A targeted `talosctl reset` often leaves the disk in a half-wiped state; the reliable recovery was to stop the VM, destroy and recreate the system-disk ZVOL, boot the Talos GPU ISO, and `apply-config --insecure` again. Do not delete `io.containerd.snapshotter.v1.overlayfs` while kubelet is running — that breaks etcd/kubelet too.
- **NFS server must start before VMs and stop after them**: VMs mount NFS shares, so NFS must be available before `pve-guests.service` starts. Configured via systemd override at `/etc/systemd/system/nfs-server.service.d/override.conf` with `Before=pve-guests.service`. Systemd automatically handles reverse ordering for shutdown (VMs stop first, then NFS). Without this, VMs fail to mount NFS on boot or lose storage during shutdown.
- **Always read kernel logs via Loki (`{app="talos-kmsg-shipper"}`) before guessing at cluster root causes**: the cluster ships `/dev/kmsg` to Loki via a DaemonSet. `scripts/wait-for-gpu-crash.sh` polls for and captures the next Flannel-restart/GPU-pod-NotReady occurrence with full diagnostics. The GPU node (talos-1) is memory-constrained; Bitwarden SDK refresh storms at the top of every hour can OOM-kill Flannel and cascade into pod evictions. Workarounds: keep talos-1 ≥16 GiB RAM, pin *arr apps off the GPU node, stagger `ExternalSecret.refreshInterval` with jitter.
- **`/etc/modprobe.d/zfs.conf` changes on Proxmox require `update-initramfs -u` to survive reboot**: The ZFS module is loaded from the initramfs, and its modprobe configuration is copied into the initramfs at build time. A stale initramfs will load the old `zfs_arc_max`/`zfs_txg_timeout` values even when `/etc/modprobe.d/zfs.conf` on disk is correct. Follow any ZFS module-option change with `update-initramfs -u` (and `proxmox-boot-tool refresh`) before rebooting.
- **Grafana notification templates use a fork of alertmanager with reduced DefaultFuncs**: The fork (grafana/prometheus-alertmanager v0.25.1-based, pinned by github.com/grafana/alerting) removed humanizeDuration, humanize, since, toJson, dict, list, safeUrl, urlUnescape from upstream's DefaultFuncs. Available notification-template funcs: date, join, match, reReplaceAll, safeHtml, stringSlice, title, toLower, toUpper, trimSpace, tz (plus Go builtins like printf, len, eq, index, range). Using a missing func crashes Grafana on startup with "text templates: [alerting.notifications.templates.invalidFormat]" and the inner parse error is swallowed.

### Terraform App Configuration (`Terraform/apps/`)

See `Terraform/AGENTS.md` for directory structure, secrets management patterns, provider authentication, running instructions, and gotchas for this sub-project (Sonarr, Radarr, Prowlarr, AdGuard, Authentik, Jellyfin providers; state in Kubernetes secret backend).

## CI/CD Workflows

| Path changes                                       | Workflow triggered                                 |
| -------------------------------------------------- | -------------------------------------------------- |
| `Kubernetes/**`                                    | `kubernetes-lint.yaml`                             |
| `Terraform/apps/**`                                | `terraform-apps.yaml` (plan on PR, apply on merge) |
| `Terraform/**` (except `Terraform/apps/**`)        | `terraform.yaml` (plan on PR, apply on merge)      |
| `Ansible/**`                                       | `ansible-lint.yaml`                                |
| `Ansible/setup-*.yaml`, `Ansible/maintenance.yaml` | `ansible.yaml` (deploy on main push, or manual)    |
| Manual only                                        | `terraform-destroy.yaml` (`workflow_dispatch`)     |

## Common Tasks

**Add new app:** Copy existing app folder (e.g., `sonarr/`), update names, add to `Kubernetes/apps/kustomization.yaml`

**Add new secret:** Create ExternalSecret referencing Bitwarden key, add key to Bitwarden Secrets Manager

**Expose service publicly:** Use `public-chain` or `streaming-chain` middleware, ensure domain in Cloudflare

**Expose service privately:** Use `private-chain` middleware (Tailscale-only access)

## Safety Rules

- **NEVER recreate/delete+recreate Kubernetes resources managed by ArgoCD** — this causes data loss (PVCs get deleted, secrets lost). Always patch or edit in-place.
- **NEVER delete PVCs, StatefulSets, or Deployments** to "fix" them. Fix the manifest and let ArgoCD reconcile.
- **Always push changes to test them** — ArgoCD auto-syncs from git. Don't leave changes local-only.
- **Before pushing**: Verify changes are non-destructive (no resource deletions, no name changes that would cause recreation).
- **Critical incident history**: ArgoCD app-of-apps was once recreated by changing resource names/structure, causing all data loss. NEVER do this.

## Workflow

- **Kubernetes changes**: Use `git push` + ArgoCD resync. ArgoCD is the GitOps source of truth.
- **Temporary cluster fixes are allowed** for debugging or to unblock a workload, but only if you first confirm ArgoCD will not revert them (e.g. the resource is not in Git, auto-sync is paused, or the field is not managed). Final, durable changes must be committed to Git and verified as Synced in ArgoCD before considering the job done.
- Apply script (`./scripts/apply-kubernetes.sh`) is for bootstrapping only, not routine changes.
- **Before running `terraform` in `Terraform/apps/`**: Always ensure `./scripts/port-forward-apps.sh` is running first (check with `ss -tlnp | grep -E "8989|7878|9696|8096|3000|9000"`).
