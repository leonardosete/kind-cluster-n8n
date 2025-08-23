#!/bin/bash
set -euo pipefail

# --- Configurações ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Arquivos e Caminhos
ENV_FILE_GH="$PROJECT_ROOT/.chaves/.env-GH_PAT_RUNNER"
ENV_FILE_VPS="$PROJECT_ROOT/.chaves/.env-vps"
REMOTE_SCRIPT_PATH="$SCRIPT_DIR/1-remote-setup-runner.sh"

# Configurações da VPS e Runner
REPO_USER="leonardosete"
RUNNER_VERSION="2.323.0"
TEMPLATE_ID=1031

# Configurações de Conexão
SSH_KEY="${SSH_KEY:-$HOME/.ssh/nova_vps_srv809140}"
SSH_USER="root"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -i $SSH_KEY"
MAX_RETRIES=30
SLEEP_INTERVAL=15

# --- Funções Auxiliares ---

# Carrega variáveis de um arquivo .env de forma segura, sem sobrescrever
# variáveis que já existem no ambiente (terminal).
load_env() {
    local env_file="$1"
    if [[ ! -f "$env_file" ]]; then
        return
    fi

    echo "ℹ️  Carregando variáveis de '$env_file' (se não estiverem no ambiente)..."
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Remove \r no final da linha (comum em arquivos editados no Windows)
        line="${line%$'\r'}"

        # Ignora comentários e linhas vazias
        if [[ "$line" =~ ^\s*# || -z "$line" ]]; then
            continue
        fi

        # Extrai chave e valor de forma segura e dinâmica
        if [[ "$line" =~ ^\s*(export\s+)?([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(.*)\s*$ ]]; then
            local key="${BASH_REMATCH[2]}"
            local value_raw="${BASH_REMATCH[3]}"
            local value="$value_raw"

            # Remove aspas (simples ou duplas) que envolvem o valor
            if [[ "$value" =~ ^\'(.*)\'$ || "$value" =~ ^\"(.*)\"$ ]]; then
                value="${BASH_REMATCH[1]}"
            fi

            # Exporta a variável APENAS se ela ainda não estiver definida no ambiente.
            # A verificação `[[ -z "${!key+x}" ]]` checa se a variável com o nome em `key` está "setada".
            if [[ -z "${!key+x}" ]]; then
                export "$key"="$value"
            fi
        fi
    done < "$env_file"
}

# --- Carregamento de Variáveis e Validações ---

# Carrega as variáveis dos arquivos .env, respeitando as que já estão no ambiente
load_env "$ENV_FILE_VPS"
load_env "$ENV_FILE_GH"

# Agora, fazemos as validações
[[ -z "${VPS_API_TOKEN:-}" || -z "${VPS_ROOT_PASS:-}" ]] && {
  echo "❌ Variáveis VPS_API_TOKEN ou VPS_ROOT_PASS não definidas no ambiente ou em '$ENV_FILE_VPS'." >&2
  exit 1
}

[[ -z "${GH_PAT_RUNNER:-}" ]] && {
  echo "❌ GH_PAT_RUNNER não definido no ambiente ou em '$ENV_FILE_GH'." >&2
  exit 1
}

[[ ! -f "$REMOTE_SCRIPT_PATH" ]] && {
  echo "❌ Script remoto '$REMOTE_SCRIPT_PATH' não encontrado!"
  exit 1
}

api_call() {
    local method="$1"
    local url="$2"
    local data_payload="${3:-}"

    # DEBUG: Codifica o token em base64 para revelar quaisquer caracteres invisíveis
    local token_base64
    token_base64=$(echo -n "$VPS_API_TOKEN" | base64)

    local response
    response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" \
        -H "Authorization: Bearer $VPS_API_TOKEN" \
        -H "Content-Type: application/json" \
        ${data_payload:+-d "$data_payload"})

    local http_code
    http_code=$(tail -n1 <<< "$response")
    local body
    body=$(sed '$ d' <<< "$response")

    if (( http_code < 200 || http_code >= 300 )); then
        echo "❌ Erro na API: HTTP $http_code" >&2
        echo "DEBUG: Token (base64) para verificação: $token_base64" >&2
        echo "DEBUG: Token usado (primeiros/últimos 4 caracteres): ${VPS_API_TOKEN:0:4}...${VPS_API_TOKEN: -4}" >&2
        echo "Resposta: $body" >&2
        exit 1
    fi
    echo "$body"
}

# --- Execução Principal ---
echo "🔍 Buscando VPS disponíveis..."
vps_list_json=$(api_call "GET" "https://developers.hostinger.com/api/vps/v1/virtual-machines")
echo "$vps_list_json" | jq -r '.[] | "• ID: \(.id) | Host: \(.hostname) | Estado: \(.state)"'

echo ""
read -rp "🖊️  Digite o ID da VPS que deseja recriar: " VPS_ID
[[ -z "$VPS_ID" ]] && { echo "❌ Nenhum ID informado. Saindo..."; exit 1; }

read -rp "⚠️  Confirmar recriação da VPS '$VPS_ID'? (yes): " CONFIRM
[[ "$CONFIRM" != "yes" ]] && { echo "🚫 Cancelado."; exit 0; }

echo "🚀 Recriando VPS $VPS_ID..."
recreate_payload=$(jq -n --arg pass "$VPS_ROOT_PASS" --argjson tpl "$TEMPLATE_ID" '{password: $pass, template_id: $tpl}')
api_call "POST" "https://developers.hostinger.com/api/vps/v1/virtual-machines/$VPS_ID/recreate" "$recreate_payload" | jq .

echo "🌐 Obtendo hostname..."
VPS_HOST=$(echo "$vps_list_json" | jq -r ".[] | select(.id == $VPS_ID) | .hostname")

[[ -z "$VPS_HOST" || "$VPS_HOST" == "null" ]] && {
  echo "❌ Hostname da VPS não encontrado."
  exit 1
}

echo "🧹 Limpando chave SSH antiga para $VPS_HOST (se existir)..."
ssh-keygen -R "$VPS_HOST" &>/dev/null || true

# --- Lógica de Espera Robusta em 3 Estágios ---

# 1. Espera o processo de recriação INICIAR (sair do estado 'running')
echo "⏳ Estágio 1/3: Aguardando a VPS '$VPS_ID' iniciar o processo de recriação..."
for attempt in $(seq 1 $MAX_RETRIES); do
  vps_status_json=$(api_call "GET" "https://developers.hostinger.com/api/vps/v1/virtual-machines/$VPS_ID")
  vps_state=$(echo "$vps_status_json" | jq -r '.state')

  if [[ "$vps_state" != "running" ]]; then
    echo "✅ Processo de recriação iniciado. Estado atual: '$vps_state'."
    break
  fi
  echo "🕐 Tentativa $attempt/$MAX_RETRIES: VPS ainda no estado 'running'. Aguardando ${SLEEP_INTERVAL}s..."
  sleep "$SLEEP_INTERVAL"
done

[[ "$vps_state" == "running" ]] && { echo "❌ A VPS não iniciou o processo de recriação após o tempo máximo." >&2; exit 1; }

# 2. Espera o processo de recriação TERMINAR (voltar para o estado 'running')
echo "⏳ Estágio 2/3: Aguardando a VPS '$VPS_ID' finalizar a instalação..."
for attempt in $(seq 1 $MAX_RETRIES); do
  vps_status_json=$(api_call "GET" "https://developers.hostinger.com/api/vps/v1/virtual-machines/$VPS_ID")
  vps_state=$(echo "$vps_status_json" | jq -r '.state')

  if [[ "$vps_state" == "running" ]]; then
    echo "✅ Instalação da VPS concluída (estado: 'running')."
    break
  fi
  echo "🕐 Tentativa $attempt/$MAX_RETRIES: Estado atual é '$vps_state'. Aguardando ${SLEEP_INTERVAL}s..."
  sleep "$SLEEP_INTERVAL"
done

[[ "$vps_state" != "running" ]] && { echo "❌ A VPS não voltou ao estado 'running' após o tempo máximo. Último estado: '$vps_state'." >&2; exit 1; }

# 3. Espera o serviço SSH ficar disponível
echo "⏳ Estágio 3/3: Aguardando o serviço SSH responder em $VPS_HOST..."
for attempt_ssh in $(seq 1 $MAX_RETRIES); do
  if ssh $SSH_OPTS "${SSH_USER}@${VPS_HOST}" 'exit' 2>/dev/null; then
    echo "✅ SSH disponível!"
    ssh_ready=true
    break
  fi
  echo "🕐 Tentativa SSH $attempt_ssh/$MAX_RETRIES... aguardando 5s"
  sleep 5
done

[[ -z "${ssh_ready:-}" ]] && { echo "❌ Não foi possível conectar via SSH após o tempo máximo." >&2; exit 1; }

echo "📤 Enviando script de setup para $VPS_HOST..."
scp $SSH_OPTS "$REMOTE_SCRIPT_PATH" "${SSH_USER}@${VPS_HOST}":/tmp/

echo "🚀 Executando script de setup remoto..."
ssh $SSH_OPTS "${SSH_USER}@${VPS_HOST}" "export GH_PAT_RUNNER='$GH_PAT_RUNNER'; bash /tmp/$(basename "$REMOTE_SCRIPT_PATH") '$REPO_USER' '$RUNNER_VERSION'"

echo "🎉 Runners registrados para múltiplos repositórios com sucesso!"
