#!/usr/bin/env bash
set -e

# Install Python dependencies if a requirements file exists
if [ -f "requirements.txt" ]; then
  pip install --user -r requirements.txt
fi

# Install Node dependencies if a package.json exists
if [ -f "package.json" ]; then
  npm install
fi

echo ""
echo "Dev container ready."
echo "PostgreSQL: postgresql://postgres:postgres@postgres:5432/app"
echo "MongoDB:    mongodb://mongo:27017/app"
