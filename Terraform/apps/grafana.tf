resource "grafana_data_source" "loki" {
  name = "Loki"
  type = "loki"
  url  = var.grafana_loki_url

  json_data_encoded = jsonencode({
    maxLines = 1000
  })
}

resource "grafana_data_source" "mimir" {
  name       = "Mimir"
  type       = "prometheus"
  url        = var.grafana_mimir_url
  is_default = true

  json_data_encoded = jsonencode({
    httpMethod = "POST"
  })
}
