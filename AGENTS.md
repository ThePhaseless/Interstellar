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

- **Orphaned pre-patch resources block ArgoCD sync via the app-of-apps self-health hook**: the CrowdSec `acquis-configmap` created in the `argocd` namespace before the namespace patches were added stayed tracked-but-extra (`OutOfSync`). Because the custom health script flags any non-Synced resource as Degraded, the sync's own health hook kept failing, which also blocked the prune that would have removed the orphan — a self-perpetuating loop. Fix: delete the orphan (`kubectl -n argocd delete cm acquis-configmap`) — ArgoCD's prune can't run until a sync completes, so stale extra resources sometimes need one manual deletion.
- **CrowdSec Helm chart regenerates `crowdsec-lapi-secrets` with random values on every render** (`randAlphaNum` without a stable lookup): the LAPI secret data and the Deployment's `checksum/lapi-secret` pod annotation differ every render, so ArgoCD never converges on that Secret/Deployment and the app stays `OutOfSync`/`Degraded`, which also fails sync health hooks. Fix: set `secrets.externalSecret.name: crowdsec-lapi-secrets` in the chart values so the chart skips generating the secret, and provide the Secret via an ExternalSecret (`crowdsec-lapi-secrets`, keys `csLapiSecret` + `registrationToken`) backed by Bitwarden `bitwarden-store-generated`. Seed the Bitwarden values from the current live secret first (`kubectl -n crowdsec get secret crowdsec-lapi-secrets -o jsonpath='{.data}' | base64 -d`) so the running LAPI/agents don't rotate.
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
- **Intel Arc (Battlemage `8086:e20b`) periodic fan ramps at idle are caused by outdated GPU-firmware fan curves — fixed via LVFS fwupd update**: The `xe` driver exposes only `fan1_input` (read-only RPM) via hwmon — no `pwm1`/`pwm1_enable`, so Linux cannot set a fan curve; the card runs its own firmware curve. Intel publishes official firmware on [LVFS](https://fwupd.org/lvfs/search?value=B580); the `21.1174` changelog explicitly lists *"Bug Fix: Erratic fan speeds"* and `21.1182` adds *"Improved lower power state entry when display is disconnected."* The card shipped with `BMG__21.1137` (GA) and Intel does NOT auto-update card firmware on Linux — it must be flashed manually. **Fix applied 2026-07-27**: flashed talos-1's B580 `21.1137 → 21.1182` via `fwupdtool update` from official LVFS (also bumped OptionROM Code to `23.1066.0.0`), then rebooted the VM. **To update again**: run a privileged `fedora:42` pod on talos-1 mounting `/dev/dri`, `/dev/mei0`, `/sys`; `dnf install -y fwupd`; `fwupdtool refresh`; the GPU MEI device fails to probe (`fw_status 00000000 is invalid`) when the GPU is in runtime-suspend, so keep it in D0 with a background `ffmpeg -hwaccel vaapi` (e.g. `testsrc` → `h264_vaapi -f null`) in the jellyfin pod during the probe/flash; then `fwupdtool update <GUID>` where GUID is `c3808bdf-c31b-5c03-905f-6f223848cae0` (the `PCI\VEN_8086&DEV_E20B&PART_FWCODE` GUID). Verify with `fwupdtool get-devices` (shows `Current version`) or igsc (`igsc fw version --device /dev/mei0`). Device flags include `Needs shutdown after installation` — a full VM reboot activates the firmware. Note: the linux-firmware blobs (`bmg_guc_70.bin`/`bmg_huc.bin`/`bmg_dmc.bin`) are separate and current via the Talos `xe` extension; `fan_control_8086_e20b_8086_1100.bin` ships in the extension but is **not loaded** by the `xe` kernel driver on 6.18 (kernel ≥7.0 wires it up via [drm-xe patchwork 168027](https://patchwork.freedesktop.org/series/168027/)). See [intel/compute-runtime#885](https://github.com/intel/compute-runtime/issues/885).
- **Longhorn PV `nodeAffinity` is immutable**: When a workload moves to a node added after the volume was created, `dataLocality: best-effort` alone cannot overcome stale node affinity. The fix is to add a replica on the new node, detach the volume, delete the PV (after setting `reclaimPolicy: Retain`), then use Longhorn's `pvCreate` action to recreate it so the workload can schedule.
- **`hd-idle -c scsi` never spins down SATA drives** — must use `-c ata` for SATA, `-c scsi` for SAS. The original Phase 1 config used `-c scsi` on SATA HDDs, so disks sat at `IDLE_A/B` (heads parked, platters spinning) forever, never reaching `STANDBY`.
- **ZFS `atime=on` prevents HDD spindown** — every read writes an atime update to all vdevs in the pool. Set `atime=off` (or `relatime=on`) on any pool where spindown matters. This is the single biggest free lever for ZFS-on-HDD power, and it's a default-`on` footgun.
- **ZFS `zfs_txg_timeout=5` (default) prevents HDD spindown** — transaction group commits every 5s write metadata to all vdevs, keeping platters spinning. Bump to 30s via `/etc/modprobe.d/zfs.conf` to allow spindown between commits. Up to 30s of writes at risk on crash; ZFS is crash-consistent (no corruption, just replay).
- **The `1a86:7523` CH340 serial converter is the Home Assistant Zigbee coordinator** — it is passed through to the HA VM via the Proxmox `Zigbee` USB mapping (`usb0`). Do **not** unbind it in a power-optimization udev rule; doing so breaks Zigbee and requires cycling USB bus 1 (or rebooting `carbon`) to recover.
- **carbon's ASMedia ASM1062 SATA controller (`26:00.0`) hosts sda+sdb — 2 of the 5 Storage pool disks**: it looks like a spare empty controller (lspci shows nothing unusual) but is not. Do **not** unbind it in a power rule; you would detach 2/5 of the RAIDZ1. Disk layout: sda/sdb on ASMedia (scsi hosts 0/1), sdc/sdd/sde on FCH `2c:00.0` (hosts 3/4/7), FCH `2b:00.0` host 2 empty. Verify with `lsblk -o HCTL` before touching any SATA controller.
- **rfkill soft-blocks do not persist across reboots on carbon (`systemd-rfkill` is inactive)** — a manual `rfkill block wifi` reverts on next boot. The durable fix is the udev unbind rules (`99-power-wifi-unbind.rules`, `99-power-usb-unbind.rules`) which fully power down the WiFi/BT combo card via PCIe runtime PM.
- **udev `RUN` substitution is `$devpath` (lowercase), not `$DEVPATH`** — uppercase is an invalid substitution and the rule is silently ignored (`udevadm verify` catches it). Also: USB interfaces carry no `idVendor`/`idProduct` attributes, so interface-level rules (btusb binds `1-4:1.0/1.1`) need `ATTRS{...}` (parent walk) and `ENV{DEVTYPE}=="usb_interface"`.
- **Talos `exec format error` with a 0-byte binary is usually corrupted containerd overlay snapshots, not wrong CPU arch**: On a fresh node, CRI can mount `/jellyfin/jellyfin` at size 0 while `talosctl debug` (inmem namespace) shows the correct binary. `talosctl image remove` + re-pull may not fix it if the overlay snapshot metadata is stuck. A targeted `talosctl reset` often leaves the disk in a half-wiped state; the reliable recovery was to stop the VM, destroy and recreate the system-disk ZVOL, boot the Talos GPU ISO, and `apply-config --insecure` again. Do not delete `io.containerd.snapshotter.v1.overlayfs` while kubelet is running — that breaks etcd/kubelet too.
- **NFS server must start before VMs and stop after them**: VMs mount NFS shares, so NFS must be available before `pve-guests.service` starts. Configured via systemd override at `/etc/systemd/system/nfs-server.service.d/override.conf` with `Before=pve-guests.service`. Systemd automatically handles reverse ordering for shutdown (VMs stop first, then NFS). Without this, VMs fail to mount NFS on boot or lose storage during shutdown.
- **Always read kernel logs via Loki (`{app="talos-kmsg-shipper"}`) before guessing at cluster root causes**: the cluster ships `/dev/kmsg` to Loki via a DaemonSet. `scripts/wait-for-gpu-crash.sh` polls for and captures the next Flannel-restart/GPU-pod-NotReady occurrence with full diagnostics. The GPU node (talos-1) is memory-constrained; Bitwarden SDK refresh storms at the top of every hour can OOM-kill Flannel and cascade into pod evictions. Workarounds: keep talos-1 ≥16 GiB RAM, pin *arr apps off the GPU node, stagger `ExternalSecret.refreshInterval` with jitter.
- **`/etc/modprobe.d/zfs.conf` changes on Proxmox require `update-initramfs -u` to survive reboot**: The ZFS module is loaded from the initramfs, and its modprobe configuration is copied into the initramfs at build time. A stale initramfs will load the old `zfs_arc_max`/`zfs_txg_timeout` values even when `/etc/modprobe.d/zfs.conf` on disk is correct. Follow any ZFS module-option change with `update-initramfs -u` (and `proxmox-boot-tool refresh`) before rebooting.
- **Grafana notification templates use a fork of alertmanager with reduced DefaultFuncs**: The fork (grafana/prometheus-alertmanager v0.25.1-based, pinned by github.com/grafana/alerting) removed humanizeDuration, humanize, since, toJson, dict, list, safeUrl, urlUnescape from upstream's DefaultFuncs. Available notification-template funcs: date, join, match, reReplaceAll, safeHtml, stringSlice, title, toLower, toUpper, trimSpace, tz (plus Go builtins like printf, len, eq, index, range). Using a missing func crashes Grafana on startup with "text templates: [alerting.notifications.templates.invalidFormat]" and the inner parse error is swallowed.
- **Use `pveupdate` and `pveupgrade` (not `apt`) to update Proxmox packages**: `pveupgrade` handles Proxmox's package dependencies, kernel updates, and bootloader config correctly. `apt upgrade` can leave kernel packages held back and doesn't trigger the Proxmox bootloader refresh. The Ansible task `Ansible/tasks/update-proxmox.yaml` already uses the correct commands. `pveupgrade` does not accept `-y` — run it interactively or use `DEBIAN_FRONTEND=noninteractive pveupgrade` for automation.
- **CrowdSec `DISABLE_AGENT=true` silently skips `COLLECTIONS` env var**: The Docker entrypoint's `prepare_hub()` function returns early when `DISABLE_AGENT` is set, so collections specified via the `COLLECTIONS` env var are never installed. The LAPI-only manifest pattern (agent disabled, `COLLECTIONS` set) is a no-op — only image-baked-in collections survive. The Helm chart avoids this by running the agent as a separate DaemonSet that processes the `COLLECTIONS` env var normally.
- **CrowdSec Helm chart LAPI service is named `crowdsec-service`, not `crowdsec-lapi`**: The Traefik bouncer middleware must reference `crowdsec-service.crowdsec.svc.cluster.local:8080`. The old raw manifest named it `crowdsec-lapi`; the Helm chart renames it. ArgoCD prunes the old Service automatically.
- **CrowdSec agent tails containerd logs, not shared volumes or sidecars**: The Helm chart's agent DaemonSet reads pod logs directly from `/var/log/containers/` via `hostPath`. Acquisition is configured in `values.yaml` with `namespace`, `podName` (glob), and `program` (parser name). No Fluentbit, no shared volume, no Traefik access-log file mount needed.
- **CrowdSec chart omits `metadata.namespace` — kustomize `namespace:` transformer doesn't apply to Helm output in v5.8.1**: The chart's templates don't include `namespace:` in resource metadata (unlike the Traefik chart which uses `namespace: {{ template "traefik.namespace" . }}`). Without explicit namespace patches, ArgoCD deploys CrowdSec resources to its own `argocd` namespace. Fix: add JSON 6902 patches in `kustomization.yaml` for each resource kind (Deployment, DaemonSet, Service, PVC, ConfigMap, Secret) setting `/metadata/namespace` to `crowdsec`.
- **CrowdSec `crowdsec` namespace needs `pod-security.kubernetes.io/enforce=privileged`**: The agent DaemonSet mounts `/var/log` via `hostPath`, which violates PodSecurity `baseline:latest`. Without the privileged label on the namespace, pod creation fails with `violates PodSecurity "baseline:latest": hostPath volumes`.
- **CrowdSec bouncer key env var must be named `BOUNCER_KEY_<name>`**: The chart's `docker_start.sh` scans for env vars matching `BOUNCER_KEY_*` to auto-register bouncers. The ExternalSecret `secretKey` must be `BOUNCER_KEY_traefik` (not `bouncer-key`), otherwise the Traefik bouncer gets `403` on `/v1/decisions/stream` and never registers.
- **Tailscale k8s-operator L3 Services use DNAT and do NOT forward the real client IP** (tailscale/tailscale#11024): All Tailscale direct traffic to a `Service` annotated with `tailscale.com/expose` appears as the ts-<svc> proxy pod IP (pod CIDR `10.244.0.0/16`), not the client's `100.x.x.x` Tailscale IP. Public traffic via Oracle HAProxy is unaffected because HAProxy sends PROXY protocol v2, which Traefik trusts and uses to recover the real client IP. To exclude Tailscale direct traffic from CrowdSec bans/rate-limiting, add `10.244.0.0/16` to the bouncer's `clientTrustedIPs` (bypasses all checks including AppSec WAF) and add a CrowdSec agent `postoverflows/s01-whitelist` with `cidr:` ranges (prevents scenarios like http-dos from triggering). Note: `100.64.0.0/10` in `clientTrustedIPs` is currently a no-op since Tailscale IPs are never seen, but kept for forward-compat if Tailscale adds PROXY protocol support.
- **CrowdSec whitelist `ip:` field expects individual IPs, not CIDR ranges**: Use the `cidr:` field for ranges (matching `crowdsecurity/whitelists` format). Using `ip:` with `10.244.0.0/16` crashes the agent with `ParseAddr("10.244.0.0/16"): unexpected character (at "/16")`.
- **All ZHA Zigbee devices are Tuya and never report firmware updates available**: The network is one `TS0505B` bulb + three `TS011F` plugs (Tuya manufacturer ID 4098). The default OTA providers (zigpy-ota, ledvance, sonoff) contain zero Tuya images — the zigpy-ota stable index has no manufacturer-4098 entries — so `update.install` on any `update.*_firmware` entity returns `No update available` and `latest_version` stays `null`. Don't chase this as a bug.
- **Killing a borg client pod mid-run leaves the Hetzner repo locked until the remote `borg serve` session dies; recover with `borg break-lock`**: a `kubectl delete pod` (or container kill) during `borg create`/`check` drops the SSH connection, but the remote side can linger, and subsequent runs fail with `Failed to create/acquire the lock ... (timeout)` — including the nightly CronJobs (a missed backup). After ensuring no backup job is legitimately running (check for pods/jobs first!), clear with `borg break-lock <repo>`. Test archives created manually (prefixes like `verifytest-*`) are never pruned by the retention globs — always `borg delete` + `borg compact` them, or name them so you don't forget.
- **Borg exclude patterns are `fm:` style and cannot re-include; use `BORG_PATTERNS` for `+` rules**: `--exclude-from` (the `BORG_EXCLUDES` env) only supports excludes, and its default `fm:` style treats `*` as matching path separators — so `- external/public/*` silently excludes *everything* under `public`, and a `+` line there is ignored entirely. Re-include rules ("back up only `X/safe` under `X`") must go in `BORG_PATTERNS` (→ `--patterns-from`, `sh:` style where `*` does NOT cross `/` and `**` matches any depth), ordered first-match-wins: `+ external/public/safe`, `+ external/public/safe/**`, `- external/public/**`. Patterns match archived paths (no leading slash — target `/photos` archives as `photos/...`); verify with `borg create --dry-run --list`. `safe` did not exist on `personal-pvc` at migration time (2026-08), so `public/` was fully excluded until it's created.
- **Unauthenticated probes at `http://192.168.1.186:8123/api/*` create "Login attempt failed" persistent notifications and can ban the source IP**: HA counts every 4xx on authenticated endpoints as a failed login. Default `login_attempts_threshold: -1` disables the ban, but a configured positive threshold bans the IP with no automatic release (manual removal from `config/ip_bans.yaml` required).
- **The Oracle VPS runs Tailscale with `--accept-dns=false` by design** (commit `4ba7c50`, security: VPS uses OCI DNS, never home AdGuard; `ansible.yaml` CI also connects with `--accept-dns=false`). Consequence: MagicDNS is dead on the VPS (`100.100.100.100` does not answer), so `haproxy.cfg` **must not** resolve the Traefik backend by name — HAProxy fails at startup with `could not resolve address 'traefik.fold-hen.ts.net'` and crash-loops, taking down all public access (incident introduced by commit `4ba7c50`, 2026-07-24). The backend IP is baked in as a literal at deploy time: `Ansible/setup-oracle.yaml` resolves the `traefik` peer from `tailscale status --json` on the control node and templates `haproxy.cfg.j2`. Same read-at-apply-time drift semantics as the AdGuard rewrites in `Terraform/apps/adguard.tf`: **if the traefik tailnet device is recreated (new IP), outside access breaks until `setup-oracle.yaml` is re-run**.


### Terraform App Configuration (`Terraform/apps/`)


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