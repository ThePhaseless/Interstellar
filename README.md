# Interstellar Homelab

A GitOps-managed Kubernetes homelab running TalosOS on Proxmox, with secure public access via Tailscale mesh networking and an Oracle VPS entry point.

## 🌐 Architecture Overview

```mermaid
flowchart TB
    subgraph Internet["🌐 Public Internet"]
        Users(["Users"])
    end

    subgraph Private["🏠 Private Network"]
        Devices(["Private Devices"])
    end

    subgraph Oracle["☁️ Oracle Cloud"]
        HAProxy["HAProxy<br/>Entry Point"]
    end

    subgraph Tailscale["🔐 Tailscale Mesh"]
        TS(("Encrypted<br/>Overlay"))
    end

    subgraph Proxmox["🖥️ Proxmox Host"]
        subgraph Cluster["TalosOS Cluster"]
            T1["talos-1<br/>GPU"]
            T2["talos-2"]
            T3["talos-3"]
        end
        iSCSI[("ZFS<br/>iSCSI<br/>8TB")]
    end

    Users -->|HTTPS| HAProxy
    Devices -->|Tailscale| TS
    HAProxy -->|Tailscale| TS
    TS <-->|Encrypted| T1 & T2 & T3
    T1 & T2 & T3 <-->|LongHorn| iSCSI

    style Internet fill:#e1f5fe
    style Private fill:#f3e5f5
    style Oracle fill:#fff3e0
    style Tailscale fill:#e8f5e9
    style Proxmox fill:#fce4ec
    style Cluster fill:#fff8e1
```

## 🛠️ Technology Stack

| Layer             | Technology                                            |
| ----------------- | ----------------------------------------------------- |
| **OS**            | TalosOS v1.10.0 (immutable Linux)                     |
| **Orchestration** | Kubernetes 1.32.0                                     |
| **GitOps**        | ArgoCD (app-of-apps pattern)                          |
| **Networking**    | Flannel CNI, MetalLB L2, Tailscale                    |
| **Ingress**       | Traefik v3.3 with PROXY protocol + CrowdSec plugin   |
| **Storage**       | LongHorn CSI → iSCSI → ZFS zvol                       |
| **Secrets**       | Bitwarden Secrets Manager + External Secrets Operator |
| **Security**      | CrowdSec WAF (Traefik plugin v1.5.0), ClamAV malware scanning |
| **Observability** | Grafana, Loki, Mimir, Promtail, Alloy                 |
| **IaC**           | Terraform, Ansible, GitHub Actions                    |

## 🖥️ Hardware

### Proxmox Host

| Component   | Specification                          |
| ----------- | -------------------------------------- |
| **CPU**     | Intel Core i5-12600K (6P + 4E cores)   |
| **RAM**     | 32GB DDR4                              |
| **Storage** | 1TB NVMe + 8TB ZFS pool (iSCSI target) |
| **GPU**     | Intel Arc B580 (passed to talos-1)     |
| **Network** | 1Gbps + Tailscale mesh                 |

### TalosOS Cluster (3 nodes)

| Node    | vCPU | RAM  | Role                   | Special         |
| ------- | ---- | ---- | ---------------------- | --------------- |
| talos-1 | 8    | 16GB | Control Plane + Worker | GPU passthrough |
| talos-2 | 8    | 16GB | Control Plane + Worker | —               |
| talos-3 | 8    | 16GB | Control Plane + Worker | —               |

### Oracle VPS (Entry Point)

| Component    | Specification                 |
| ------------ | ----------------------------- |
| **Instance** | VM.Standard.A1.Flex (ARM)     |
| **CPU**      | 4 Ampere cores                |
| **RAM**      | 24GB                          |
| **Network**  | 4Gbps + public IP             |
| **Role**     | HAProxy → Tailscale → Traefik |

## 📦 Services

### Media Stack

| Service     | Access    | Description                       |
| ----------- | --------- | --------------------------------- |
| Jellyfin    | Public    | Media streaming (GPU transcoding) |
| Jellyseerr  | Public    | Media request management          |
| Sonarr      | Tailscale | TV show automation                |
| Radarr      | Tailscale | Movie automation                  |
| Prowlarr    | Tailscale | Indexer management                |
| Bazarr      | Tailscale | Subtitle management               |
| qBittorrent | Tailscale | Download client                   |
| Recyclarr   | Internal  | TRaSH guide sync                  |
| Decluttarr  | Internal  | Auto-cleanup                      |

