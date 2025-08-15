#!/bin/bash
set -euo pipefail

# ========================== CONFIGURAÇÕES ==========================
SSH_KEY="${SSH_KEY:-$HOME/.ssh/nova_vps_srv809140}"
ENV_FILE="$HOME/kind-cluster-n8n/.chaves/.env-GH_PAT_RUNNER"
REMOTE_SCRIPT="$(dirname "$0")/1-remote-setup-runner.sh"
REPO_USER="leonardosete"
RUNNER_VERSION="2.323.0"
TEMPLATE_ID=1031
MAX_RETRIES=30
SLEEP_INTERVAL=15

[[ -z "${VPS_API_TOKEN:-}" || -z "${VPS_ROOT_PASS:-}" ]] && {
  echo "❌ Variáveis VPS_API_TOKEN ou VPS_ROOT_PASS não definidas. Execute: source ~/.zshenv"
  exit 1
}

[[ ! -f "$ENV_FILE" ]] && {
  echo "❌ Arquivo $ENV_FILE não encontrado!"
  exit 1
}

[[ ! -f "$REMOTE_SCRIPT" ]] && {
  echo "❌ Script remoto '$REMOTE_SCRIPT' não encontrado!"
  exit 1
}

GH_PAT_RUNNER=$(grep '^GH_PAT_RUNNER=' "$ENV_FILE" | cut -d '=' -f2-)
[[ -z "$GH_PAT_RUNNER" ]] && {
  echo "❌ GH_PAT_RUNNER vazio ou ausente em $ENV_FILE"
  exit 1
}

echo "🔍 Buscando VPS disponíveis..."
response=$(curl -s https://developers.hostinger.com/api/vps/v1/virtual-machines \
  --header "Authorization: Bearer $VPS_API_TOKEN")

# Verifica se o conteúdo é JSON válido
if ! echo "$response" | jq -e 'type == "array"' >/dev/null 2>&1; then
  echo "❌ Resposta inesperada da API. Verifique seu VPS_API_TOKEN ou se a API está online."
  echo "Resposta recebida: $response"
  exit 1
fi

echo "$response" | jq -r '.[] | "• ID: \(.id) | Host: \(.hostname) | Estado: \(.state)"'

echo ""
read -rp "🖊️  Digite o ID da VPS que deseja recriar: " VPS_ID
[[ -z "$VPS_ID" ]] && { echo "❌ Nenhum ID informado. Saindo..."; exit 1; }

read -rp "⚠️  Confirmar recriação da VPS $VPS_ID? (yes): " CONFIRM
[[ "$CONFIRM" != "yes" ]] && { echo "🚫 Cancelado."; exit 0; }

echo "🚀 Recriando VPS $VPS_ID..."
curl -s https://developers.hostinger.com/api/vps/v1/virtual-machines/$VPS_ID/recreate \
  --request POST \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $VPS_API_TOKEN" \
  --data "{\"password\": \"$VPS_ROOT_PASS\", \"template_id\": $TEMPLATE_ID}" | jq

echo "🌐 Obtendo hostname..."
VPS_HOST=$(curl -s https://developers.hostinger.com/api/vps/v1/virtual-machines \
  --header "Authorization: Bearer $VPS_API_TOKEN" \
  | jq -r ".[] | select(.id == $VPS_ID) | .hostname")

[[ -z "$VPS_HOST" || "$VPS_HOST" == "null" ]] && {
  echo "❌ Hostname da VPS não encontrado."
  exit 1
}

cp "$HOME/.ssh/known_hosts-bkp" "$HOME/.ssh/known_hosts" || true

echo "⏳ Aguardando SSH responder em $VPS_HOST..."
for attempt in $(seq 1 $MAX_RETRIES); do
  if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i "$SSH_KEY" -q root@"$VPS_HOST" 'exit' 2>/dev/null; then
    echo "✅ SSH disponível!"
    break
  fi
  echo "🕐 Tentativa $attempt/$MAX_RETRIES... aguardando ${SLEEP_INTERVAL}s"
  sleep "$SLEEP_INTERVAL"
done

if ! ssh -o ConnectTimeout=5 -i "$SSH_KEY" -q root@"$VPS_HOST" 'exit' 2>/dev/null; then
  echo "❌ Não foi possível conectar via SSH após tempo máximo."
  exit 1
fi

echo "📤 Enviando script de setup para $VPS_HOST..."
scp -i "$SSH_KEY" "$REMOTE_SCRIPT" root@"$VPS_HOST":/tmp/

echo "🚀 Executando script de setup remoto..."
ssh -i "$SSH_KEY" root@"$VPS_HOST" bash /tmp/$(basename "$REMOTE_SCRIPT") "$REPO_USER" "$GH_PAT_RUNNER" "$RUNNER_VERSION"

echo "🎉 Runners registrados para múltiplos repositórios com sucesso!"
