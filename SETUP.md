# Setup Guide

This guide covers the prerequisites, secrets configuration, and deployment steps for the Interstellar homelab.

## 🔐 Required Secrets

Before deployment, configure these secrets in **Bitwarden Secrets Manager** and **GitHub repository settings**.

### How to Obtain Secrets

| Service                  | Documentation                                                                                        |
| ------------------------ | ---------------------------------------------------------------------------------------------------- |
| **Bitwarden SM**         | [Machine Accounts](https://bitwarden.com/help/machine-accounts/)                                     |
| **Tailscale API**        | [API Keys](https://tailscale.com/kb/1101/api#authentication)                                         |
| **Tailscale OAuth**      | [OAuth Clients](https://tailscale.com/kb/1215/oauth-clients)                                         |
| **OCI API Keys**         | [Required Keys and OCIDs](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm) |
| **Cloudflare API Token** | [Create API Token](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/)     |
| **Proxmox API Token**    | [API Tokens](https://pve.proxmox.com/wiki/User_Management#_api_tokens)                               |
| **CrowdSec Bouncer Key** | [Bouncer Registration](https://docs.crowdsec.net/docs/next/bouncers/intro)                           |
| **Google OAuth**         | [OAuth 2.0 Setup](https://developers.google.com/identity/protocols/oauth2)                           |

### GitHub Repository Secrets

| Secret            | Description                                                             |
| ----------------- | ----------------------------------------------------------------------- |
| `BW_ACCESS_TOKEN` | Bitwarden machine account token (single project containing all secrets) |

### Bitwarden Secrets Manager

All secrets should be stored in a single Bitwarden Secrets Manager project:

#### OCI Secrets

| Key               | Description                                     |
| ----------------- | ----------------------------------------------- |
| `oci-config`      | Full `~/.oci/config` file content (without key) |
| `oci-private-key` | OCI API private key (PEM format)                |
| `oci-namespace`   | OCI Object Storage namespace                    |
| `tf-state-bucket` | OCI Object Storage bucket name                  |

#### Infrastructure Secrets

| Key                         | Description                                   | Required Permissions                                                          |
| --------------------------- | --------------------------------------------- | ----------------------------------------------------------------------------- |
| `tailscale-oauth-client-id` | Tailscale OAuth client ID                     | Scopes: `devices:core`, `keys:auth_keys` (Write) — Tags: `tag:cluster,tag:ci` |
| `tailscale-oauth-secret`    | Tailscale OAuth client secret                 | -                                                                             |
| `tailscale-tailnet`         | Tailscale tailnet name (e.g. `example.org`)   | -                                                                             |
| `cloudflare-api-token`      | Cloudflare API token                          | `Zone:DNS:Edit`, `Zone:Zone:Read` for your domain                             |
| `cloudflare-zone-id`        | Cloudflare Zone ID                            | -                                                                             |
| `proxmox-api-token`         | Proxmox API token (`user@realm!token=secret`) | Full permissions on `/` or VM management                                      |
| `discord-webhook-url`       | Discord webhook for alerts                    | -                                                                             |
| `crowdsec-api-key`          | CrowdSec enrollment key                       | -                                                                             |
| `copyparty-admins`          | Comma-separated admin emails                  | -                                                                             |
| `copyparty-writers`         | Comma-separated writer emails                 | -                                                                             |

#### OAuth2 Proxy Secrets (Google OAuth)

| Key                                 | Description                                 | Required Permissions                                 |
| ----------------------------------- | ------------------------------------------- | ---------------------------------------------------- |
| `oauth2-proxy-google-client-id`     | Google OAuth Client ID                      | Google Cloud Console → APIs & Services → Credentials |
| `oauth2-proxy-google-client-secret` | Google OAuth Client Secret                  | Same as above                                        |
| `oauth2-proxy-cookie-secret`        | Cookie encryption secret (32 bytes, base64) | Generate with `openssl rand -base64 32`              |

**Google OAuth Setup:**

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select existing
3. Enable "Google+ API" or "Google Identity"
4. Go to APIs & Services → Credentials → Create OAuth Client ID
5. Application type: Web application
6. Authorized redirect URIs: `https://auth.nerine.dev/oauth2/callback`
7. Copy Client ID and Client Secret to Bitwarden

### Secrets Created by OpenTofu (do not set manually)

These are generated automatically during `tofu apply` and stored in Bitwarden:

| Secret                | Generated By                          | Stored As                    |
| --------------------- | ------------------------------------- | ---------------------------- |
| Tailscale auth key    | `tailscale_tailnet_key.cluster`       | `tailscale-auth-key`         |
| OAuth2 cookie secret  | `random_password.oauth_cookie_secret` | `google-oauth-cookie-secret` |
| Talos machine secrets | `talos_machine_secrets.cluster`       | OpenTofu state               |
| Kubeconfig            | `talos_cluster_kubeconfig.cluster`    | OpenTofu output              |
| Talosconfig           | `talos_machine_configuration`         | OpenTofu output              |

## 🚀 Bootstrap & Deployment

### Prerequisites

1. Domain configured in Cloudflare
2. Oracle Cloud account (free tier works)
3. Proxmox VE 8+ with IOMMU enabled
4. Bitwarden Secrets Manager account
5. Tailscale account with API access
6. Tools installed: `tofu` (OpenTofu), `ansible`, `bws`, `tailscale`

### 1. Environment Setup

Clone the repository and load the environment variables from Bitwarden.

```bash
# 1. Clone the repository
git clone https://github.com/ThePhaseless/Interstellar.git
cd Interstellar

# 2.a. Set Bitwarden Access Token
export BWS_ACCESS_TOKEN="<your-token>"

# 2.b. Or create .env file in root of the repo
```

.env:
BWS_ACCESS_TOKEN="<your-token>"

```

# 3. Fetch secrets and setup environment
source scripts/setup-env.sh
```

### 2. Infrastructure Bootstrap

We use a "local-first" approach to create the remote state bucket and provisioning infrastructure.

```bash
cd Terraform

# 1. Initialize with local state (bypasses remote backend)
tofu init -backend=false

# 2. Apply infrastructure
# This creates the OCI Compartment, State Bucket, VPS, and Proxmox VMs
tofu apply

# 3. Migrate state to OCI Object Storage
# This initializes the remote backend and uploads your local state
tofu init
# Type 'yes' when asked to copy state
```

### 3. Configuration & Cluster Setup

```bash
cd ../Ansible

# 1. Configure Oracle VPS (HAProxy)
ansible-playbook setup-oracle.yaml

# 2. Configure Proxmox Node (Network/Storage)
ansible-playbook setup-proxmox.yaml
```

### 4. GitOps Activation

Pushing to `main` triggers the CI/CD pipeline, which will now use the configured OCI remote backend.

```bash
git push origin main
```

## 🔄 CI/CD Workflows

| Workflow             | Trigger      | Action               |
| -------------------- | ------------ | -------------------- |
| `opentofu.yaml`      | PR to main   | Plan and comment     |
| `opentofu.yaml`      | Push to main | Apply infrastructure |
| `ansible.yaml`       | PR to main   | Lint playbooks       |
| `ansible.yaml`       | Push to main | Run playbooks        |
| `tailscale-acl.yaml` | PR to main   | Validate policy      |
| `tailscale-acl.yaml` | Push to main | Apply ACL policy     |
