#!/bin/bash
# Gera (ou regenera) SealedSecrets para uma OU MAIS aplicações
# Uso:
#   ./generate-sealedsecret-apps.sh evolution-api,evolution-postgres  [namespace]
#   ./generate-sealedsecret-apps.sh evolution-api evolution-postgres  [namespace]

set -euo pipefail

############################################
# 1) PARÂMETROS
############################################
if [[ $# -lt 1 ]]; then
  echo "❌ Uso: $0 <app1[,app2,...]> [namespace]"
  exit 1
fi

RAW_APPS=$1
NAMESPACE=${2:-n8n-vps}

# Permite tanto vírgula quanto espaço
IFS=',' read -ra APPS <<< "$RAW_APPS"
if [[ ${#APPS[@]} -eq 1 && "$RAW_APPS" == *" "* ]]; then
  # separador por espaço
  APPS=("$@")
  APPS=("${APPS[@]:0:${#APPS[@]}-1}") # remove último arg se for namespace
fi

############################################
# 2) FUNÇÃO PARA UM ÚNICO APP
############################################
generate_for_app () {
  local APP_NAME=$1          # ex.: evolution-api
  local SECRET_NAME="${APP_NAME}-secrets"
  local OUT_DIR="apps/${APP_NAME}/templates"
  local OUT_FILE="${OUT_DIR}/sealedsecret-${APP_NAME}.yaml"
  local PUB_CERT="/tmp/pub-cert.pem"

  echo "🔧 Gerando SealedSecret para '${APP_NAME}' no namespace '${NAMESPACE}' …"
  mkdir -p "$OUT_DIR"
  [[ -f "$OUT_FILE" ]] && rm -f "$OUT_FILE"

  # ----------------------------------------
  # 2.1) Define SECRET_KEYS por aplicação
  #      (você pode mover este bloco para
  #       fora se já vier do workflow)
  # ----------------------------------------
  case "$APP_NAME" in
    evolution-api)
      SECRET_KEYS="EVOLUTION_API_AUTHENTICATION_API_KEY,EVOLUTION_API_CACHE_REDIS_URI,EVOLUTION_API_DATABASE_CONNECTION_URI,EVOLUTION_API_POSTGRES_DB,EVOLUTION_API_POSTGRES_PASSWORD,EVOLUTION_API_POSTGRES_USER"
      ;;
    evolution-postgres)
      SECRET_KEYS="EVOLUTION_POSTGRES_POSTGRES_DB,EVOLUTION_POSTGRES_POSTGRES_PASSWORD,EVOLUTION_POSTGRES_POSTGRES_USER"
      ;;
    *)
      echo "❌ Aplicação '${APP_NAME}' não suportada."; return 1 ;;
  esac

  # ----------------------------------------
  # 2.2) Monta argumentos --from-literal
  # ----------------------------------------
  IFS=',' read -ra KEYS <<< "$SECRET_KEYS"
  local missing_vars=()
  local SECRET_ARGS=""

  for KEY in "${KEYS[@]}"; do
    VALUE="${!KEY:-}"
    if [[ -z "$VALUE" ]]; then
      missing_vars+=("$KEY")
    else
      SECRET_ARGS+=" --from-literal=$KEY=$VALUE"
    fi
  done

  if (( ${#missing_vars[@]} > 0 )); then
    echo "❌ Variáveis não definidas: ${missing_vars[*]}"
    return 1
  fi

  # ----------------------------------------
  # 2.3) Obtém (ou reutiliza) certificado
  # ----------------------------------------
  if [[ ! -f "$PUB_CERT" ]]; then
    echo "📥 Baixando certificado do sealed-secrets …"
    kubeseal --controller-name=sealed-secrets \
             --controller-namespace=kube-system \
             --fetch-cert > "$PUB_CERT"
  fi
  openssl x509 -in "$PUB_CERT" -noout >/dev/null

  # ----------------------------------------
  # 2.4) Cria, sela e grava arquivo
  # ----------------------------------------
  kubectl create secret generic "$SECRET_NAME" $SECRET_ARGS \
          --namespace="$NAMESPACE" \
          --dry-run=client -o json > /tmp/secret-${APP_NAME}.json

  kubeseal -o yaml \
           --cert "$PUB_CERT" \
           --controller-name=sealed-secrets \
           --controller-namespace=kube-system \
           < /tmp/secret-${APP_NAME}.json > "$OUT_FILE"

  echo "✅ SealedSecret salvo em: $OUT_FILE"
}

############################################
# 3) LOOP SOBRE TODAS AS APPS
############################################
for APP in "${APPS[@]}"; do
  generate_for_app "$APP"
done
echo "✅ Todos os SealedSecrets foram gerados com sucesso!"