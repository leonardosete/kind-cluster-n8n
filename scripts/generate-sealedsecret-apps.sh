#!/usr/bin/env bash
# versão “ENV-only”, compatível Bash 3.2
set -euo pipefail
APP_NAME=${1:-}; NAMESPACE=${2:-n8n-vps}
[[ -z "$APP_NAME" ]] && { echo "uso: $0 <app>"; exit 1; }

SECRET_NAME="${APP_NAME}-secrets"
PUB_CERT=".chaves/pub-cert.pem"
OUT_DIR="apps/${APP_NAME}/templates"
[ "$APP_NAME" = "evolution-api" ] && OUT_DIR="apps/evolution-api/templates"
[ "$APP_NAME" = "n8n" ]           && OUT_DIR="apps/n8n/templates"
mkdir -p "$OUT_DIR"; OUT_FILE="$OUT_DIR/sealedsecret-${APP_NAME}.yaml"

# remove artefato antigo
[ -f "$OUT_FILE" ] && rm -f "$OUT_FILE"

# prepara argumentos a partir de SECRET_KEYS
IFS=',' read -ra KEYS <<< "${SECRET_KEYS:?SECRET_KEYS não definida}"
SECRET_ARGS=""
for k in "${KEYS[@]}"; do
  v="${!k:?variável $k vazia}"; SECRET_ARGS+=" --from-literal=$k=$v"
done

# 🆕 ▸ garante que a pasta .chaves exista
mkdir -p "$(dirname "$PUB_CERT")"

# 🆕 ▸ busca o cert se ainda não existir
[ ! -f "$PUB_CERT" ] && kubeseal --fetch-cert > "$PUB_CERT"

# cria, sela, grava
eval kubectl create secret generic "$SECRET_NAME" $SECRET_ARGS \
  --namespace="$NAMESPACE" --dry-run=client -o json > /tmp/secret.json
kubeseal --cert "$PUB_CERT" -o yaml < /tmp/secret.json > "$OUT_FILE"
echo "✅ SealedSecret gerado em $OUT_FILE"
