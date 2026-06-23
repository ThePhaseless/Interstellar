terraform {
  backend "oci" {
    bucket    = "tf-state"
    namespace = "frhsbtxnilh6"
    key       = "interstellar/servarr.tfstate"
  }
}
