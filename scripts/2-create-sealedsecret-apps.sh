#!/bin/bash
# generate-sealedsecret-apps.sh
# Gera e sela um Secret Kubernetes a partir de variáveis de ambiente
# ou de um .env-$APP_NAME legado, produzindo sealedsecret-$APP_NAME.yaml
set -euo pipefail

APP_NAME=${1:-}
NAMESPACE=${2:-n8n-vps}        # Namespace default
[[ -z "$APP_NAME" ]] && {
  echo "❌ Uso: $0 <app_name> [namespace]"
  exit 1
}

PUB_CERT=".chaves/pub-cert.pem"
SECRET_NAME="${APP_NAME}-secrets"

# ──────────────────────────────
# 1️⃣ Resolve caminho de saída
# ──────────────────────────────
case "$APP_NAME" in
  evolution-*)
    OUT_FILE="apps/evolution-api/templates/sealedsecret-${APP_NAME}.yaml"
    ;;
  n8n)
    OUT_FILE="apps/n8n/templates/sealedsecret-${APP_NAME}.yaml"
    ;;
  *)
    OUT_FILE="apps/${APP_NAME}/templates/sealedsecret-${APP_NAME}.yaml"
    ;;
esac
mkdir -p "$(dirname "$OUT_FILE")"

# Remove artefato antigo
[[ -f "$OUT_FILE" ]] && { echo "🗑️  Removendo $OUT_FILE antigo…"; rm -f "$OUT_FILE"; }

# ──────────────────────────────
# 2️⃣ Monta argumentos do Secret
# ──────────────────────────────
SECRET_ARGS=""

if [[ -n "${SECRET_KEYS:-}" ]]; then
  echo "🔑 Lendo chaves a partir de variáveis de ambiente: $SECRET_KEYS"
  IFS=',' read -ra KEYS <<< "$SECRET_KEYS"
  for key in "${KEYS[@]}"; do
    value="${!key:-}"
    [[ -z "$value" ]] && {
      echo "⚠️  Variável $key não definida – abortando."
      exit 1
    }
    SECRET_ARGS+=" --from-literal=${key}=${value}"
  done
else
  ENV_FILE=".chaves/.env-${APP_NAME}"
  [[ ! -f "$ENV_FILE" ]] && {
    echo "❌ Nem SECRET_KEYS nem $ENV_FILE encontrados."
    exit 1
  }
  echo "📦 Carregando variáveis do $ENV_FILE (modo legado)…"
  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    key=$(echo "$line" | cut -d= -f1)
    value=$(echo "$line" | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//')
    SECRET_ARGS+=" --from-literal=${key}=${value}"
  done < "$ENV_FILE"
fi

# ──────────────────────────────
# 3️⃣ Garante pub-cert.pem
# ──────────────────────────────
if [[ ! -f "$PUB_CERT" ]]; then
  echo "🔍 Baixando cert público do controller Sealed-Secrets…"
  kubeseal                                 \
    --controller-name=sealed-secrets       \
    --controller-namespace=kube-system     \
    --fetch-cert > "$PUB_CERT"
  echo "✅ Cert salvo em $PUB_CERT"
fi

# ──────────────────────────────
# 4️⃣ Cria Secret JSON e sela
# ──────────────────────────────
echo "🔐 Gerando Secret temporário…"
eval kubectl create secret generic "$SECRET_NAME" \
  $SECRET_ARGS                                   \
  --namespace="$NAMESPACE"                       \
  --dry-run=client -o json > /tmp/secret.json

echo "🔐 Selando com kubeseal…"
kubeseal                                         \
  --cert "$PUB_CERT"                             \
  --controller-name=sealed-secrets               \
  --controller-namespace=kube-system             \
  -o yaml < /tmp/secret.json > "$OUT_FILE"

rm -f /tmp/secret.json

echo "✅ SealedSecret salvo em $OUT_FILE (namespace: $NAMESPACE)"
