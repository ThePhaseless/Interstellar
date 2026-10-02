terraform {
  required_version = ">= 1.15.1"

  required_providers {
    restful = {
      source  = "magodo/restful"
      version = ">= 0.25.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.10.0"
    }
  }
}

# Polls until no attached Longhorn volume is degraded or rebuilding. The header is ignored by
# the API; it is here so that a new image updates this resource, which re-runs the poll.
resource "restful_operation" "longhorn_healthy" {
  count = var.upgrade_gate ? 1 : 0

  path   = "/apis/longhorn.io/v1beta2/namespaces/longhorn-system/volumes"
  method = "GET"
  header = {
    "X-Talos-Installer-Image" = var.image
  }

  poll = {
    status_locator = "body.items.#(status.state==\"attached\")#|#(status.robustness!=\"healthy\")#|#"
    status = {
      success = "0"
      # A count outside this list fails the apply rather than waiting.
      pending = [for n in range(1, 100) : tostring(n)]
    }
  }

  output_attrs = ["kind"]
}

resource "talos_machine" "this" {
  client_configuration  = var.client_configuration
  machine_configuration = var.machine_configuration
  node                  = var.node
  endpoint              = var.endpoint
  image                 = var.image

  drain_on_upgrade                = true
  kubeconfig_wo                   = var.drain_kubeconfig
  ignore_kubernetes_upgrade_drift = true

  depends_on = [restful_operation.longhorn_healthy]
}
