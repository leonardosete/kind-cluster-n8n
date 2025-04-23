#!/usr/bin/env sh
# Bootstrap: instala os community-nodes na primeira vez

set -e

NODES_DIR="/home/node/.n8n/nodes"
mkdir -p "$NODES_DIR"

# garante pnpm disponível
corepack enable && corepack prepare pnpm@latest --activate

if [ ! -d "$NODES_DIR/node_modules" ]; then
  echo "[bootstrap] instalando n8n-nodes-evolution-api e n8n-nodes-python"
  pnpm add --dir "$NODES_DIR" \
    --allow-scripts=n8n-nodes-evolution-api,n8n-nodes-python \
    n8n-nodes-evolution-api n8n-nodes-python
fi

# chama o entrypoint original da imagem
exec /docker-entrypoint.sh "$@"