### Utilities

| Service      | Access            | Description                   |
| ------------ | ----------------- | ----------------------------- |
| Copyparty    | Tailscale + OAuth | File sharing (GPU processing) |
| Immich       | Tailscale         | Photo management (ML on GPU)  |
| AdGuard Home | Tailscale         | DNS + ad blocking             |
| MCPJungle    | Internal          | MCP server aggregator         |

### Infrastructure

| Component          | Description                    |
| ------------------ | ------------------------------ |
| ArgoCD             | GitOps continuous deployment   |
| Traefik            | Ingress controller             |
| CrowdSec           | WAF + threat detection         |
| MetalLB            | Load balancer (L2 mode)        |
| LongHorn           | Distributed block storage      |
| External Secrets   | Bitwarden integration          |
| Tailscale Operator | Service mesh + auth            |
| Reloader           | Auto-reload on config changes  |
| ClamAV             | Malware scanning for downloads |

## 📂 Repository Structure

```
Interstellar/
├── .github/workflows/       # CI/CD pipelines
│   ├── terraform.yaml       # Infrastructure deployment
│   ├── ansible.yaml         # Host configuration
│   ├── kubernetes-lint.yaml # Manifest linting
│   └── tailscale-acl.yaml   # ACL policy sync
├── .kube-linter.yaml        # Kube-linter configuration
├── Ansible/                 # Host configuration playbooks
│   ├── setup-proxmox.yaml   # VLAN, iSCSI, firewall
│   └── setup-oracle.yaml    # HAProxy, Tailscale
├── Kubernetes/
│   └── talos/
│       ├── bootstrap/       # Core infrastructure
│       │   ├── argocd/
│       │   ├── metallb/
│       │   ├── longhorn/
│       │   ├── traefik/
│       │   ├── crowdsec/
│       │   ├── external-secrets/
│       │   ├── tailscale-operator/
│       │   ├── observability/
│       │   └── clamav/
│       └── apps/            # Application manifests
├── scripts/
│   └── lint-kubernetes.sh   # Local linting script
├── Tailscale/
│   └── policy.hujson        # ACL policy
├── Terraform/               # Infrastructure as Code
│   ├── proxmox.tf           # VM provisioning
│   ├── talos.tf             # Cluster configuration
│   ├── cloudflare.tf        # DNS records
│   ├── tailscale.tf         # Auth keys
│   ├── oracle.tf            # VPS infrastructure
│   └── bitwarden.tf         # Secret references
├── haproxy.cfg              # Oracle HAProxy config
└── compose.proxy.yaml       # HAProxy Docker Compose
```

## 🔐 Required Secrets

Before deployment, configure these secrets in **Bitwarden Secrets Manager** and **GitHub repository settings**.

### How to Obtain Secrets

