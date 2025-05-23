#!/usr/bin/env sh
# Instala os community-nodes no PVC apenas na 1ª execução

set -e

NODES_DIR="/home/node/.n8n/custom"
mkdir -p "$NODES_DIR"

# garante pnpm
corepack enable && corepack prepare pnpm@latest --activate

if [ ! -d "$NODES_DIR/node_modules" ]; then
  pnpm add --dir "$NODES_DIR" \
    --dangerously-allow-all-builds --shamefully-hoist \
    n8n-nodes-evolution-api n8n-nodes-python
fi

# entrega para o entrypoint oficial do n8n
exec /docker-entrypoint.sh "$@"
