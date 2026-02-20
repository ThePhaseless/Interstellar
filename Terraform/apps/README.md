# Terraform App Configuration

This folder manages app configuration via Terraform providers. State is stored in a
Kubernetes secret using the kubernetes backend.

## What This Manages

- Sonarr and Radarr qBittorrent download clients
- Prowlarr applications for Sonarr and Radarr
- AdGuard Home DNS rewrites and filter lists

## Backend

The backend uses the default namespace and a secret suffix of "servarr".
Adjust backend settings in [Terraform/apps/backend.tf](Terraform/apps/backend.tf)
if you want a different namespace or secret name.

## Prerequisites

Services are accessed directly via **Tailscale MagicDNS** — no port-forwarding required.
Ensure you are connected to the Tailscale network where the cluster services are exposed.

Required Bitwarden secrets:
- `sonarr-api-key`, `radarr-api-key`, `prowlarr-api-key` — *arr API keys
- `qbittorrent-username`, `qbittorrent-password` — qBittorrent credentials
- `adguard-admin-username`, `adguard-admin-password` — AdGuard admin credentials (plaintext)

## Usage

1. Connect to the Tailscale network
2. Export Bitwarden Secrets Manager environment variables (same as infra):
   - BWS_ACCESS_TOKEN
   - BW_ORGANIZATION_ID

```
source .venv/bin/activate && source scripts/setup-env.sh
cd Terraform/apps
terraform init
terraform plan
terraform apply
```

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
