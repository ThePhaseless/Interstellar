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
- **Tailscale exit nodes on Proxmox need kernel forwarding enabled**: Advertising `0.0.0.0/0` and `::/0` is not enough; `net.ipv4.ip_forward=1` and `net.ipv6.conf.all.forwarding=1` must be set or clients lose internet when selecting the exit node.
- **Sonarr/Radarr external auth**: Init containers write `config.xml` with `<AuthenticationMethod>External</AuthenticationMethod>` — Traefik forward-auth injects `Remote-User`.
- **NFS server IP**: Injected via ConfigMap replacement in root `Kubernetes/kustomization.yaml`, not hardcoded.
- **Middleware namespaces matter**: When referencing a middleware from another namespace, include `namespace: <ns>` in the IngressRoute.
- **Terraform CI auto-applies on main pushes**: Routine Terraform runs rely on backend state locks with `-lock-timeout` rather than manual approval gates; Ansible deploys use non-canceling job-level concurrency.
- **Mise only auto-loads static repo env**: `.env` and the uv-managed `.venv` come from `.mise.toml`, but Bitwarden/Tailscale exports still require `source scripts/setup-env.sh` in the shell that will run Terraform or Ansible commands.

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
- Apply script (`./scripts/apply-kubernetes.sh`) is for bootstrapping only, not routine changes.
- **Before running `terraform` in `Terraform/apps/`**: Always ensure `./scripts/port-forward-apps.sh` is running first (check with `ss -tlnp | grep -E "8989|7878|9696|3000|9000"`).
