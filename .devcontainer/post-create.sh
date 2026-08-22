#!/usr/bin/env bash
set -e

# Install Python dependencies if a requirements file exists
if [ -f "data_generation/pyproject.toml" ]; then
  (cd data_generation && uv sync)
fi

# Install Node dependencies if a package.json exists
if [ -f "mongo/package.json" ]; then
  (cd mongo && npm install)
fi

echo ""
echo "Dev container ready."
echo "PostgreSQL: postgresql://postgres:postgres@postgres:5432/app"
echo "MongoDB:    mongodb://mongo:27017/app"
