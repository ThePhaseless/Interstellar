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

## Kubernetes Conventions

### App structure

Each app lives in `Kubernetes/apps/<name>/` with `kustomization.yaml`, `deployment.yaml`, `service.yaml`, and optionally `ingress.yaml`, `pvc.yaml`, `externalsecret.yaml`.

- **Namespaces**: `media`, `utilities`, `home` — declared in `Kubernetes/apps/namespaces.yaml`
- **Labels**: Always include `app: <name>` via kustomization `labels` block
- **ConfigMaps**: Use `configMapGenerator` with `disableNameSuffixHash: true`
- **New apps**: Add the directory to `Kubernetes/apps/kustomization.yaml` resources list; ArgoCD auto-syncs

### Ingress

Uses Traefik `IngressRoute` CRD (`traefik.io/v1alpha1`), not standard `Ingress`. Pattern:

- Entrypoint: `websecure`, certResolver: `letsencrypt`
- Domain: `*.nerine.dev`
- Middleware chain: reference `public-chain@kubernetescrd` from `traefik` namespace for public routes
- Global middlewares live in `traefik` namespace; app-specific ones in the app's namespace

### Secrets

- `ClusterSecretStore` names: `bitwarden-store` (manual) or `bitwarden-store-generated` (Terraform-created)
- 1-hour refresh interval on ExternalSecrets
- API key extraction: sidecar containers read app config → update Bitwarden → Terraform reads back

### Storage

- NFS v4.2 PersistentVolumes defined in `Kubernetes/apps/common/media-pv.yaml`
- Mount options: `nfsvers=4.2,noatime`, reclaim policy: `Retain`, access mode: `ReadWriteMany`
- Longhorn CSI for non-NFS persistent storage

### Deployments

- `Recreate` strategy for stateful/GPU apps (Jellyfin, Immich, AdGuard)
- Annotation `reloader.stakater.com/auto: "true"` for config-change restarts
- GPU resources: `gpu.intel.com/xe: "1"` (Intel Arc, only on GPU-labeled node)

## Terraform Conventions

- **Naming**: Resources use `kebab-case`, locals use `snake_case`
- **Secrets**: `random_password` → `bitwarden-secrets_secret` with `lifecycle { ignore_changes = [value] }`
- **User secrets**: Validated with `postcondition` (fail if empty placeholder)
- **State**: Main → OCI Object Storage; Apps → Kubernetes secret backend
- **Variables**: Cluster config in `variables.tf`, app endpoints in `Terraform/apps/variables.tf`

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

