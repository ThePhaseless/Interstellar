FROM bitnami/kubectl@sha256:8f59408f9e896fc8992a0660a56687545bd06751f26531b4a26fca6d5dc7562d as kubectl
FROM alpine/helm@sha256:e3f8d5c462d75470fbb1fce79ad5c20063657096d1f98c0fcea869e2600e2e5e as helm

FROM mcr.microsoft.com/devcontainers/base:latest@sha256:71b6fe7c4e07ec747a94a72b2a17f2f8c286eaa7b1c59862888df764efb8b6c6
COPY --from=ghcr.io/astral-sh/uv:latest@sha256:96f40d3904aad8d0bd010539001d36c8e2188b981e1334471a90c4a1d93bb490 /uv /uvx /bin/
COPY --from=golang:latest@sha256:2920bb124f1a2e12a1d39f0cab756ae0068441ee1da7655dec7f5e374944095b /usr/local/go /usr/local/go
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