| Service                  | Documentation                                                                                        |
| ------------------------ | ---------------------------------------------------------------------------------------------------- |
| **Bitwarden SM**         | [Machine Accounts](https://bitwarden.com/help/machine-accounts/)                                     |
| **Tailscale API**        | [API Keys](https://tailscale.com/kb/1101/api#authentication)                                         |
| **Tailscale OAuth**      | [OAuth Clients](https://tailscale.com/kb/1215/oauth-clients)                                         |
| **OCI API Keys**         | [Required Keys and OCIDs](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm) |
| **Cloudflare API Token** | [Create API Token](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/)    |
| **Proxmox API Token**    | [API Tokens](https://pve.proxmox.com/wiki/User_Management#_api_tokens)                               |
| **CrowdSec Bouncer Key** | [Bouncer Registration](https://docs.crowdsec.net/docs/next/bouncers/intro)                           |
| **Google OAuth**         | [OAuth 2.0 Setup](https://developers.google.com/identity/protocols/oauth2)                           |

### GitHub Repository Secrets

| Secret                | Description                                    |
| --------------------- | ---------------------------------------------- |
| `BW_ACCESS_TOKEN`     | Bitwarden machine account token (main project) |
| `BW_OCI_ACCESS_TOKEN` | Bitwarden machine account token (OCI backend)  |

### GitHub Repository Variables

| Variable          | Description                                        |
| ----------------- | -------------------------------------------------- |
| `TF_STATE_BUCKET` | OCI Object Storage bucket name for Terraform state |

### Bitwarden Secrets Manager

These secrets must exist in your Bitwarden Secrets Manager project:

#### OCI Backend (separate project for bootstrap)

| Key                | Description                         |
| ------------------ | ----------------------------------- |
| `oci-tenancy-ocid` | OCI tenancy OCID                    |
| `oci-user-ocid`    | OCI user OCID                       |
| `oci-fingerprint`  | OCI API key fingerprint             |
| `oci-private-key`  | OCI API private key (PEM format)    |
| `oci-region`       | OCI region (e.g., `eu-frankfurt-1`) |
| `oci-namespace`    | OCI Object Storage namespace        |

#### Infrastructure Secrets (main project)

| Key                                   | Description                         |
| ------------------------------------- | ----------------------------------- |
| `oci-compartment-id`                  | OCI compartment for resources       |
| `tailscale-api-key`                   | Tailscale API key                   |
| `tailscale-tailnet`                   | Tailscale tailnet name              |
| `tailscale-oauth-client-id`           | OAuth client for Tailscale Operator |
| `tailscale-oauth-secret`              | OAuth secret for Tailscale Operator |
| `proxmox-api-token-id`                | Proxmox API token ID                |
| `proxmox-api-token-secret`            | Proxmox API token secret            |
| `cloudflare-api-token`                | Cloudflare API token (DNS edit)     |
| `discord-webhook-url`                 | Discord webhook for alerts          |
| `crowdsec-api-key`                    | CrowdSec enrollment key             |
| `google-oauth-client-id`              | Google OAuth for Copyparty          |
| `google-oauth-client-secret`          | Google OAuth secret for Copyparty   |
| `jellyfin-google-oauth-client-id`     | Google OAuth for Jellyfin SSO       |
| `jellyfin-google-oauth-client-secret` | Google OAuth secret for Jellyfin    |
| `copyparty-admins`                    | Comma-separated admin emails        |
| `copyparty-writers`                   | Comma-separated writer emails       |

### Secrets Created by Terraform (do not set manually)

These are generated automatically during `terraform apply` and stored in Bitwarden:

| Secret                | Generated By                          | Stored As                    |
| --------------------- | ------------------------------------- | ---------------------------- |
| Tailscale auth key    | `tailscale_tailnet_key.cluster`       | `tailscale-auth-key`         |
| OAuth2 cookie secret  | `random_password.oauth_cookie_secret` | `google-oauth-cookie-secret` |
| Talos machine secrets | `talos_machine_secrets.cluster`       | Terraform state              |
| Kubeconfig            | `talos_cluster_kubeconfig.cluster`    | Terraform output             |
| Talosconfig           | `talos_machine_configuration`         | Terraform output             |

## 🚀 Deployment

### Prerequisites

1. Domain configured in Cloudflare
2. Oracle Cloud account (free tier works)
3. Proxmox VE 8+ with IOMMU enabled
4. Bitwarden Secrets Manager account
5. Tailscale account with API access

### Initial Setup

```bash
# 1. Fork and clone the repository
git clone https://github.com/YOUR_USERNAME/Interstellar.git
cd Interstellar

# 2. Configure GitHub secrets and variables (see above)

# 3. Create Bitwarden secrets (see above)

# 4. Push to trigger deployment
git push origin main
```

### Deployment Order

1. **Terraform** provisions Oracle VPS and Proxmox VMs
2. **Ansible** configures hosts (VLAN, iSCSI, HAProxy)
3. **Terraform** bootstraps TalosOS cluster
4. **ArgoCD** deploys all Kubernetes resources from Git

## 🔄 CI/CD Workflows

| Workflow             | Trigger      | Action               |
| -------------------- | ------------ | -------------------- |
| `terraform.yaml`     | PR to main   | Plan and comment     |
| `terraform.yaml`     | Push to main | Apply infrastructure |
| `ansible.yaml`       | PR to main   | Lint playbooks       |
| `ansible.yaml`       | Push to main | Run playbooks        |
| `tailscale-acl.yaml` | PR to main   | Validate policy      |
| `tailscale-acl.yaml` | Push to main | Apply ACL policy     |

## 🔒 Security Model

- **Network Isolation**: Cluster runs on VLAN 100, no direct LAN access
- **Zero Trust**: All inter-service communication via Tailscale
- **Public Access**: Only through Oracle VPS → Tailscale → Traefik
- **Private Services**: Require Tailscale authentication
- **Malware Scanning**: ClamAV scans all downloaded files
- **WAF Protection**: CrowdSec with community threat feeds

## 📝 License

This project is for personal use and educational purposes.
