#!/bin/bash
set -euo pipefail

# Este script deve ser executado na máquina local, não na VPS.
# Ele instala o GitHub Actions Runner na VPS e o registra no repositório do GitHub.

# === CONFIGURAÇÕES LOCAIS ===
SSH_KEY=~/.ssh/nova_vps_srv809140
VPS_USER=root
VPS_HOST=srv809140.hstgr.cloud
ENV_FILE="/Users/leonardosete/kind-cluster-n8n/.chaves/.env-GH_PAT_TOKEN"

# === LIMPEZA KNOWN_HOSTS ===
cp /Users/leonardosete/.ssh/known_hosts-bkp /Users/leonardosete/.ssh/known_hosts

# === CARREGA TOKEN DO ARQUIVO .env ===
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Arquivo $ENV_FILE não encontrado!"
  exit 1
fi

GH_PAT=$(grep '^GH_PAT=' "$ENV_FILE" | cut -d '=' -f2-)

if [[ -z "$GH_PAT" ]]; then
  echo "❌ Token GH_PAT não encontrado no arquivo!"
  exit 1
fi

# === EXECUTA O SCRIPT REMOTAMENTE USANDO SSH ===
echo "🚀 Iniciando setup do GitHub Runner na VPS..."

REMOTE_SCRIPT=$(cat <<'EOS'
#!/bin/bash
set -euo pipefail

echo "📦 Instalando dependências: perl e jq..."
apt-get update -y
apt-get install -y perl jq

GITHUB_USER="leonardosete"
REPO_NAME="kind-cluster-n8n"
RUNNER_USER="github"
RUNNER_LABELS="self-hosted,linux,kind"
RUNNER_NAME="vps-kind"
RUNNER_VERSION="2.323.0"

REPO_URL="https://github.com/$GITHUB_USER/$REPO_NAME"
RUNNER_HOME="/home/$RUNNER_USER"
RUNNER_DIR="$RUNNER_HOME/actions-runner"
RUNNER_PKG="actions-runner-linux-x64-$RUNNER_VERSION.tar.gz"
RUNNER_URL="https://github.com/actions/runner/releases/download/v$RUNNER_VERSION/$RUNNER_PKG"
RUNNER_SHA="0dbc9bf5a58620fc52cb6cc0448abcca964a8d74b5f39773b7afcad9ab691e19"

if ! id "$RUNNER_USER" &>/dev/null; then
  echo "👤 Criando usuário $RUNNER_USER..."
  useradd -m -s /bin/bash "$RUNNER_USER"
fi

echo "📁 Preparando diretório do runner..."
mkdir -p "$RUNNER_DIR"
chown "$RUNNER_USER:$RUNNER_USER" "$RUNNER_DIR"

echo "📥 Baixando GitHub Actions Runner..."
sudo -u "$RUNNER_USER" bash -c "
  cd $RUNNER_DIR &&
  curl -sLO $RUNNER_URL &&
  echo \"$RUNNER_SHA  $RUNNER_PKG\" | shasum -a 256 -c &&
  tar xzf $RUNNER_PKG
"

echo "🔑 Solicitando token de registro ao GitHub..."
REG_TOKEN=$(curl -s -X POST \
  -H "Authorization: token ${GH_PAT}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$GITHUB_USER/$REPO_NAME/actions/runners/registration-token" \
  | jq -r .token)

if [[ "$REG_TOKEN" == "null" || -z "$REG_TOKEN" ]]; then
  echo "❌ Falha ao obter token de registro!"
  exit 1
fi

echo "⚙️ Configurando runner..."
sudo -u "$RUNNER_USER" bash -c "
  cd $RUNNER_DIR &&
  ./config.sh --url $REPO_URL --token $REG_TOKEN \
    --name $RUNNER_NAME \
    --labels $RUNNER_LABELS \
    --unattended
"

echo "📦 Instalando como serviço..."
cd "$RUNNER_DIR"
./svc.sh install
./svc.sh start

echo "✅ Runner registrado e ativo! Acesse: $REPO_URL/actions/runners"
EOS
)

ssh -i "$SSH_KEY" "$VPS_USER@$VPS_HOST" "GH_PAT='$GH_PAT' bash -s" <<< "$REMOTE_SCRIPT"
echo "✅ Setup concluído com sucesso!"