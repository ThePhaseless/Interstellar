FROM mcr.microsoft.com/devcontainers/base:latest@sha256:aa263c6fdd7c1bc990eead3922224fe8afbf5d85eaf3b6b9260786ab94d74933
COPY --from=ghcr.io/astral-sh/uv:latest@sha256:b1e699368d24c57cda93c338a57a8c5a119009ba809305cc8e86986d4a006754 /uv /uvx /bin/
COPY --from=golang:latest@sha256:fcdb3e42c5544e9682a635771eac76a698b66de79b1b50ec5b9ce5c5f14ad775 /usr/local/go /usr/local/go
ENV PATH="/uv:/usr/local/go/bin:${PATH}"

FROM bitnami/kubectl@sha256:59ad45e8bd79e7af7592ff2852b32adcb0da50792bc52ce44679d5c5f1b4d415 as kubectl
FROM alpine/helm@sha256:4b0bdd2cf18ff6bca12aba0b2c5671384dab5035c19c57f0c58b854a0baf65be as helm

COPY --from=kubectl /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/kubectl
COPY --from=helm /bin/helm /usr/local/bin/helm

ADD https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh k3d_installer.sh
RUN chmod +x k3d_installer.sh && ./k3d_installer.sh

USER vscode

RUN go install golang.stackrox.io/kube-linter/cmd/kube-linter@latest
ENV PATH="/home/vscode/go/bin:${PATH}"

RUN curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
RUN uv tool install ansible-lint
