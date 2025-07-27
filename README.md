# Interstellar Homelab

This repository contains the complete configuration and documentation for my personal homelab infrastructure. The setup demonstrates practical knowledge of various technologies including virtualization, containerization, networking, and self-hosted services. All of this achieved with bypassing the lack of the public IP from the ISP.

## 🌐 Infrastructure Overview

```
                                ┌──────────────┐     ┌───────────┐
                                │              │     │           │
                                │    Public    │     │  Private  │
                                │  Entrypoint  │     │  Devices  │
                                │              │     │           │
                                └───────┬──────┘     └──┬────────┘
                                        │               │      ▲
                                        ▼               │      │
                               ┌────────────────┐       │
                               │                │       │      │
                               │   Oracle VPS   │       │      │
                               │   (HAProxy)    │       │
                               │                │       │      │
                               └────────┬───────┘       │      │
                                        │               │
                                        ▼               ▼      │
                                       ┌────────────────┐      │
               DNS (AdGuard Home)      │ Tailscale Mesh │
        ┌── ── ── ── ── ── ── ── ── ───┤    Network     ├─── ──┘
                                       └────────┬───────┘
        ▼            ┌────────────────┐         │
┌───────────────┐    │                │         │
│ Docker        │    │  Home Server   │         │
│ Containers    │◄───┤   (Proxmox)    │◄────────┘
└───────────────┘    │                │
                     └────────────────┘
```

## 🛠️ Technologies Used

- **Virtualization**: Proxmox VE
- **Networking**: Tailscale, HAProxy, Traefik
- **Containerization**: Docker, Docker Compose
- **Security**: CrowdSec, Authentik, Firewall
- **Automation**: GitHub Actions, Renovate
- **Infrastructure as Code**: All configurations stored in this repository

## 🖥️ Main Server

### Server Specification

| Component   | Specification                                           | Proxy VPS                  |
| ----------- | ------------------------------------------------------- | -------------------------- |
| **CPU**     | Intel Core i5-12600K (6 p-cores, 4 e-cores, 16 threads) | Ampere A1 Flex (4 cores)   |
| **RAM**     | 32GB DDR4 (2x16GB)                                      | 20 GB                      |
| **Storage** | 1TB Dahua NVMe SSD + 5x 3TB Refurbished Segate HDD      | 10 GB Block Storage        |
| **GPU**     | Intel UHD Graphics 770                                  | N/A                        |
| **Network** | 1Gbps Ethernet + Tailscale VPN                          | 4Gbps Ethernet + Tailscale |
| **OS**      | Proxmox VE 8                                            | Ubuntu 24.04 Minimal       |

The primary server runs Proxmox VE with VM containing various docker containers:

### 🎬 Media Services

| Service     | Description                         |
| ----------- | ----------------------------------- |
| Jellyfin    | Media streaming server              |
| Sonarr      | TV show management                  |
| Radarr      | Movie management                    |
| Bazarr      | Subtitle management                 |
| Jellyseerr  | Media request management            |
| qBittorrent | Download client                     |
| Prowlarr    | Indexer management                  |
| Recyclarr   | Radarr/Sonarr configuration manager |
| Decluttarr  | Media organization                  |
| Renamer     | Custom media renaming service       |
| Byparr      | Cloudflare Turnstile bypass         |

### 🔐 Security & Auth

| Service          | Description                              |
| ---------------- | ---------------------------------------- |
| Authentik Server | Identity provider and SSO                |
| Authentik Worker | Background task processing               |
| Authentik LDAP   | LDAP provider outpost                    |
| PostgreSQL       | Database for Authentik                   |
| Redis            | Caching for Authentik                    |
| AdGuard Home     | DNS-based ad blocking                    |
| CrowdSec         | Security automation and threat detection |
| Postfix          | Reverse mail service for containers      |

### 🧩 Other Services

| Service       | Description            |
| ------------- | ---------------------- |
| Traefik       | Internal reverse proxy |
| HomeAssistant | Home automation        |
| Homepage      | Dashboard for services |
| ScanServJS    | Scanner web interface  |
| MSSQL         | Microsoft SQL Server   |
| HTTPD         | Web server             |
| Whoami        | Testing service        |

## ☁️ Oracle Cloud Infrastructure

A VPS running on Oracle's free ARM tier with:

- HAProxy configured for reverse proxy with Proxy Protocol enabled to bypass CGNat
- Docker & Docker Compose
- Firewall rules:
  - Allow HTTP/HTTPS from any source
  - Allow SSH only from Tailscale network

## 🔒 Tailscale Implementation

Tailscale is utilized for:

- Secure VPN mesh connecting all infrastructure
- SSH authentication
- Automatic DNS configuration with AdGuard Home
- Game server sharing
- Zero-trust network architecture
- Self hosted proxy (Oracle VPS running as an exit node)

## ♻️ CI/CD Pipeline

- GitHub Actions workflow for automated testing and deployment
- Renovate bot configured for:
  - Automatic updates for minor releases
  - Pull requests for major version updates
- Ensures infrastructure stays current and secure

## 📂 Repository Structure

```
Interstellar/
├─ .github/         # GitHub Actions workflows
├─ .vscode/         # VS Code configuration files
├─ .devcontainer/   # Testing environment
├─ Config/          # Template config files for services
├─ Scripts/         # Deploy scripts
├─ compose.*.yaml   # Docker Compose files
├─ renovate.json    # Renovate configuration
└─ README.md        # The file that you're reading
```

## 🛒 Requirements

- Domain
- Cloudflare Account
- SMTP Account
- Public IP address

## 🔄 Getting Started

1. Start Tailscale with `` for docker IP resolving (may break Tailscale subnet routing)
2. Clone this repository
3. Rename `*.env.example` files to `*.env`
4. Update the values in the `.env` files
5. Run `docker compose up -d`
6. Set up \*arr and fill out API keys in .env file
7. [Setup Authentik with Traefik](https://github.com/brokenscripts/authentik_traefik?tab=readme-ov-file)
8. [Configure LDAP Authentik with Jellyfin](https://docs.goauthentik.io/integrations/services/jellyfin/) (use manual outpost and set outpost token in `.env` file)
9. Run `docker compose up -d` again to apply new variables

## 🚀 Future Enhancements

- Implement proper backup solution
- Expand monitoring capabilities
