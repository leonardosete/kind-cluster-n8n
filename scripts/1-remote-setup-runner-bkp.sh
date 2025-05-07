#!/bin/bash
set -euo pipefail

REPO_USER="$1"
REPO_NAME="$2"
GH_PAT="$3"
RUNNER_VERSION="$4"

RUNNER_USER="github"
RUNNER_LABELS="self-hosted,linux,kind"
RUNNER_NAME="vps-kind"
RUNNER_HOME="/home/$RUNNER_USER"
RUNNER_DIR="$RUNNER_HOME/actions-runner"
RUNNER_PKG="actions-runner-linux-x64-$RUNNER_VERSION.tar.gz"
RUNNER_URL="https://github.com/actions/runner/releases/download/v$RUNNER_VERSION/$RUNNER_PKG"
REPO_URL="https://github.com/$REPO_USER/$REPO_NAME"

echo "📦 Instalando dependências..."
apt-get update -y
apt-get install -y perl jq curl tar sudo

if ! id "$RUNNER_USER" &>/dev/null; then
  echo "👤 Criando usuário $RUNNER_USER..."
  useradd -m -s /bin/bash "$RUNNER_USER"
fi

mkdir -p "$RUNNER_DIR"
chown "$RUNNER_USER:$RUNNER_USER" "$RUNNER_DIR"

echo "📥 Baixando GitHub Actions Runner..."
sudo -u "$RUNNER_USER" bash -c "
  cd $RUNNER_DIR &&
  curl -sLO $RUNNER_URL &&
  echo '0dbc9bf5a58620fc52cb6cc0448abcca964a8d74b5f39773b7afcad9ab691e19  $RUNNER_PKG' | shasum -a 256 -c &&
  tar xzf $RUNNER_PKG
"

echo "🔑 Solicitando token de registro ao GitHub..."
REG_TOKEN=$(curl -s -X POST \
  -H "Authorization: token ${GH_PAT}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${REPO_USER}/${REPO_NAME}/actions/runners/registration-token" \
  | jq -r .token)

if [[ -z "$REG_TOKEN" || "$REG_TOKEN" == "null" ]]; then
  echo "❌ Falha ao obter token de registro!"
  exit 1
fi

echo "⚙️  Configurando runner..."
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

echo "✅ Runner registrado com sucesso!"
echo "🛠️  Configuração concluída. O runner está pronto para uso."