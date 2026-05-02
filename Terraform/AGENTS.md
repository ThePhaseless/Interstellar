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

- **Provider URLs differ between local and CI**: Locally use `localhost` via `scripts/port-forward-apps.sh`; CI overrides with `TF_VAR_*` pointing to Tailscale MagicDNS names.
- **Talos devices are currently tagged `tag:cluster` in Tailscale**: CI access rules must allow both `tag:cluster` and `tag:node`, or GitHub runners will join the tailnet successfully but still be unable to resolve or reach Talos nodes.
- **Talos provider endpoints should stay on MagicDNS hostnames after bootstrap**: `talos_machine_configuration_apply`, `talos_machine_bootstrap`, and `talos_cluster_kubeconfig` must use Tailscale-reachable hostnames in CI; only first bootstrap before Tailscale comes up should override `talos_api_endpoints` back to LAN IPs.
- **Bitwarden provider is pre-release**: `bitwarden-secrets` version `0.5.4-pre` — pin exactly, don't use `>=`.
- **Cloudflare provider uses conditional token**: Falls back to dummy token `"0000..."` when secret is empty (bootstrap phase). Same pattern for Tailscale provider.
- **OCI auth via environment**: Uses `OCI_CONFIG` and `OCI_PRIVATE_KEY` env vars sourced from Bitwarden by `scripts/setup-env.sh`, not `~/.oci/config` file.
- **GitHub secrets sync**: BWS secret IDs (not values) are stored as GitHub Actions variables; the CI runner resolves them at runtime via `bws secret get`.
