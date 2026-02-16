# Terraform App Configuration

This folder manages app configuration via Terraform providers. State is stored in a
Kubernetes secret using the kubernetes backend.

## What This Manages

- Sonarr and Radarr qBittorrent download clients
- Prowlarr applications for Sonarr and Radarr
- Grafana data sources for Loki and Mimir

Jellyfin automation is not included here because there is no official Terraform
provider. Use the Jellyfin setup doc separately.

## Backend

The backend uses the default namespace and a secret suffix of "servarr".
Adjust backend settings in [Terraform/apps/backend.tf](Terraform/apps/backend.tf)
if you want a different namespace or secret name.

## Usage

1. Ensure you can reach the in-cluster service URLs (port-forward or run inside the
   cluster network).
2. Export Bitwarden Secrets Manager environment variables (same as infra):
   - BWS_ACCESS_TOKEN
   - BW_ORGANIZATION_ID

Example:

```
cd Terraform/apps
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## Importing Existing Resources

If Sonarr/Radarr/Prowlarr/Grafana are already configured, import them before
applying to avoid duplicates. Example:

```
terraform import sonarr_download_client.qbittorrent 1
terraform import radarr_download_client.qbittorrent 1
terraform import prowlarr_application.sonarr 1
terraform import prowlarr_application.radarr 2
terraform import grafana_data_source.loki "<uid>"
terraform import grafana_data_source.mimir "<uid>"
```
