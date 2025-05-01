#!/bin/bash
set -euo pipefail

APP_NAME=${1:-}
NAMESPACE=${2:-n8n-vps}

if [[ -z "$APP_NAME" ]]; then
  echo "❌ Nome da aplicação não fornecido."
  echo "Uso: $0 <nome-do-app> [namespace]"
  exit 1
fi

ENV_FILE=".chaves/.env-${APP_NAME}"
SECRET_NAME="${APP_NAME}-secrets"
PUB_CERT=".chaves/pub-cert.pem"
OUT_DIR="apps/${APP_NAME}/templates"
OUT_FILE="${OUT_DIR}/sealedsecret-${APP_NAME}.yaml"

# 📂 Verifica se arquivo .env existe
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Arquivo de variáveis não encontrado: $ENV_FILE"
  exit 1
fi

# 🔄 Carrega variáveis
set -o allexport
source "$ENV_FILE"
set +o allexport

# 🧹 Remove arquivo anterior se existir
mkdir -p "$OUT_DIR"
[[ -f "$OUT_FILE" ]] && rm -f "$OUT_FILE"

# 🛑 Verifica se variáveis necessárias estão definidas
IFS=',' read -ra KEYS <<< "${SECRET_KEYS:?SECRET_KEYS não definida}"

missing_vars=()
SECRET_ARGS=""

for KEY in "${KEYS[@]}"; do
  VALUE="${!KEY:-}"
  if [[ -z "$VALUE" ]]; then
    missing_vars+=("$KEY")
  else
    SECRET_ARGS+=" --from-literal=$KEY=$VALUE"
  fi
done

if (( ${#missing_vars[@]} > 0 )); then
  echo "❌ As seguintes variáveis estão ausentes ou vazias no arquivo $ENV_FILE:"
  for var in "${missing_vars[@]}"; do
    echo "   - $var"
  done
  exit 1
fi

# 🔐 Garante chave pública do Sealed Secrets
if [[ ! -f "$PUB_CERT" ]]; then
  echo "📥 Obtendo chave pública do cluster..."
  kubeseal --fetch-cert --controller-namespace sealed-secrets > "$PUB_CERT"
fi

# 🧱 Gera Secret temporário
kubectl create secret generic "$SECRET_NAME" $SECRET_ARGS \
  --namespace="$NAMESPACE" \
  --dry-run=client -o json > /tmp/secret-${APP_NAME}.json

# 🔐 Sela o Secret
kubeseal --cert "$PUB_CERT" -o yaml < /tmp/secret-${APP_NAME}.json > "$OUT_FILE"

echo "✅ SealedSecret gerado com sucesso em: $OUT_FILE"
