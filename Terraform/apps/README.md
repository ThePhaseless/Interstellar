# Terraform App Configuration

This folder manages app configuration via Terraform providers. State is stored in a
Kubernetes secret using the kubernetes backend.

## What This Manages

- Sonarr and Radarr qBittorrent download clients
- Prowlarr applications for Sonarr and Radarr
- AdGuard Home DNS rewrites and filter lists
- Jellyfin provider integration and import workflow

## Backend

The backend uses the default namespace and a secret suffix of "servarr".
Adjust backend settings in [Terraform/apps/backend.tf](Terraform/apps/backend.tf)
if you want a different namespace or secret name.

## Prerequisites

Local provider defaults point at `localhost`, so start the app port-forwards before running Terraform. If you prefer direct Tailscale or MagicDNS endpoints, override the `TF_VAR_*_provider_url` variables.

Project environment setup:

- `mise` installed and activated in your shell
- From the repo root: `mise trust && mise install && mise run install`
- Bitwarden-backed environment loaded in the current shell: `source scripts/setup-env.sh`
- `KUBE_CONFIG_PATH` exported (for example `~/.kube/config`)
- Go installed locally if you want to run the Jellyfin import helper

Required Bitwarden secrets:

- `sonarr-api-key`, `radarr-api-key`, `prowlarr-api-key` — \*arr API keys
- `jellyfin-admin-password` — Jellyfin bootstrap/admin password
- `qbittorrent-username`, `qbittorrent-password` — qBittorrent credentials
- `adguard-admin-username`, `adguard-admin-password` — AdGuard admin credentials (plaintext)

## Usage

1. Ensure `BWS_ACCESS_TOKEN` is set (export it or put it in `.env` at the repo root)
2. From the repo root, trust and install the pinned toolchain and Python dependencies
3. Source Bitwarden-backed environment variables into your current shell
4. Start the app port-forwards
5. Export `KUBE_CONFIG_PATH`

```
mise trust
mise install
mise run install
source scripts/setup-env.sh
./scripts/port-forward-apps.sh &
export KUBE_CONFIG_PATH=~/.kube/config
cd Terraform/apps
terraform init
terraform plan
terraform apply
```

The Jellyfin provider is published on Terraform Registry as `ThePhaseless/jellyfin`,
so `terraform init` now uses the standard registry installation flow.

The repo now manages Jellyfin bootstrap state directly in `Terraform/apps/jellyfin.tf`:
libraries, the SSO plugin repository/package, SSO plugin configuration, and login branding.
The Kubernetes setup sidecar is no longer the source of truth for those settings.

## Importing Existing Resources

If services are already configured, import them before applying to avoid duplicates:

```
terraform import sonarr_download_client.qbittorrent 1
terraform import radarr_download_client.qbittorrent 1
terraform import prowlarr_application.sonarr 1
terraform import prowlarr_application.radarr 2
terraform import adguard_rewrite.nerine_dev_wildcard '*.nerine.dev/100.72.236.33'
terraform import adguard_rewrite.nerine_dev 'nerine.dev/100.72.236.33'
```

The repo includes curated import blocks in `Terraform/apps/jellyfin.imports.tf` for
the live Jellyfin resources it manages. If you need to expand the managed surface
area later, regenerate a fresh comparison snapshot from the live server with:

```bash
export JELLYFIN_ENDPOINT=http://localhost:8096
export JELLYFIN_USERNAME=admin
export JELLYFIN_PASSWORD="$(bws secret list --output json --color no | jq -r '.[] | select(.key=="jellyfin-admin-password") | .value')"
go run github.com/ThePhaseless/terraform-provider-jellyfin/cmd/jellyfin-import@v0.1.0
```
