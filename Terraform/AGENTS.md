# Terraform Conventions

## Directory Structure

- `Terraform/` — Main infrastructure: cluster provisioning, cloud resources, DNS, secrets, CI integration
- `Terraform/apps/` — App-level configuration via dedicated providers (Sonarr, Radarr, AdGuard, Authentik)

Each directory is a separate Terraform root with its own backend and state.

## State Backends

- **Main** (`Terraform/`): OCI Object Storage — `backend "oci"` with key `interstellar/terraform.tfstate`
- **Apps** (`Terraform/apps/`): Kubernetes secret — `backend "kubernetes"` in `default` namespace

Bootstrap requires two-phase init: `terraform init -backend=false && terraform apply`, then `terraform init -migrate-state`.

## Secrets Management

Three patterns, all using `bitwarden-secrets_secret`:

### Generated secrets (Terraform creates and owns the value)

```hcl
resource "random_password" "example" {
  length  = 32
  special = false
}

resource "bitwarden-secrets_secret" "example" {
  key        = "example-password"
  value      = random_password.example.result
  project_id = local.bitwarden_generated_project_id
  note       = "Description. Managed by Terraform."
}
```

### App-extracted secrets (pod sidecar updates after initial placeholder)

```hcl
resource "bitwarden-secrets_secret" "sonarr_api_key" {
  key        = "sonarr-api-key"
  value      = "placeholder-will-be-set-by-app"
  project_id = local.bitwarden_generated_project_id
  note       = "Sonarr API key. Initially placeholder, updated by api-extractor sidecar. Managed by Terraform."

  lifecycle {
    ignore_changes = [value]
  }
}
```

### User-managed secrets (must be filled manually in Bitwarden)

```hcl
resource "bitwarden-secrets_secret" "example_manual" {
  key        = "example-manual-secret"
  value      = ""
  project_id = local.bitwarden_project_id    # Note: manual project, not generated
  note       = "Fill manually in Bitwarden. Managed by Terraform."

  lifecycle {
    ignore_changes = [value]
    postcondition {
      condition     = self.value != ""
      error_message = "Secret 'example-manual-secret' is empty. Please fill it in Bitwarden."
    }
  }
}
```

**Key distinctions:**

- `local.bitwarden_generated_project_id` → auto-generated secrets (Terraform or app-managed)
- `local.bitwarden_project_id` → user-managed secrets (manual entry required)
- `lifecycle { ignore_changes = [value] }` on anything where the value changes outside Terraform
- `postcondition` on user-managed secrets to fail early if empty

## Naming

- **Resources**: `kebab-case` (`interstellar-vcn`, `oracle-proxy`)
- **Locals**: `snake_case` (`talos_node_names`, `bitwarden_generated_project_id`)
- **Bitwarden keys**: `kebab-case` (`sonarr-api-key`, `crowdsec-api-key`)
- **Variables**: `snake_case` with descriptive `description` field

## Variables

### Main (`variables.tf`)

Infrastructure config: Proxmox endpoint, cluster VIP, node map (vmid/vcpus/memory/gpu), Talos extensions, domain, Bitwarden token.

### Apps (`apps/variables.tf`)

Two variable categories kept separate:

- **Cluster-internal URLs**: K8s service DNS names (`http://sonarr.media.svc.cluster.local:8989`) — used in app-to-app config
- **Provider URLs**: How Terraform reaches apps (`http://localhost:8989` via port-forward, overridden with `TF_VAR_*` in CI) — used in provider blocks

## Provider Authentication

Providers authenticate via Bitwarden secrets read at plan time:

```hcl
provider "sonarr" {
  url     = var.sonarr_provider_url
  api_key = data.bitwarden-secrets_secret.sonarr_api_key.value
}
```

The `data.bitwarden-secrets_secret` data sources read live values from Bitwarden — these are the API keys that pod sidecars extract and update.

## Resource Patterns

### Conditional resources (dynamic blocks)

```hcl
dynamic "ingress_security_rules" {
  for_each = var.proxy_public_access ? [1] : []
  content { ... }
}
```

### For-each over node map

```hcl
resource "proxmox_virtual_environment_vm" "talos" {
  for_each = var.nodes
  name     = each.key
  ...
}
```

### OIDC app registration (Authentik → Bitwarden → ExternalSecret → Pod)

```hcl
resource "authentik_provider_oauth2" "app" {
  name      = "App"
  client_id = "app"
  ...
}

resource "bitwarden-secrets_secret" "app_client_id" {
  key        = "authentik-app-client-id"
  value      = authentik_provider_oauth2.app.client_id
  project_id = local.bitwarden_generated_project_id
}
```

## Lint & CI

```bash
scripts/lint-terraform.sh    # tflint --init && tflint
cd Terraform && terraform plan
```

CI runs `terraform plan` on PRs touching `Terraform/` (not `Terraform/apps/`). Apps Terraform has a separate workflow triggered by `Terraform/apps/**`.

## Key Gotchas

