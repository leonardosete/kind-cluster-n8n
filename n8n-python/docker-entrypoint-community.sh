#!/usr/bin/env sh          # ← use sh, não bash
set -e

NODES_DIR="/home/node/.n8n/nodes"
mkdir -p "$NODES_DIR"

# habilita pnpm
corepack enable && corepack prepare pnpm@latest --activate

if [ ! -d "$NODES_DIR/node_modules" ]; then
  echo "[bootstrap] instalando community-nodes"
  pnpm add --dir "$NODES_DIR" \
    --allow-scripts=n8n-nodes-evolution-api,n8n-nodes-python \
    n8n-nodes-evolution-api n8n-nodes-python
fi

# chama o entrypoint original
exec /docker-entrypoint.sh "$@"
