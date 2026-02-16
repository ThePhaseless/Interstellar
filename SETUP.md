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

### Secrets Created by Terraform (do not set manually)

These are generated automatically during `terraform apply` and stored in Bitwarden:

| Secret                | Generated By                          | Stored As                    |
| --------------------- | ------------------------------------- | ---------------------------- |
| Tailscale auth key    | `tailscale_tailnet_key.cluster`       | `tailscale-auth-key`         |
| OAuth2 cookie secret  | `random_password.oauth_cookie_secret` | `google-oauth-cookie-secret` |
| Talos machine secrets | `talos_machine_secrets.cluster`       | Terraform state              |
| Kubeconfig            | `talos_cluster_kubeconfig.cluster`    | Terraform output             |
| Talosconfig           | `talos_machine_configuration`         | Terraform output             |

## 🚀 Bootstrap & Deployment

### Prerequisites

1. Domain configured in Cloudflare
2. Oracle Cloud account (free tier works)
3. Proxmox VE 8+ with IOMMU enabled
4. Bitwarden Secrets Manager account
5. Tailscale account with API access
6. Tools installed: `terraform`, `ansible`, `bws`, `tailscale`

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

This also writes `~/.talos/config` from the Bitwarden secret key `talosconfig` and attempts to configure kubectl via Tailscale using `talos-1` by default. Override with `TS_KUBECONFIG_TARGET=<hostname>` before sourcing if needed.

### 2. Ordered Bootstrap Runbook

Use this exact order.

#### Step A: Terraform init (local backend first)

```bash
cd Terraform
terraform init -backend=false
```

#### Step B: Terraform apply

```bash
terraform apply
```

If apply/plan fails with a stale lock:

```bash
terraform force-unlock -force <LOCK_ID>
```

#### Step C: Configure Proxmox host prerequisites

Talos nodes are bridged directly to the home LAN (`vmbr0`). Run this playbook to prepare Proxmox storage services required by the cluster.

```bash
cd ../Ansible
ansible-playbook setup-proxmox.yaml
```

#### Step D: Configure Oracle entrypoint

```bash
cd ../Ansible
ansible-playbook setup-oracle.yaml
```

#### Step E: Migrate Terraform state to OCI backend

```bash
cd ../Terraform
terraform init
```

Type `yes` when Terraform asks to copy local state to the remote backend.

### 3. Post-bootstrap Validation

Run these checks after Step B:

```bash
# Kubernetes API and node readiness
kubectl get nodes -o wide

# Talos health from control host
talosctl health --nodes 192.168.1.111,192.168.1.112,192.168.1.113
```

Optional: print helper output from Terraform:

```bash
cd /home/orcho/Interstellar/Terraform
terraform output access_instructions
```

### 4. GitOps Activation

Pushing to `main` triggers CI/CD workflows for Terraform, Ansible, and Kubernetes linting/deployment:

```bash
git push origin main
```

## 🔄 CI/CD Workflows

| Workflow             | Trigger      | Action               |
| -------------------- | ------------ | -------------------- |
| `terraform.yaml`     | PR to main   | Plan and comment     |
| `terraform.yaml`     | Push to main | Apply infrastructure |
| `ansible.yaml`       | PR to main   | Lint playbooks       |
| `ansible.yaml`       | Push to main | Run playbooks        |
| `tailscale-acl.yaml` | PR to main   | Validate policy      |
| `tailscale-acl.yaml` | Push to main | Apply ACL policy     |
