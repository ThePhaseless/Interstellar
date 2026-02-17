# Copilot Instructions for Interstellar Homelab

## Development

Before running first script in a new shell in this repository activate the virtual environment and source the environment setup script so all required variables are loaded. Run this only once per Not before every command execution!

```bash
source .venv/bin/activate
source scripts/setup-env.sh
```

For Kubernetes deployments, use standalone `kustomize` (not `kubectl apply -k`). This repository uses Helm-enabled Kustomize builds.

## Architecture Overview

This is a GitOps-managed Kubernetes homelab on TalosOS (Proxmox VMs) with public access via Oracle VPS → Tailscale → Traefik. ArgoCD deploys everything from Git.

**Key flow:** Internet → HAProxy (Oracle) → Tailscale mesh → Traefik → Services

## Directory Structure

- `Kubernetes/bootstrap/` - Core infrastructure (ArgoCD, MetalLB, LongHorn, Traefik, External Secrets)
- `Kubernetes/apps/` - Application workloads organized by service name
- `Kubernetes/apps/common/` - Shared resources: RBAC, PVCs, ExternalSecrets, configurator scripts
- `Terraform/` - Infrastructure provisioning (Proxmox VMs, Oracle VPS, Talos cluster, Cloudflare DNS)
- `Ansible/` - Host configuration (Proxmox routing/NAT + NFS host prep, Oracle HAProxy)
- `Tailscale/policy.hujson` - ACL policy (HJSON format with comments)

## Kubernetes Conventions

### Kustomize Structure

All manifests use Kustomize. Each app folder contains: `kustomization.yaml`, `deployment.yaml`, `service.yaml`, `ingress.yaml`, `pvc.yaml`.

### Namespaces

- `media` - All \*arr apps, Jellyfin, qBittorrent
- `traefik` - Ingress controller + middlewares
- `external-secrets` - Bitwarden integration
- Bootstrap components get their own namespaces

### Ingress Pattern

Use Traefik `IngressRoute` (not standard Ingress). Apply middleware chains:

- `public-chain` - Public services (security headers + CrowdSec + rate limit)
- `streaming-chain` - Media streaming (relaxed rate limits)
- `private-chain` - Tailscale-only access (`tailscale-only` middleware)

Example:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
spec:
  routes:
    - middlewares:
        - name: private-chain
          namespace: traefik
```

### Secrets Management

Never hardcode secrets. Use ExternalSecrets with `ClusterSecretStore: bitwarden-store`:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
spec:
  secretStoreRef:
    name: bitwarden-store
    kind: ClusterSecretStore
  data:
    - secretKey: api-token
      remoteRef:
        key: my-secret-name # Bitwarden secret name
```

### GPU Workloads

GPU-bound services (Jellyfin, Immich ML, Copyparty) must use:

```yaml
nodeSelector:
  kubernetes.io/hostname: talos-1
resources:
  requests:
    gpu.intel.com/i915: "1"
  limits:
    gpu.intel.com/i915: "1"
```

### \*arr Apps Pattern

Media apps use init containers + sidecars for auto-configuration:

1. `api-extractor` init container extracts API key from config.xml
2. `configurator` sidecar configures download clients via API
3. Scripts in `Kubernetes/apps/common/scripts/`

## Linting & Validation

```bash
# Kubernetes manifests
./scripts/lint-kubernetes.sh

# Ansible playbooks
./scripts/lint-ansible.sh

# Terraform
./scripts/lint-terraform.sh
```

Disabled kube-linter checks (see `.kube-linter.yaml`):

- `no-read-only-root-fs` - Third-party images
- `run-as-non-root` - Many apps require root
- `unset-cpu-requirements` / `unset-memory-requirements` - Init containers

## Terraform Patterns

- State stored in OCI Object Storage
- Secrets fetched from Bitwarden via `bws` CLI in CI
- Talos machine configs use `config_patches` for customization
- See `Terraform/talos.tf` for cluster configuration pattern

## CI/CD Workflows

| Path changes    | Workflow triggered                            |
| --------------- | --------------------------------------------- |
| `Kubernetes/**` | `kubernetes-lint.yaml`                        |
| `Terraform/**`  | `terraform.yaml` (plan on PR, apply on merge) |
| `Ansible/**`    | `ansible.yaml`                                |
| `Tailscale/**`  | `tailscale-acl.yaml`                          |

## Common Tasks

**Add new app:** Copy existing app folder (e.g., `sonarr/`), update names, add to `Kubernetes/apps/kustomization.yaml`

**Add new secret:** Create ExternalSecret referencing Bitwarden key, add key to Bitwarden Secrets Manager

**Expose service publicly:** Use `public-chain` or `streaming-chain` middleware, ensure domain in Cloudflare

**Expose service privately:** Use `private-chain` middleware (Tailscale-only access)
