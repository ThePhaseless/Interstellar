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

Local provider defaults point at `localhost`, so start the app port-forwards before running Terraform. If you prefer direct Tailscale or MagicDNS endpoints, override the `TF_VAR_*_provider_url` variables.

Project environment setup:

- `mise` installed and activated in your shell
- From the repo root: `mise trust && mise install && mise run install`
- Bitwarden-backed environment loaded in the current shell: `source scripts/setup-env.sh`
- `KUBE_CONFIG_PATH` exported (for example `~/.kube/config`)

Required Bitwarden secrets:

- `sonarr-api-key`, `radarr-api-key`, `prowlarr-api-key` — \*arr API keys
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
