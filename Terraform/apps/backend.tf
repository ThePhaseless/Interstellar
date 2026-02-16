terraform {
  backend "kubernetes" {
    namespace     = "default"
    secret_suffix = "servarr"
  }
}
