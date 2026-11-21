FROM bitnami/kubectl@sha256:8919c149c2e3d6860e0143c117900e64d71395172aaef0e01e604bb98c8e7ce0 as kubectl
FROM alpine/helm@sha256:a3b9d617c0c30a6c488cebb429c4ba83995a26dc2184599af5fd408a361b2e67 as helm

FROM mcr.microsoft.com/devcontainers/base:latest@sha256:41ff7ce12ec45f2704f27a6e091831186ad922ec8112e6339425bfefdf5a70f9
COPY --from=ghcr.io/astral-sh/uv:latest@sha256:d3b601f0c7b118bc1753febf7c41cc80981df678445e0254284eecf84db79a7d /uv /uvx /bin/
COPY --from=golang:latest@sha256:205c7636d74e0ffbe3d007162df7d74f859f5a8c8322dfb9f907977686c126cf /usr/local/go /usr/local/go
ENV PATH="/usr/local/go/bin:${PATH}"

COPY --from=kubectl /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/kubectl
COPY --from=helm /bin/helm /usr/local/bin/helm

ADD https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh k3d_installer.sh
RUN chmod +x k3d_installer.sh && ./k3d_installer.sh

USER vscode

RUN go install golang.stackrox.io/kube-linter/cmd/kube-linter@latest
ENV PATH="/home/vscode/go/bin:${PATH}"

RUN curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
RUN uv tool install ansible-lint
