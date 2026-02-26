variable "sonarr_url" {
  type        = string
  description = "Sonarr cluster-internal URL (used in Prowlarr app config)"
  default     = "http://sonarr.media.svc.cluster.local:8989"
}

variable "radarr_url" {
  type        = string
  description = "Radarr cluster-internal URL (used in Prowlarr app config)"
  default     = "http://radarr.media.svc.cluster.local:7878"
}

variable "prowlarr_url" {
  type        = string
  description = "Prowlarr cluster-internal URL (used in Prowlarr app config)"
  default     = "http://prowlarr.media.svc.cluster.local:9696"
}

variable "qbittorrent_host" {
  type        = string
  description = "qBittorrent cluster-internal host (stored in Sonarr/Radarr config)"
  default     = "qbittorrent.media.svc.cluster.local"
}

variable "qbittorrent_port" {
  type        = number
  description = "qBittorrent port"
  default     = 8080
}

variable "sonarr_tv_category" {
  type        = string
  description = "Sonarr download category"
  default     = "tv"
}

variable "radarr_movie_category" {
  type        = string
  description = "Radarr download category"
  default     = "movies"
}

variable "byparr_url" {
  type        = string
  description = "Byparr (FlareSolverr-compatible) cluster-internal URL"
  default     = "http://byparr.media.svc.cluster.local:8191"
}

# --- Provider URLs (how Terraform connects to services via kubectl port-forward) ---
# Locally: run ./scripts/port-forward-apps.sh to forward services to localhost.
# In CI: override with TF_VAR_* env vars pointing to Tailscale MagicDNS names.
variable "sonarr_provider_url" {
  type        = string
  description = "Sonarr URL reachable from Terraform (localhost via port-forward, or Tailscale in CI)"
  default     = "http://localhost:8989"
}

variable "radarr_provider_url" {
  type        = string
  description = "Radarr URL reachable from Terraform (localhost via port-forward, or Tailscale in CI)"
  default     = "http://localhost:7878"
}

variable "prowlarr_provider_url" {
  type        = string
  description = "Prowlarr URL reachable from Terraform (localhost via port-forward, or Tailscale in CI)"
  default     = "http://localhost:9696"
}

variable "adguard_provider_url" {
  type        = string
  description = "AdGuard Home host:port reachable from Terraform (localhost via port-forward, or Tailscale in CI)"
  default     = "localhost:3000"
}

variable "traefik_tailscale_ip" {
  type        = string
  description = "Traefik Tailscale IP for AdGuard A-record rewrites (Tailscale clients). Stable while pod secret intact; update if traefik device is re-registered."
  default     = "100.107.133.42"
}

variable "adguard_traefik_local_ip" {
  type        = string
  description = "Traefik MetalLB IP for DNS rewrites (*.nerine.dev) - used by local network clients"
  default     = "192.168.1.11"
}

variable "bitwarden_sonarr_api_key_name" {
  type        = string
  description = "Bitwarden secret key name for Sonarr API key"
  default     = "sonarr-api-key"
}

variable "bitwarden_radarr_api_key_name" {
  type        = string
  description = "Bitwarden secret key name for Radarr API key"
  default     = "radarr-api-key"
}

variable "bitwarden_prowlarr_api_key_name" {
  type        = string
  description = "Bitwarden secret key name for Prowlarr API key"
  default     = "prowlarr-api-key"
}

# --- Authentik ---
variable "authentik_provider_url" {
  type        = string
  description = "Authentik URL reachable from Terraform (via Tailscale MagicDNS)"
  default     = "http://localhost:9000"
}

variable "authentik_domain" {
  type        = string
  description = "Base domain for Authentik cookie scope and proxy providers"
  default     = "nerine.dev"
}
