#!/usr/bin/env bash
set -e

# diretório do PVC
NODES_DIR="/home/node/.n8n/nodes"

# garante que a pasta exista no PVC
mkdir -p "$NODES_DIR"

# ativa pnpm (caso Corepack ainda não tenha baixado binário)
corepack enable && corepack prepare pnpm@latest --activate

# instala apenas se ainda não houver node_modules
if [ ! -d "$NODES_DIR/node_modules" ]; then
  echo "[bootstrap] Instalando n8n-nodes-evolution-api e n8n-nodes-python..."
  pnpm add --dir "$NODES_DIR" \
    --allow-scripts=n8n-nodes-evolution-api,n8n-nodes-python \
    n8n-nodes-evolution-api n8n-nodes-python
fi

# entrega para o entrypoint original do n8n
exec /docker-entrypoint.sh "$@"
