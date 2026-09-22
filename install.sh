#!/usr/bin/env bash
set -euo pipefail

command -v docker >/dev/null || { echo 'Docker is required'; exit 1; }
docker compose version >/dev/null 2>&1 || { echo 'Docker Compose v2 is required'; exit 1; }

if [ ! -f config.yaml ]; then
  cp config.example.yaml config.yaml
  echo 'Created config.yaml; review it before starting.'
fi

docker compose pull
docker compose up -d
docker compose ps
