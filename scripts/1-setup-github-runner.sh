#!/bin/bash
set -euo pipefail

# === CONFIGURAÇÕES =========================================
GITHUB_USER="leonardosete"
REPO_NAME="kind-cluster-n8n"
RUNNER_USER="github"
RUNNER_LABELS="self-hosted,linux,kind"
RUNNER_NAME="vps-kind"
RUNNER_VERSION="2.323.0"
GH_PAT="ghp_***" # Personal Access Token do GitHub
# O token deve ter permissões para acessar o repositório e registrar runners
# https://github.com/settings/tokens
# ===========================================================

# === DERIVADOS =============================================
REPO_URL="https://github.com/$GITHUB_USER/$REPO_NAME"
RUNNER_HOME="/home/$RUNNER_USER"
RUNNER_DIR="$RUNNER_HOME/actions-runner"
RUNNER_PKG="actions-runner-linux-x64-$RUNNER_VERSION.tar.gz"
RUNNER_URL="https://github.com/actions/runner/releases/download/v$RUNNER_VERSION/$RUNNER_PKG"
RUNNER_SHA="0dbc9bf5a58620fc52cb6cc0448abcca964a8d74b5f39773b7afcad9ab691e19"
# ===========================================================

# === 1. Criar usuário ======================================
if ! id "$RUNNER_USER" &>/dev/null; then
  echo "👤 Criando usuário $RUNNER_USER..."
  useradd -m -s /bin/bash "$RUNNER_USER"
fi

# === 2. Preparar diretório =================================
echo "📁 Preparando $RUNNER_DIR..."
mkdir -p "$RUNNER_DIR"
chown "$RUNNER_USER:$RUNNER_USER" "$RUNNER_DIR"

# === 3. Baixar runner =======================================
echo "📥 Baixando GitHub Actions Runner v$RUNNER_VERSION..."
sudo -u "$RUNNER_USER" bash -c "
  cd $RUNNER_DIR &&
  curl -sLO $RUNNER_URL &&
  echo \"$RUNNER_SHA  $RUNNER_PKG\" | shasum -a 256 -c &&
  tar xzf $RUNNER_PKG
"

# === 4. Gerar token de registro via API ====================
echo "🔑 Gerando token de registro..."
REG_TOKEN=$(curl -s -X POST \
  -H "Authorization: token $GH_PAT" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$GITHUB_USER/$REPO_NAME/actions/runners/registration-token" \
  | jq -r .token)

if [[ "$REG_TOKEN" == "null" || -z "$REG_TOKEN" ]]; then
  echo "❌ Falha ao obter token de registro do runner!"
  exit 1
fi

echo "✔️ Token gerado com sucesso."

# === 5. Configurar runner ==================================
echo "⚙️ Configurando runner no GitHub..."
sudo -u "$RUNNER_USER" bash -c "
  cd $RUNNER_DIR &&
  ./config.sh --url $REPO_URL --token $REG_TOKEN \
    --name $RUNNER_NAME \
    --labels $RUNNER_LABELS \
    --unattended
"

# === 6. Instalar como serviço ==============================
echo "📦 Instalando como serviço..."
cd "$RUNNER_DIR"
./svc.sh install
./svc.sh start

echo "✅ Runner registrado e ativo! Pronto para receber jobs."
echo "📝 Para verificar o status do runner, acesse: $REPO_URL/actions/runners"