- **TLS terminates at Traefik**, not at the app or HAProxy. Apps serve plain HTTP internally. ArgoCD runs with `--insecure`.
- **Tailscale DNS split-horizon**: Public DNS (Cloudflare) only has Oracle VPS IP. Tailscale clients use AdGuard as their DNS (configured in `tailscale.tf`), which rewrites `*.nerine.dev` to Traefik's Tailscale IP via client-based rules in `adguard.tf`.
- **Kubernetes pods do not automatically get the same split-horizon behavior as Tailscale clients**: In-cluster server-side calls to `*.nerine.dev` still follow normal cluster DNS unless CoreDNS is explicitly taught otherwise, so OIDC discovery from pods can hit the public Oracle IP and fail even when browser-based access works.
- **For a single workload that must call a public `*.nerine.dev` hostname from inside the cluster, prefer pod-level `hostAliases` to Traefik's declarative MetalLB IP over a cluster-wide CoreDNS override**: this fixes split-horizon only where needed and keeps global DNS untouched.
- **Tailscale exit nodes on Proxmox need kernel forwarding enabled**: Advertising `0.0.0.0/0` and `::/0` is not enough; `net.ipv4.ip_forward=1` and `net.ipv6.conf.all.forwarding=1` must be set or clients lose internet when selecting the exit node.
- **Sonarr/Radarr external auth**: Init containers write `config.xml` with `<AuthenticationMethod>External</AuthenticationMethod>` — Traefik forward-auth injects `Remote-User`.
- **Longhorn can keep a volume `attached`/`healthy` while the node mount is effectively read-only**: If apps start reporting `Read-only file system`, check the node's `/proc/mounts` for `emergency_ro` on the PVC before adding scheduling workarounds; this needs volume/filesystem repair or remount, not pod rescheduling.
- **For Longhorn `emergency_ro` incidents, snapshot first and try a clean detach/reattach before fsck or manifest changes**: Creating manual Longhorn snapshots, scaling the owning workload to `0` until the volume detaches, then scaling it back up restored the mounts to `rw` in this cluster without recreating any resources or rolling data back.
- **Talos control-plane etcd lives under `/var/lib/etcd` inside `EPHEMERAL` on these nodes, not a dedicated `ETCD` partition**: `talosctl reset --system-labels-to-wipe ETCD` fails here; rebuilding a removed etcd member needs a broader maintenance plan than a partition-only wipe.
- **NFS server IP**: Injected via ConfigMap replacement in root `Kubernetes/kustomization.yaml`, not hardcoded.
- **Middleware namespaces matter**: When referencing a middleware from another namespace, include `namespace: <ns>` in the IngressRoute.
- **Terraform CI auto-applies on main branch**: Apply runs on any `main` branch event (push or workflow_dispatch) where the plan detects changes. Drift from manual recovery (e.g., reinstalled GPU node) can make the plan destructive on the next push; run `terraform plan` locally and reconcile state before pushing after any out-of-band node rebuild.
- **Mise only auto-loads static repo env**: `.env` and the uv-managed `.venv` come from `.mise.toml`, but Bitwarden/Tailscale exports still require `source scripts/setup-env.sh` in the shell that will run Terraform or Ansible commands.
- **Main Terraform CI uses a GitHub App token for API access**: `terraform.yaml` uses `actions/create-github-app-token@v3` to generate a token with `repo` scope for Terraform's `github_actions_variable`/`github_actions_secret` data sources. The default `GITHUB_TOKEN` with `permissions: write-all` is **insufficient** for reading repository variables and secrets via the API. The GH App ID and private key are stored in Bitwarden as `GH_APP_ID` and `GH_APP_PRIVATE_KEY`.
- **Longhorn volumes with `recurring-job-group.longhorn.io/default: enabled` auto-delete user-created snapshots**: The Longhorn admission webhook re-adds this label if removed, so snapshots created via `kubectl apply` are deleted within seconds. For migrations requiring persistent snapshots, use direct data copy via a temporary Job (mount old PVC read-only, new PVC read-write, `cp -a`) instead of the snapshot/restore flow.
- **Borg repo path migration (backups/immich → backups/interstellar)**: After merging the backup refactor, manually SSH to the storage box and run `mv backups/immich backups/interstellar` BEFORE running `terraform apply`. The Terraform change updates the Bitwarden secret, so the mv must happen first or backups will fail until the directory exists at the new path. All existing archives move with the directory — borg repos are self-contained.
- **Intel Arc GPU runtime PM requires DMC firmware**: The Talos `xe` extension historically omitted `i915/bmg_dmc.bin`, so `xe` hard-disabled runtime PM and the GPU sat at ~9W idle forever. This is a fixable extension bug, not a hardware limit. Fix: `siderolabs/i915` extension is added to GPU nodes (ships `i915/` firmware) — pending upstream PR to `siderolabs/extensions drm/xe/pkg.yaml`. Do **not** re-add GPU metric exporters even with the fix — periodic sysfs reads from `/sys/class/drm/card0/device/tile0/gt*/freq0/cur_freq` or `throttle/reason_*` still wake the GT out of G2 and cost ~7-8W.
- **Intel Arc GPU on QEMU virtual PCIe bridge cannot recover from any runtime PM state**: Both D3cold→D0 and D3hot→D0 transitions fail silently (no dmesg errors) on the Proxmox QEMU `1b36:000c` GEN1 x1 bridge. The GPU wedges until the next reboot. Fix: disable all runtime PM for the GPU via `power/control=on`, enforced by a privileged init container in the `gpu-pm-fix` DaemonSet (`Kubernetes/bootstrap/intel-gpu-operator/gpu-pm-fix.yaml`). The `machine.sysfs` controller handles `d3cold_allowed=0` but cannot set `power/control`. The intel-device-plugins operator reverts direct edits to `intel-gpu-plugin` DaemonSet, so `gpu-pm-fix` is a separate DaemonSet the operator doesn't manage.
- **Longhorn PV `nodeAffinity` is immutable**: When a workload moves to a node added after the volume was created, `dataLocality: best-effort` alone cannot overcome stale node affinity. The fix is to add a replica on the new node, detach the volume, delete the PV (after setting `reclaimPolicy: Retain`), then use Longhorn's `pvCreate` action to recreate it so the workload can schedule.
- **`hd-idle -c scsi` never spins down SATA drives** — must use `-c ata` for SATA, `-c scsi` for SAS. The original Phase 1 config used `-c scsi` on SATA HDDs, so disks sat at `IDLE_A/B` (heads parked, platters spinning) forever, never reaching `STANDBY`.
- **ZFS `atime=on` prevents HDD spindown** — every read writes an atime update to all vdevs in the pool. Set `atime=off` (or `relatime=on`) on any pool where spindown matters. This is the single biggest free lever for ZFS-on-HDD power, and it's a default-`on` footgun.
- **ZFS `zfs_txg_timeout=5` (default) prevents HDD spindown** — transaction group commits every 5s write metadata to all vdevs, keeping platters spinning. Bump to 30s via `/etc/modprobe.d/zfs.conf` to allow spindown between commits. Up to 30s of writes at risk on crash; ZFS is crash-consistent (no corruption, just replay).
- **The `1a86:7523` CH340 serial converter is the Home Assistant Zigbee coordinator** — it is passed through to the HA VM via the Proxmox `Zigbee` USB mapping (`usb0`). Do **not** unbind it in a power-optimization udev rule; doing so breaks Zigbee and requires cycling USB bus 1 (or rebooting `carbon`) to recover.
- **Talos `exec format error` with a 0-byte binary is usually corrupted containerd overlay snapshots, not wrong CPU arch**: On a fresh node, CRI can mount `/jellyfin/jellyfin` at size 0 while `talosctl debug` (inmem namespace) shows the correct binary. `talosctl image remove` + re-pull may not fix it if the overlay snapshot metadata is stuck. A targeted `talosctl reset` often leaves the disk in a half-wiped state; the reliable recovery was to stop the VM, destroy and recreate the system-disk ZVOL, boot the Talos GPU ISO, and `apply-config --insecure` again. Do not delete `io.containerd.snapshotter.v1.overlayfs` while kubelet is running — that breaks etcd/kubelet too.

