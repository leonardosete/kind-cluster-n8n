#!/usr/bin/env bash
# Gera (ou regenera) SealedSecrets para uma ou mais aplicações.
# Uso:
#   ./generate-sealedsecret-apps.sh evolution-api,evolution-postgres,n8n,n8n-postgres [namespace]

set -euo pipefail

env_usage() {
  echo "❌ Uso: $0 <app1[,app2,...]> [namespace]"
  exit 1
}

[[ $# -lt 1 ]] && env_usage

RAW_APPS=$1
NAMESPACE=${2:-n8n-vps}

############################################
# 1) PREPARA LISTA DE APPS
############################################
IFS=', ' read -ra TMP <<< "$RAW_APPS"
APPS=()
for raw in "${TMP[@]}"; do
  APPS+=("$(echo "$raw" | xargs)")
done

############################################
# 2) FETCH CERTIFICADO ONCE
############################################
SEALED_NS="kube-system"
SEALED_SVC="sealed-secrets"
CERT_TMP=$(mktemp)
kubeseal --controller-namespace="$SEALED_NS" \
         --controller-name="$SEALED_SVC" \
         --fetch-cert > "$CERT_TMP"
trap 'rm -f "$CERT_TMP"' EXIT

############################################
# 3) GERA SEALEDSECRET POR APP
############################################
generate_for_app() {
  APP_NAME=$1
  # define diretório de saída: se app é evolution-postgres, coloca em evolution-api/templates
  if [[ "$APP_NAME" == "evolution-postgres" ]]; then
    OUT_DIR="apps/evolution-api/templates"
  else
    OUT_DIR="apps/${APP_NAME}/templates"
  fi
  OUT_FILE="$OUT_DIR/sealedsecret-${APP_NAME}.yaml"

  mkdir -p "$OUT_DIR"
  rm -f "$OUT_FILE" || true

  declare -A MAP
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
    *)
      echo "❌ Aplicação '${APP_NAME}' não suportada." >&2
      return 1
      ;;
  esac

  # coleta valores e monta args
  args=""
  missing=()
  for KEY in "${!MAP[@]}"; do
    VAR_NAME=${MAP[$KEY]}
    VAL="${!VAR_NAME:-}"
    if [[ -z "$VAL" ]]; then
      missing+=("$VAR_NAME")
    else
      args+=" --from-literal=$KEY=$VAL"
    fi
  done
  if (( ${#missing[@]} )); then
    echo "❌ Variáveis não definidas: ${missing[*]}" >&2
    return 1
  fi

  kubectl create secret generic "${APP_NAME}-secrets" \
    $args -n "$NAMESPACE" --dry-run=client -o json > /tmp/secret.json

  kubeseal -o yaml --cert "$CERT_TMP" \
    --controller-namespace="$SEALED_NS" \
    --controller-name="$SEALED_SVC" \
    < /tmp/secret.json > "$OUT_FILE"

  echo "✅ $OUT_FILE gerado."
}

for APP in "${APPS[@]}"; do
  generate_for_app "$APP"
done

echo "🎉 Todos os SealedSecrets foram gerados com sucesso!"