- **`talosctl upgrade` transiently crash-loops kubelet on every node carrying `shutdownGracePeriodByPodPriority`**: on first boot Talos starts kubelet with stock defaults (`shutdownGracePeriod: 30s`) before the machine config converges, so kubelet fails validation with `Cannot specify both shutdownGracePeriodByPodPriority and shutdownGracePeriod at the same time` and restarts for ~30s until the config lands. This looks identical to the incident that downed the cluster but is self-healing — wait for `Aborting restart sequence` followed by a clean start, and only intervene if the node does not reach Ready.
- **`longhorn-cache` volumes permanently block `kubectl drain` under the `block-if-contains-last-replica` node-drain-policy**: the StorageClass is `numberOfReplicas: 1` by design, so whichever node holds one always holds "the last replica" and drain hangs until timeout (seen on talos-1 with `utilities/immich-ml-cache`). Cordoning also strands the workload, since the single replica cannot follow it. Fix: confirm the volume is detached with a stopped replica, temporarily `kubectl -n longhorn-system patch settings.longhorn.io node-drain-policy --type=merge -p '{"value":"always-allow"}'`, drain and upgrade, then restore `block-if-contains-last-replica`. The setting is not in Git, so ArgoCD will not revert it either way.
- **Terraform cannot change `cluster.network.*`; only `talosctl upgrade-k8s` re-applies bootstrap manifests**: after `terraform apply` set `cni.flannel.kubeNetworkPoliciesEnabled`, all three nodes regenerated the `05-flannel` Manifest resource to version 2, but `k8s.ManifestApplyController` ran for under 20ms with no errors and the live DaemonSet stayed at generation 1. Talos updates its internal manifest resource on config change and pushes it to the API server only during `upgrade-k8s`. Any CNI/CoreDNS/kube-proxy manifest change made through Terraform is silently inert until `talosctl upgrade-k8s --to <k8s-version>` runs.
- **Provider URLs differ between local and CI**: Locally use `localhost` via `scripts/port-forward-apps.sh`; CI overrides with `TF_VAR_*` pointing to Tailscale MagicDNS names.
- **AdGuard `adguard_config` must keep a syntactically valid disabled DHCP block**: the provider replays DHCP settings during DNS updates, and AdGuard rejects blank DHCPv4 IP fields even when DHCP is disabled.
- **Talos devices are tagged `tag:node`; `tag:cluster` is retired**: `talos.tf` advertises `--advertise-tags=tag:node` and no live device carries `tag:cluster`, so ACL rules naming it are dead weight rather than a safety net. `Ansible/inventory_tailscale.py` still maps it as a legacy fallback.
- **Talos Longhorn data disk selection should use the visible `/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1` symlink**: Proxmox has `serial=lh-data-*`, but Talos 1.13 does not expose it in the Disks API or sysfs for these `scsi-hd` VM disks.
- **Talos and Kubernetes provider endpoints default to LAN IPs (nodes) and the cluster VIP (API); CI must override them**: GitHub runners join the tailnet but nothing advertises `192.168.1.0/24` there, so the LAN defaults are unreachable from CI. `terraform.yaml` resolves live Tailscale IPs via `scripts/resolve-talos-api-endpoint.sh` and passes `TF_VAR_talos_api_endpoints` (map node→IP) and `TF_VAR_kubernetes_api_host`. Keep `data.talos_client_configuration` on MagicDNS hostnames — that is the user-facing talosconfig, used from anywhere on the tailnet.
- **In CI, prefer `talos-2` over `talos-1` when picking a Kubernetes API node**: `talos-1` is the GPU node and is recreated more often during hardware/GPU experiments; its Tailscale identity does not survive reinstallation. `resolve-talos-api-endpoint.sh` probes for a reachable node; do not hardcode `talos-1`.
- **`proxmox_download_file` Talos ISOs must track `talos_version`**: `ignore_changes = [url, file_name]` hid stale v1.12.4 ISOs after upgrading to v1.13.4 and let CI plans miss drift. Remove the ignore and set `overwrite = true` so ISOs stay in sync and the Talos version bump is honest.
- **Cloudflare provider uses conditional token**: Falls back to dummy token `"0000..."` when secret is empty (bootstrap phase). Same pattern for Tailscale provider.
- **Tailscale tailnet auth key values are create-time only**: Bitwarden secrets that store `tailscale_tailnet_key.*.key` must ignore later `value` drift, or refresh will plan to overwrite the stored auth key with `null`.
- **GitHub Actions runners should connect to Tailscale with `--accept-dns=false`**: tailnet DNS is intentionally AdGuard-only, so accepting it during CI can break public DNS resolution before Terraform has a chance to apply ACL/DNS fixes.
- **Root Terraform CI resolves Proxmox through Tailscale status**: with tailnet DNS disabled in CI, workflow steps must set `TF_VAR_proxmox_endpoint` to the unique `carbon` Tailscale IPv4 address before running plan/apply.
- **OCI auth via environment**: Uses `OCI_CONFIG` and `OCI_PRIVATE_KEY` env vars sourced from Bitwarden by `scripts/setup-env.sh`, not `~/.oci/config` file.
- **GitHub secrets sync**: BWS secret IDs (not values) are stored as GitHub Actions variables; the CI runner resolves them at runtime via `bws secret get`.
