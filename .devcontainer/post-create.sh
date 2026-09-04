#!/usr/bin/env bash
set -e

# uv and node come from devenv (see devenv.nix), not from the image's PATH.
# If they are not visible, re-run this whole script inside the devenv
# environment. A bare `devenv shell` line does NOT work here: it starts an
# interactive subshell, which in a non-interactive postCreate either hangs or
# exits, and in either case its PATH is discarded before the next line runs.
#
# DEVENV_REENTERED guards against looping if the devenv shell still lacks uv.
if ! command -v uv >/dev/null 2>&1; then
  if [ -n "$DEVENV_REENTERED" ]; then
    echo "uv is not available even inside 'devenv shell'. Check devenv.nix."
    exit 1
  fi
  echo "uv not on PATH; re-entering under devenv shell..."
  export DEVENV_REENTERED=1
  exec devenv shell -- bash "$0" "$@"
fi

# Python dependencies.
#
# The workspace is bind-mounted from the host, so data_generation/.venv may
# have been created by a different OS (a Windows host running `uv run`) or
# against a different interpreter. Either way it will not work in here, and uv
# will happily reuse a broken venv rather than replace it. Test it and rebuild
# if it cannot import the standard library.
if [ -f "data_generation/pyproject.toml" ]; then
  (
    cd data_generation

    if [ -x .venv/bin/python ] && ! .venv/bin/python -c "import uuid" >/dev/null 2>&1; then
      echo "Discarding unusable data_generation/.venv (stale or built elsewhere)."
      rm -rf .venv
    fi

    uv sync

    # Fail container creation loudly here rather than partway through a
    # 500k-document seed. Each of these has bitten this project at least once.
    uv run python -c "import uuid, psycopg2, pymongo, faker" \
      || { echo "Python environment is broken; check languages.python in devenv.nix."; exit 1; }
  )
fi

# Node dependencies. Only the mongosh type-checking harness needs these; the
# .js files are run by mongosh, not node.
if [ -f "mongo/package.json" ]; then
  (cd mongo && npm install)
fi

# Auto-activate devenv in every new terminal.
#
# The image already hooks direnv into ~/.bashrc, but ships no direnvrc, so
# `use devenv` in .envrc would not resolve on its own. `devenv direnvrc` emits
# one (a nix-direnv derivative with layout caching) -- no network fetch and no
# pinned hash to rot, unlike the source_url line `devenv init` scaffolds.
#
# Both of these live in the container's home directory, not the bind-mounted
# workspace, so they must be re-done on every rebuild -- hence doing it here
# rather than by hand.
if command -v devenv >/dev/null 2>&1 && command -v direnv >/dev/null 2>&1; then
  mkdir -p "$HOME/.config/direnv"
  devenv direnvrc > "$HOME/.config/direnv/direnvrc"
  # Trust this workspace's .envrc. Without it direnv refuses to load and just
  # prints a "direnv: error .envrc is blocked" line on every prompt.
  direnv allow "${PWD}" || echo "WARNING: 'direnv allow' failed; run it by hand in /workspace."
else
  echo "WARNING: devenv or direnv not found; terminals will not auto-activate."
fi

echo ""
echo "Dev container ready."
echo "PostgreSQL: postgresql://postgres:postgres@postgres:5432/app"
echo "MongoDB:    mongodb://mongo:27017/app"
