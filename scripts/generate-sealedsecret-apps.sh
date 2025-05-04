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
# 2) LISTA DE APPS (remove espaços extras)
############################################
IFS=', ' read -ra TMP <<< "$RAW_APPS"
if [[ ${#TMP[@]} -eq 1 && "$RAW_APPS" == *" "* ]]; then
  TMP=("$@"); TMP=("${TMP[@]:0:${#TMP[@]}-1}")
fi
APPS=(); for raw in "${TMP[@]}"; do APPS+=( "$(echo "$raw" | xargs)" ); done

############################################
# 3) CONSTANTES DO CONTROLLER + CERT ÚNICO
############################################
SEALED_NS="kube-system"
SEALED_SVC="sealed-secrets"

CERT_TMP=$(mktemp)
kubeseal --controller-namespace="$SEALED_NS" \
         --controller-name="$SEALED_SVC" \
         --fetch-cert > "$CERT_TMP"
trap 'rm -f "$CERT_TMP"' EXIT   # limpa ao sair

############################################
# 4) FUNÇÃO PARA UMA ÚNICA APP
############################################
generate_for_app () {
  local APP_NAME=$1
  local SECRET_NAME="${APP_NAME}-secrets"
  local OUT_DIR="apps/${APP_NAME}/templates"
  local OUT_FILE="${OUT_DIR}/sealedsecret-${APP_NAME}.yaml"

  echo "🔧 Gerando SealedSecret para '${APP_NAME}' em '${NAMESPACE}'…"
  mkdir -p "$OUT_DIR"; rm -f "$OUT_FILE" 2>/dev/null || true

  # 4.1) Quais chaves entram no Secret?
  case "$APP_NAME" in
    evolution-api)
      SECRET_KEYS="AUTHENTICATION_API_KEY,CACHE_REDIS_URI,DATABASE_CONNECTION_URI,POSTGRES_DB,POSTGRES_PASSWORD,POSTGRES_USER"
      ;;
    evolution-postgres)
      SECRET_KEYS="POSTGRES_DB,POSTGRES_PASSWORD,POSTGRES_USER"
      ;;
    n8n)                                # ⬅️ trocado
      SECRET_KEYS="DB_POSTGRESDB_DATABASE,DB_POSTGRESDB_USER,DB_POSTGRESDB_PASSWORD,N8N_ENCRYPTION_KEY"
      ;;
    n8n-postgres)
      SECRET_KEYS="POSTGRES_DB,POSTGRES_PASSWORD,POSTGRES_USER"
      ;;
    *)
      echo "❌ Aplicação '${APP_NAME}' não suportada."; return 1 ;;
  esac

  # 4.2) Monta argumentos --from-literal
  IFS=',' read -ra KEYS <<< "$SECRET_KEYS"
  local missing=() args=""
  for KEY in "${KEYS[@]}"; do
    VALUE="${!KEY:-}"
    [[ -z "$VALUE" ]] && missing+=("$KEY") || args+=" --from-literal=$KEY=$VALUE"
  done
  (( ${#missing[@]} )) && { echo "❌ Variáveis não definidas: ${missing[*]}"; return 1; }

  # 4.3) Cria Secret (JSON) e sela (usa CERT_TMP)
  kubectl create secret generic "$SECRET_NAME" $args \
          --namespace="$NAMESPACE" --dry-run=client -o json > /tmp/secret-${APP_NAME}.json

  kubeseal --cert "$CERT_TMP" \
           --controller-namespace="$SEALED_NS" \
           --controller-name="$SEALED_SVC" \
           -o yaml < /tmp/secret-${APP_NAME}.json > "$OUT_FILE"

  rm -f /tmp/secret-${APP_NAME}.json
  echo "✅  $OUT_FILE gerado."
}

############################################
# 5) LOOP SOBRE TODAS AS APPS
############################################
for APP in "${APPS[@]}"; do
  generate_for_app "$APP"
done

echo "🎉 Todos os SealedSecrets foram gerados com sucesso!"
