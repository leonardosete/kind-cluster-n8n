#!/bin/bash
set -euo pipefail

APP_NAME=${1:-}
NAMESPACE=${2:-n8n-vps}

if [[ -z "$APP_NAME" ]]; then
  echo "❌ Nome da aplicação não fornecido."
  echo "Uso: $0 <nome-do-app> [namespace]"
  exit 1
fi

SECRET_NAME="${APP_NAME}-secrets"
OUT_DIR="apps/${APP_NAME}/templates"
OUT_FILE="${OUT_DIR}/sealedsecret-${APP_NAME}.yaml"
PUB_CERT="/tmp/pub-cert.pem"

mkdir -p "$OUT_DIR"

# 🧼 Remove arquivo anterior
[[ -f "$OUT_FILE" ]] && rm -f "$OUT_FILE"

# 🔑 Garante que SECRET_KEYS esteja definida
IFS=',' read -ra KEYS <<< "${SECRET_KEYS:?SECRET_KEYS não definida}"

# 🔧 Monta os argumentos do Secret
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
  echo "❌ As seguintes variáveis de ambiente estão vazias ou não definidas:"
  for var in "${missing_vars[@]}"; do echo "   - $var"; done
  exit 1
fi

# 🔐 Busca chave pública do sealed-secrets se necessário
if [[ ! -f "$PUB_CERT" ]]; then
  echo "📥 Tentando obter certificado do sealed-secrets..."
  kubeseal \
    --controller-name=sealed-secrets \
    --controller-namespace=kube-system \
    --fetch-cert | tee "$PUB_CERT"

  echo "🔑 Certificado salvo em: $PUB_CERT"
fi

# ✅ Valida o conteúdo do certificado
if ! openssl x509 -in "$PUB_CERT" -noout >/dev/null 2>&1; then
  echo "❌ Certificado inválido ou corrompido em $PUB_CERT"
  exit 1
fi

# 🧱 Cria Secret temporário
kubectl create secret generic "$SECRET_NAME" $SECRET_ARGS \
  --namespace="$NAMESPACE" \
  --dry-run=client -o json > /tmp/secret-${APP_NAME}.json

# 🔐 Sela o Secret
kubeseal \
  --cert "$PUB_CERT" \
  --controller-name=sealed-secrets \
  --controller-namespace=kube-system \
  -o yaml < /tmp/secret-${APP_NAME}.json > "$OUT_FILE"

echo "✅ SealedSecret gerado com sucesso em: $OUT_FILE"
