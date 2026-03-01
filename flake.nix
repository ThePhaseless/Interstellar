{
  description = "Interstellar Homelab – GitOps-managed Kubernetes homelab on TalosOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfreePredicate =
            pkg:
            builtins.elem (pkgs.lib.getName pkg) [
              "bws"
              "terraform"
            ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            # Python / project dependency management (manages pyproject.toml deps)
            uv

            # Kubernetes
            kubectl
            kustomize
            kubernetes-helm
            kube-linter

            # Infrastructure-as-Code
            terraform
            tflint

            # Networking
            tailscale

            # Secrets
            bws # Bitwarden Secrets Manager CLI

            # Utilities
            jq
            openssl
          ];

          shellHook = ''
            # Let uv manage the Python toolchain & virtualenv from pyproject.toml
            export UV_PYTHON_PREFERENCE=managed

            if [[ ! -d .venv ]]; then
              echo "Creating virtualenv via uv sync ..."
              uv sync --quiet
            fi

            source .venv/bin/activate
          '';
        };
      }
    );
}
