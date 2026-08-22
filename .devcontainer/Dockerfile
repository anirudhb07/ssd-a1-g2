FROM mcr.microsoft.com/devcontainers/base:ubuntu

# PostgreSQL client + MongoDB Shell (mongosh), installed directly via apt
# instead of devcontainer features (avoids the mongosh-homebrew feature,
# which builds Homebrew from source and can hang/take 10+ minutes).
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        postgresql-client \
    && curl -fsSL https://pgp.mongodb.com/server-8.0.asc | gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor \
    && echo "deb [ arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/8.0 multiverse" \
        | tee /etc/apt/sources.list.d/mongodb-org-8.0.list \
    && apt-get update && apt-get install -y --no-install-recommends mongodb-mongosh \
    && rm -rf /var/lib/apt/lists/*

# uv: fast Python package manager, installed directly via the official
# installer (avoids the uv devcontainer feature's GitHub Releases lookup,
# which can stall or hit GitHub's API rate limit on repeated builds).
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh
