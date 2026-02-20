# --- Cluster-internal URLs (stored in app configs for inter-service communication) ---
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

# --- Provider URLs (how Terraform connects to the services, via Tailscale MagicDNS) ---
variable "sonarr_provider_url" {
  type        = string
  description = "Sonarr URL reachable from Terraform (via Tailscale MagicDNS)"
  default     = "http://sonarr:8989"
}

variable "radarr_provider_url" {
  type        = string
  description = "Radarr URL reachable from Terraform (via Tailscale MagicDNS)"
  default     = "http://radarr:7878"
}

variable "prowlarr_provider_url" {
  type        = string
  description = "Prowlarr URL reachable from Terraform (via Tailscale MagicDNS)"
  default     = "http://prowlarr:9696"
}

variable "adguard_provider_url" {
  type        = string
  description = "AdGuard Home URL reachable from Terraform (via Tailscale MagicDNS)"
  default     = "http://adguard:3000"
}

variable "adguard_traefik_tailscale_ip" {
  type        = string
  description = "Traefik Tailscale IP for DNS rewrites (*.nerine.dev)"
  default     = "100.72.236.33"
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

variable "bitwarden_qbittorrent_username_name" {
  type        = string
  description = "Bitwarden secret key name for qBittorrent username"
  default     = "qbittorrent-username"
}

variable "bitwarden_qbittorrent_password_name" {
  type        = string
  description = "Bitwarden secret key name for qBittorrent password"
  default     = "qbittorrent-password"
}

# --- Authentik ---
variable "authentik_provider_url" {
  type        = string
  description = "Authentik URL reachable from Terraform (via Tailscale MagicDNS or port-forward)"
  default     = "http://localhost:9000"
}

variable "authentik_domain" {
  type        = string
  description = "Base domain for Authentik cookie scope and proxy providers"
  default     = "nerine.dev"
}

variable "authentik_vip_emails" {
  type        = list(string)
  description = "Email addresses allowed to access VIP-restricted applications"
  default     = []
}
