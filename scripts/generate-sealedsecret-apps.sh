#!/bin/bash
# Gera (ou regenera) SealedSecrets para uma ou mais aplicações.
# Uso:
#   ./generate-sealedsecret-apps.sh evolution-api,evolution-postgres,n8n,n8n-postgres [namespace]

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
# 2) LISTA DE APPS
############################################
IFS=', ' read -ra TMP <<< "$RAW_APPS"
if [[ ${#TMP[@]} -eq 1 && "$RAW_APPS" == *" "* ]]; then
  TMP=("$@"); TMP=("${TMP[@]:0:${#TMP[@]}-1}")
fi
APPS=(); for raw in "${TMP[@]}"; do APPS+=( "$(echo "$raw" | xargs)" ); done

############################################
# 3) PEGA CERTIFICADO DO CONTROLLER (1x)
############################################
SEALED_NS="kube-system"
SEALED_SVC="sealed-secrets"

CERT_TMP=$(mktemp)
kubeseal --controller-namespace="$SEALED_NS" \
         --controller-name="$SEALED_SVC" \
         --fetch-cert > "$CERT_TMP"
trap 'rm -f "$CERT_TMP"' EXIT

############################################
# 4) FUNÇÃO PARA UMA APP
############################################
generate_for_app () {
  local APP_NAME=$1
  local SECRET_NAME="${APP_NAME}-secrets"
  local OUT_DIR="apps/${APP_NAME}/templates"
  local OUT_FILE="${OUT_DIR}/sealedsecret-${APP_NAME}.yaml"
  mkdir -p "$OUT_DIR"; rm -f "$OUT_FILE" 2>/dev/null || true

  # 4.1) Define DEST → SRC (mapa) e lista de chaves
  declare -A MAP; SECRET_KEYS=""

  case "$APP_NAME" in
    evolution-api)
      MAP=(
        [AUTHENTICATION_API_KEY]=EVOLUTION_API_AUTHENTICATION_API_KEY
        [CACHE_REDIS_URI]=EVOLUTION_API_CACHE_REDIS_URI
        [DATABASE_CONNECTION_URI]=EVOLUTION_API_DATABASE_CONNECTION_URI
        [POSTGRES_DB]=EVOLUTION_POSTGRES_POSTGRES_DB
        [POSTGRES_PASSWORD]=EVOLUTION_POSTGRES_POSTGRES_PASSWORD
        [POSTGRES_USER]=EVOLUTION_POSTGRES_POSTGRES_USER
      )
      ;;
    evolution-postgres)
      MAP=(
        [POSTGRES_DB]=EVOLUTION_POSTGRES_POSTGRES_DB
        [POSTGRES_PASSWORD]=EVOLUTION_POSTGRES_POSTGRES_PASSWORD
        [POSTGRES_USER]=EVOLUTION_POSTGRES_POSTGRES_USER
      )
      ;;
    n8n)
      MAP=(
        [DB_POSTGRESDB_DATABASE]=N8N_POSTGRES_POSTGRES_DB
        [DB_POSTGRESDB_PASSWORD]=N8N_POSTGRES_POSTGRES_PASSWORD
        [DB_POSTGRESDB_USER]=N8N_POSTGRES_POSTGRES_USER
        [N8N_ENCRYPTION_KEY]=N8N_ENCRYPTION_KEY
      )
      ;;
    n8n-postgres)
      MAP=(
        [POSTGRES_DB]=N8N_POSTGRES_POSTGRES_DB
        [POSTGRES_PASSWORD]=N8N_POSTGRES_POSTGRES_PASSWORD
        [POSTGRES_USER]=N8N_POSTGRES_POSTGRES_USER
      )
      ;;
    *) echo "❌ Aplicação '${APP_NAME}' não suportada."; return 1 ;;
  esac

  SECRET_KEYS=$(IFS=','; echo "${!MAP[*]}" | tr ' ' ',')
  local missing=() args=""

  for DEST in "${!MAP[@]}"; do
    SRC=${MAP[$DEST]}
    VAL="${!SRC:-}"
    [[ -z "$VAL" ]] && missing+=("$SRC") || args+=" --from-literal=$DEST=$VAL"
  done
  (( ${#missing[@]} )) && { echo "❌ Variáveis não definidas: ${missing[*]}"; return 1; }

  # 4.2) Cria Secret e sela
  kubectl create secret generic "$SECRET_NAME" $args \
          -n "$NAMESPACE" --dry-run=client -o json > /tmp/secret.json

  kubeseal -o yaml --cert "$CERT_TMP" \
           --controller-namespace="$SEALED_NS" \
           --controller-name="$SEALED_SVC" \
           < /tmp/secret.json > "$OUT_FILE"

  echo "✅ $OUT_FILE gerado."
}

############################################
# 5) LOOP
############################################
for APP in "${APPS[@]}"; do
  generate_for_app "$APP"
done

echo "🎉 Todos os SealedSecrets foram gerados com sucesso!"
