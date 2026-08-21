FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Python and Node.js are installed via devcontainer "features" in devcontainer.json.
# This just adds the psql CLI for talking to the postgres container from a terminal.
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*
