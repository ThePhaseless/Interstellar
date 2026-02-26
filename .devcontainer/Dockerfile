FROM mcr.microsoft.com/devcontainers/base:latest
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
COPY --from=golang:latest /usr/local/go /usr/local/go
ENV PATH="/uv:/usr/local/go/bin:${PATH}"

FROM bitnami/kubectl as kubectl
FROM alpine/helm as helm

COPY --from=kubectl /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/kubectl
COPY --from=helm /bin/helm /usr/local/bin/helm

ADD https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh k3d_installer.sh
RUN chmod +x k3d_installer.sh && ./k3d_installer.sh

USER vscode

RUN go install golang.stackrox.io/kube-linter/cmd/kube-linter@latest
ENV PATH="/home/vscode/go/bin:${PATH}"

RUN curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
RUN uv tool install ansible-lint
