#!/usr/bin/env bash
# Gera (ou regenera) SealedSecrets para uma ou mais aplicações, com DEBUG detalhado.
# Uso:
#   ./generate-sealedsecret-apps.sh evolution-api,evolution-postgres,n8n,n8n-postgres [namespace]

set -euxo pipefail

############################################
# 1) PARÂMETROS
############################################
[[ $# -lt 1 ]] && {
  echo "❌ Uso: $0 <app1[,app2,...]> [namespace]"
  exit 1
}

RAW_APPS=$1
NAMESPACE=${2:-n8n-vps}

echo "🧩 RAW_APPS='${RAW_APPS}', NAMESPACE='${NAMESPACE}'"

############################################
# 2) LISTA DE APPS
############################################
IFS=', ' read -ra TMP <<< "${RAW_APPS}"
if [[ ${#TMP[@]} -eq 1 && "${RAW_APPS}" == *" "* ]]; then
  TMP=("$@"); TMP=("${TMP[@]:0:${#TMP[@]}-1}")
fi
APPS=(); for raw in "${TMP[@]}"; do APPS+=( "$(echo "${raw}" | xargs)" ); done

echo "🧩 APPS to generate: ${APPS[*]}"

############################################
# 3) PEGA CERTIFICADO DO CONTROLLER (1x)
############################################
SEALED_NS="kube-system"
SEALED_SVC="sealed-secrets"

CERT_TMP=$(mktemp)
kubeseal --controller-namespace="${SEALED_NS}" \
         --controller-name="${SEALED_SVC}" \
         --fetch-cert > "${CERT_TMP}"
trap 'rm -f "${CERT_TMP}"' EXIT

echo "🔐 Seal-cert fetched to ${CERT_TMP}"

############################################
# 4) FUNÇÃO PARA UMA APP
############################################
generate_for_app () {
  local APP_NAME=$1
  echo "🧩 Processing generate_for_app('$APP_NAME')"
  local SECRET_NAME="${APP_NAME}-secrets"
  local OUT_DIR="apps/${APP_NAME}/templates"
  local OUT_FILE="${OUT_DIR}/sealedsecret-${APP_NAME}.yaml"
  mkdir -p "${OUT_DIR}"; rm -f "${OUT_FILE}" || true

  # 4.1) Define DEST → SRC (mapa) e lista de chaves
  declare -A MAP
  case "${APP_NAME}" in
    evolution-api)
      echo "📦 Mapping variables for evolution-api"
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
      echo "📦 Mapping variables for evolution-postgres"
      MAP=(
        [POSTGRES_DB]=EVOLUTION_POSTGRES_POSTGRES_DB
        [POSTGRES_PASSWORD]=EVOLUTION_POSTGRES_POSTGRES_PASSWORD
        [POSTGRES_USER]=EVOLUTION_POSTGRES_POSTGRES_USER
      )
      ;;
    n8n)
      echo "📦 Mapping variables for n8n"
      MAP=(
        [DB_POSTGRESDB_DATABASE]=N8N_POSTGRES_POSTGRES_DB
        [DB_POSTGRESDB_PASSWORD]=N8N_POSTGRES_POSTGRES_PASSWORD
        [DB_POSTGRESDB_USER]=N8N_POSTGRES_POSTGRES_USER
        [N8N_ENCRYPTION_KEY]=N8N_ENCRYPTION_KEY
      )
      ;;
    n8n-postgres)
      echo "📦 Mapping variables for n8n-postgres"
      MAP=(
        [POSTGRES_DB]=N8N_POSTGRES_POSTGRES_DB
        [POSTGRES_PASSWORD]=N8N_POSTGRES_POSTGRES_PASSWORD
        [POSTGRES_USER]=N8N_POSTGRES_POSTGRES_USER
      )
      ;;
    *)
      echo "❌ App desconhecido passado: ${APP_NAME}" >&2
      return 1
      ;;
  esac

  echo "🔐 Checking mapped vars for ${APP_NAME}:"
  local missing=() args=""
  for DEST in "${!MAP[@]}"; do
    SRC=${MAP[$DEST]}
    VAL="${!SRC:-}"
    echo "   - ${DEST} ← \${${SRC}} = '${VAL}'"
    if [[ -z "${VAL}" ]]; then
      missing+=("${SRC}")
    else
      args+=" --from-literal=${DEST}=${VAL}"
    fi
  done
  if (( ${#missing[@]} )); then
    echo "❌ Variáveis não definidas para ${APP_NAME}: ${missing[*]}" >&2
    return 1
  fi

  # 4.2) Cria Secret e sela
  echo "💾 Creating k8s Secret '${SECRET_NAME}' in namespace '${NAMESPACE}'"
  kubectl create secret generic "${SECRET_NAME}" ${args} \
          -n "${NAMESPACE}" --dry-run=client -o json > /tmp/secret.json

  echo "🔐 Sealing secret to ${OUT_FILE}"
  kubeseal -o yaml --cert "${CERT_TMP}" \
           --controller-namespace="${SEALED_NS}" \
           --controller-name="${SEALED_SVC}" \
           < /tmp/secret.json > "${OUT_FILE}"

  echo "✅ ${OUT_FILE} gerado."
}

############################################
# 5) LOOP DE GERAÇÃO
############################################
echo "🎬 Starting loop over APPS"
for APP in "${APPS[@]}"; do
  generate_for_app "${APP}"
done

echo "🎉 Todos os SealedSecrets foram gerados com sucesso!"
