FROM bitnami/kubectl@sha256:8919c149c2e3d6860e0143c117900e64d71395172aaef0e01e604bb98c8e7ce0 as kubectl
FROM alpine/helm@sha256:a3b9d617c0c30a6c488cebb429c4ba83995a26dc2184599af5fd408a361b2e67 as helm

FROM mcr.microsoft.com/devcontainers/base:latest@sha256:38f9e6c291f054e3c868d95a5477cbfcf76c0fa7c218dda65dc6aa3fbfe06871
COPY --from=ghcr.io/astral-sh/uv:latest@sha256:5cc1805e2426484abca4ad46ea783bab281fdb225fd82d8ce6d66a81254bac85 /uv /uvx /bin/
COPY --from=golang:latest@sha256:ec47ea3725fea0cc88f6de94919aef19f40f12fc1ec0e2d1b3426dbf15ecca04 /usr/local/go /usr/local/go
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
