#!/bin/bash
# Gera (ou regenera) SealedSecrets para uma ou mais aplicações.
# Uso:
#   ./generate-sealedsecret-apps.sh evolution-api,evolution-postgres  [namespace]
#   ./generate-sealedsecret-apps.sh evolution-api evolution-postgres  [namespace]

set -euo pipefail

############################################
# 1) PARÂMETROS
############################################
[[ $# -lt 1 ]] && {
  echo "❌ Uso: $0 <app1[,app2,...]> [namespace]"
  exit 1
}

RAW_APPS=$1
NAMESPACE=${2:-n8n-vps}

############################################
# 2) MONTA ARRAY "APPS" JÁ SANITIZADA
############################################
IFS=', ' read -ra TMP <<< "$RAW_APPS"
if [[ ${#TMP[@]} -eq 1 && "$RAW_APPS" == *" "* ]]; then
  TMP=("$@"); TMP=("${TMP[@]:0:${#TMP[@]}-1}")
fi
APPS=(); for raw in "${TMP[@]}"; do APPS+=( "$(echo "$raw" | xargs)" ); done

############################################
# 3) FUNÇÃO PARA UM ÚNICO APP
############################################
generate_for_app () {
  local APP_NAME=$1
  local SECRET_NAME="${APP_NAME}-secrets"
  local OUT_DIR="apps/${APP_NAME}/templates"
  local OUT_FILE="${OUT_DIR}/sealedsecret-${APP_NAME}.yaml"

  echo "🔧 Gerando SealedSecret para '${APP_NAME}' no namespace '${NAMESPACE}'…"
  mkdir -p "$OUT_DIR"; rm -f "$OUT_FILE" 2>/dev/null || true

  # 3.1) Define SECRET_KEYS
  case "$APP_NAME" in
    evolution-api)
      SECRET_KEYS="EVOLUTION_API_AUTHENTICATION_API_KEY,EVOLUTION_API_CACHE_REDIS_URI,EVOLUTION_API_DATABASE_CONNECTION_URI,EVOLUTION_API_POSTGRES_DB,EVOLUTION_API_POSTGRES_PASSWORD,EVOLUTION_API_POSTGRES_USER"
      ;;
    evolution-postgres)
      SECRET_KEYS="EVOLUTION_POSTGRES_POSTGRES_DB,EVOLUTION_POSTGRES_POSTGRES_PASSWORD,EVOLUTION_POSTGRES_POSTGRES_USER"
      ;;
    n8n)
      SECRET_KEYS="N8N_DB_POSTGRESDB_DATABASE,N8N_DB_POSTGRESDB_PASSWORD,N8N_DB_POSTGRESDB_USER,N8N_ENCRYPTION_KEY"
      ;;
    n8n-postgres)
      SECRET_KEYS="N8N_POSTGRES_POSTGRES_DB,N8N_POSTGRES_POSTGRES_PASSWORD,N8N_POSTGRES_POSTGRES_USER"
      ;;
    *)
      echo "❌ Aplicação '${APP_NAME}' não suportada."; return 1 ;;
  esac

  # 3.2) Monta argumentos --from-literal
  IFS=',' read -ra KEYS <<< "$SECRET_KEYS"
  local missing=() secret_args=""
  for KEY in "${KEYS[@]}"; do
    VALUE="${!KEY:-}"
    [[ -z "$VALUE" ]] && missing+=("$KEY") || secret_args+=" --from-literal=$KEY=$VALUE"
  done
  (( ${#missing[@]} )) && { echo "❌ Variáveis não definidas: ${missing[*]}"; return 1; }

  # 3.3) Sempre usa o certificado atual do controller
  SEALED_NS=$(kubectl get pods -A -l app.kubernetes.io/name=sealed-secrets \
               -o jsonpath='{.items[0].metadata.namespace}')
  CERT_TMP=$(mktemp)
  kubeseal --controller-namespace="$SEALED_NS" --fetch-cert > "$CERT_TMP"

  # 3.4) Cria, sela e grava
  kubectl create secret generic "$SECRET_NAME" $secret_args \
          --namespace="$NAMESPACE" --dry-run=client -o json > /tmp/secret-${APP_NAME}.json

  kubeseal -o yaml --cert "$CERT_TMP" \
           --controller-namespace="$SEALED_NS" \
           < /tmp/secret-${APP_NAME}.json > "$OUT_FILE"

  rm -f "$CERT_TMP" /tmp/secret-${APP_NAME}.json
  echo "✅ SealedSecret salvo em: $OUT_FILE"
}

############################################
# 4) LOOP SOBRE TODAS AS APPS
############################################
for APP in "${APPS[@]}"; do
  generate_for_app "$APP"
done

echo "🎉 Todos os SealedSecrets foram gerados com sucesso!"
