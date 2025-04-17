#!/bin/bash
set -e

APP_NAME=$1
NAMESPACE=${2:-n8n-vps}  # valor padrão: n8n-vps

if [[ -z "$APP_NAME" ]]; then
  echo "❌ Uso: $0 <nome-do-app> [namespace]"
  echo "Exemplo: $0 gt-dash gt-dash"
  exit 1
fi

ENV_FILE=".chaves/.env-$APP_NAME"
SECRET_NAME="${APP_NAME}-secrets"
PUB_CERT=".chaves/pub-cert.pem"

# 🧠 Calcula caminho correto do OUT_FILE
case "$APP_NAME" in
  evolution-*)
    OUT_FILE="apps/evolution-api/templates/sealedsecret-$APP_NAME.yaml"
    ;;
  n8n)
    OUT_FILE="apps/n8n/templates/sealedsecret-$APP_NAME.yaml"
    ;;
  *)
    OUT_FILE="apps/$APP_NAME/templates/sealedsecret-$APP_NAME.yaml"
    ;;
esac

# ✅ Verificação do .env
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Arquivo $ENV_FILE não encontrado!"
  exit 1
fi

# ✅ Verificação e geração do pub-cert.pem
if [[ ! -f "$PUB_CERT" ]]; then
  echo "🔍 pub-cert.pem não encontrada, buscando do cluster..."
  kubeseal \
    --controller-name=sealed-secrets \
    --controller-namespace=kube-system \
    --fetch-cert > "$PUB_CERT"
  echo "✅ pub-cert.pem salva em $PUB_CERT"
fi

# 🔄 Carrega variáveis
echo "📦 Carregando variáveis do $ENV_FILE..."
set -o allexport
source "$ENV_FILE"
set +o allexport

# 🔧 Monta os argumentos do Secret
# SECRET_ARGS=""
# while IFS='=' read -r key value; do
#   [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
#   rest=$(echo "$line" | cut -d= -f2-)
#   value="${rest%\"}"
#   value="${value#\"}"
#   SECRET_ARGS+=" --from-literal=$key=$value"
# done < <(grep -v '^\s*$' "$ENV_FILE")
SECRET_ARGS=""
while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
  key=$(echo "$line" | cut -d= -f1)
  value=$(echo "$line" | cut -d= -f2-)
  value="${value%\"}"
  value="${value#\"}"
  SECRET_ARGS+=" --from-literal=$key=$value"
done < "$ENV_FILE"

echo -e "\n🔍 Debug - Variáveis lidas:"
echo "$SECRET_ARGS"

# 🛠️ Gera e criptografa
echo "🔐 Gerando Secret Kubernetes em JSON..."
eval kubectl create secret generic "$SECRET_NAME" \
  $SECRET_ARGS \
  --namespace="$NAMESPACE" \
  --dry-run=client -o json > temp-secrets.json

# 🔧 Garante que o diretório de destino exista
mkdir -p "$(dirname "$OUT_FILE")"

echo "🔐 Criptografando com kubeseal..."
kubeseal \
  --cert "$PUB_CERT" \
  --controller-name=sealed-secrets \
  --controller-namespace=kube-system \
  -o yaml < temp-secrets.json > "$OUT_FILE"

rm temp-secrets.json

echo "✅ SealedSecret seguro gerado em $OUT_FILE (namespace: $NAMESPACE)"
