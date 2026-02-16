variable "sonarr_url" {
  type        = string
  description = "Sonarr base URL"
  default     = "http://sonarr.media.svc.cluster.local:8989"
}

variable "radarr_url" {
  type        = string
  description = "Radarr base URL"
  default     = "http://radarr.media.svc.cluster.local:7878"
}

variable "prowlarr_url" {
  type        = string
  description = "Prowlarr base URL"
  default     = "http://prowlarr.media.svc.cluster.local:9696"
}

variable "qbittorrent_host" {
  type        = string
  description = "qBittorrent host"
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

variable "grafana_url" {
  type        = string
  description = "Grafana base URL"
  default     = "http://grafana.observability.svc.cluster.local:3000"
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

variable "bitwarden_grafana_auth_name" {
  type        = string
  description = "Bitwarden secret key name for Grafana auth (token or username:password)"
  default     = "grafana-auth"
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
variable "grafana_loki_url" {
  type        = string
  description = "Grafana Loki data source URL"
  default     = "http://loki.observability.svc.cluster.local:3100"
}

variable "grafana_mimir_url" {
  type        = string
  description = "Grafana Mimir data source URL"
  default     = "http://mimir.observability.svc.cluster.local:9009/prometheus"
}