### Terraform App Configuration (`Terraform/apps/`)

This sub-project uses **Terraform** to configure Sonarr, Radarr, Prowlarr, and AdGuard Home via their Terraform providers. State is stored in a Kubernetes secret (backend `kubernetes`, secret suffix `servarr`).

**Prerequisites:**

- Terraform (`terraform`) installed (>= 1.14.4)
- `KUBE_CONFIG_PATH` set (e.g. `~/.kube/config`) — required for the kubernetes backend
- Repo trusted and toolchain installed: `mise trust && mise install && mise run install`
- Bitwarden-backed environment sourced in the current shell: `source scripts/setup-env.sh`

**Running locally** (services are accessed via `kubectl port-forward`):

```bash
# 1. Export kubeconfig path for the kubernetes backend
export KUBE_CONFIG_PATH=~/.kube/config

# 2. Start port-forwards (runs in background with auto-reconnect)
./scripts/port-forward-apps.sh &

# 3. Init, plan, and apply (defaults point to localhost)
cd Terraform/apps
terraform init
terraform plan
terraform apply
```

Provider URL defaults use `localhost` (matching the port-forward script). In CI, override with `TF_VAR_*` env vars pointing to Tailscale MagicDNS names.

**Importing existing resources** (to avoid duplicates on first run):

```bash
terraform import sonarr_download_client.qbittorrent 1
terraform import radarr_download_client.qbittorrent 1
terraform import prowlarr_application.sonarr <ID>
terraform import prowlarr_application.radarr <ID>
```

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
