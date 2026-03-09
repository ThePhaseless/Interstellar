{
  description = "Interstellar Homelab – GitOps-managed Kubernetes homelab on TalosOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
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
            oniguruma

            # Kubernetes
            kubectl
            kustomize
            kubernetes-helm
            kube-linter

            # Infrastructure-as-Code
            terraform
            tflint

            # Secrets
            bws # Bitwarden Secrets Manager CLI

            # Talos
            talosctl

            # Formatters
            nixfmt

            # Utilities
            jq
            openssl
            ripgrep
            bubblewrap
            socat
          ];

          # Env setup is handled by .envrc (direnv) — see dotenv, venv, and secrets logic there.
          # shellHook is intentionally minimal; use `direnv allow` to activate the full environment.
        };
      }
    );
}
