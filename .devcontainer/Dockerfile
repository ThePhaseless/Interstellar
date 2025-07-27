FROM mcr.microsoft.com/devcontainers/base:latest
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
COPY --from=golang:latest /usr/local/go /usr/local/go
ENV PATH="/uv:/usr/local/go/bin:${PATH}"

ADD https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh k3d_installer.sh
RUN chmod +x k3d_installer.sh && ./k3d_installer.sh

USER vscode
