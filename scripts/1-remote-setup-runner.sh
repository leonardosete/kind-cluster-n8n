#!/bin/bash
set -euo pipefail

REPO_USER="$1"
GH_PAT_RUNNER="$2"
RUNNER_VERSION="$3"

#REPOS=("kind-cluster-n8n" "git-wkf-dash" "garantia-digital")
REPOS=("kind-cluster-n8n" "git-wkf-dash")

RUNNER_USER="github"
RUNNER_LABELS="self-hosted,linux,kind"

echo "📦 Instalando dependências..."
apt-get update -y
apt-get install -y perl jq curl tar sudo

if ! id "$RUNNER_USER" &>/dev/null; then
  echo "👤 Criando usuário $RUNNER_USER..."
  useradd -m -s /bin/bash "$RUNNER_USER"
fi

for REPO_NAME in "${REPOS[@]}"; do
  RUNNER_NAME="vps-${REPO_NAME}"
  RUNNER_HOME="/home/$RUNNER_USER"
  RUNNER_DIR="$RUNNER_HOME/actions-runner-${REPO_NAME}"
  RUNNER_PKG="actions-runner-linux-x64-$RUNNER_VERSION.tar.gz"
  RUNNER_URL="https://github.com/actions/runner/releases/download/v$RUNNER_VERSION/$RUNNER_PKG"
  REPO_URL="https://github.com/$REPO_USER/$REPO_NAME"

  echo "📂 Preparando runner para $REPO_NAME..."
  mkdir -p "$RUNNER_DIR"
  chown "$RUNNER_USER:$RUNNER_USER" "$RUNNER_DIR"

  echo "📥 Baixando GitHub Actions Runner para $REPO_NAME..."
  sudo -u "$RUNNER_USER" bash -c "
    cd $RUNNER_DIR &&
    curl -sL \"$RUNNER_URL\" -o \"$RUNNER_PKG\" &&
    tar xzf \"$RUNNER_PKG\"
  "

  echo "🔑 Solicitando token de registro para $REPO_NAME..."
  REG_TOKEN=$(curl -s -X POST \
    -H "Authorization: token ${GH_PAT_RUNNER}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${REPO_USER}/${REPO_NAME}/actions/runners/registration-token" \
    | jq -r .token)

  if [[ -z "$REG_TOKEN" || "$REG_TOKEN" == "null" ]]; then
    echo "❌ Falha ao obter token de registro para $REPO_NAME!"
    continue
  fi

  echo "⚙️  Configurando runner para $REPO_NAME..."
  sudo -u "$RUNNER_USER" bash -c "
    cd $RUNNER_DIR &&
    ./config.sh --url $REPO_URL --token $REG_TOKEN \
      --name $RUNNER_NAME \
      --labels $RUNNER_LABELS \
      --unattended
  "

  echo "📦 Instalando e iniciando como serviço para $REPO_NAME..."
  cd "$RUNNER_DIR"
  ./svc.sh install
  ./svc.sh start
done

echo "✅ Todos os runners registrados!"
