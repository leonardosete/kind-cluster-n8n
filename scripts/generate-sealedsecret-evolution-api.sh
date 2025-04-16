#!/bin/bash

set -e

APP_NAME=$1

if [[ -z "$APP_NAME" ]]; then
  echo "❌ Uso: $0 <nome-do-app>"
  echo "Exemplo: $0 evolution-api"
  exit 1
fi

APP_PATH="apps/$APP_NAME"
ENV_FILE=".chaves/.env-$APP_NAME"
SECRET_NAME="${APP_NAME}-secrets"
NAMESPACE="n8n-vps"
OUT_FILE="$APP_PATH/sealedsecret-$APP_NAME.yaml"
PUB_CERT=".chaves/pub-cert.pem"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Arquivo $ENV_FILE não encontrado em $APP_PATH"
  exit 1
fi

if [[ ! -f "$PUB_CERT" ]]; then
  echo "🔍 pub-cert.pem não encontrada, buscando do cluster..."
  kubeseal --fetch-cert --controller-name=sealed-secrets --controller-namespace=kube-system > "$PUB_CERT"
  echo "✅ pub-cert.pem salva localmente"
fi

echo "📦 Carregando variáveis do $ENV_FILE..."
set -o allexport
source "$ENV_FILE"
set +o allexport

# Monta argumentos do kubectl create secret dinamicamente
SECRET_ARGS=""
while read -r line; do
  key=$(echo "$line" | cut -d= -f1)
  value=$(echo "$line" | cut -d= -f2-)
  SECRET_ARGS+=" --from-literal=$key=\"$value\""
done < <(grep -v '^#' "$ENV_FILE")

echo "🔐 Gerando Secret Kubernetes em JSON..."
eval kubectl create secret generic "$SECRET_NAME" \
  $SECRET_ARGS \
  --namespace=$NAMESPACE \
  --dry-run=client -o json > temp-secret.json

echo "🔐 Criptografando com kubeseal..."
kubeseal --cert "$PUB_CERT" -o yaml < temp-secret.json > "$OUT_FILE"

rm temp-secret.json

echo "✅ SealedSecret seguro gerado em $OUT_FILE"
