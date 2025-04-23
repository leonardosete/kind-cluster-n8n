#!/usr/bin/env sh
# Instala os community-nodes no PVC apenas na 1ª execução

set -e

NODES_DIR="/home/node/.n8n/nodes"
mkdir -p "$NODES_DIR"

# garante pnpm
corepack enable && corepack prepare pnpm@latest --activate

if [ ! -d "$NODES_DIR/node_modules" ]; then
  echo "[bootstrap] instalando n8n-nodes-evolution-api e n8n-nodes-python..."
  pnpm add --dir "$NODES_DIR" \
    --dangerously-allow-all-builds \
    n8n-nodes-evolution-api n8n-nodes-python
fi

# entrega para o entrypoint oficial do n8n
exec /docker-entrypoint.sh "$@"
