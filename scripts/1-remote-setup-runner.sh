#!/bin/bash
set -euo pipefail

REPO_USER="${1}"
RUNNER_VERSION="${2}"

if [[ -z "${GH_PAT_RUNNER:-}" ]]; then
  echo "❌ Erro: A variável de ambiente GH_PAT_RUNNER não foi definida." >&2
  echo "   Certifique-se de que ela foi exportada para a sessão SSH." >&2
  exit 1
fi

# Debug: verificar token
echo "🔍 Debug: Token recebido (primeiros/últimos 10 caracteres): ${GH_PAT_RUNNER:0:10}...${GH_PAT_RUNNER: -10}"
echo "🔍 Debug: Comprimento do token: ${#GH_PAT_RUNNER}"

#REPOS=("kind-cluster-n8n" "git-wkf-dash" "garantia-digital")
REPOS=("kind-cluster-n8n" "meu-dash" "garantia-digital-v1-dyad")

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
  SERVICE_NAME="actions.runner.${REPO_USER}-${REPO_NAME}.${RUNNER_NAME}.service"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Processando: $REPO_NAME"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔍 Debug (Loop): Token recebido (primeiros/últimos 10 caracteres): ${GH_PAT_RUNNER:0:10}...${GH_PAT_RUNNER: -10}"
  echo "🔍 Debug (Loop): Comprimento do token: ${#GH_PAT_RUNNER}"

  # Verificar se o diretório do runner já existe
  if [[ -d "$RUNNER_DIR" ]]; then
    echo "⚠️  Diretório $RUNNER_DIR já existe"
    
    # Verificar se o serviço está ativo
    if systemctl is-active --quiet "$SERVICE_NAME"; then
      echo "✅ Runner já está ativo e funcional para $REPO_NAME"
      echo "⏭️  Pulando este repositório..."
      continue
    else
      echo "⚠️  Diretório existe, mas serviço não está ativo."
      echo "   Tentando remover serviço anterior..."
      sudo -u "$RUNNER_USER" bash -c "
        cd $RUNNER_DIR &&
        ./svc.sh uninstall || true
      "
      rm -rf "$RUNNER_DIR"
    fi
  fi

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
  echo "🔍 Debug: Testando conexão com GitHub..."
  
  API_RESPONSE=$(curl -s -X POST \
    -H "Authorization: token ${GH_PAT_RUNNER}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${REPO_USER}/${REPO_NAME}/actions/runners/registration-token")
  
  echo "🔍 Debug: Resposta da API (primeiros 200 caracteres):"
  echo "$API_RESPONSE" | head -c 200
  echo ""
  
  REG_TOKEN=$(echo "$API_RESPONSE" | jq -r .token 2>/dev/null || echo "")

  if [[ -z "$REG_TOKEN" || "$REG_TOKEN" == "null" ]]; then
    echo "❌ Falha ao obter token de registro para $REPO_NAME!"
    echo "   Resposta da API completa:"
    echo "$API_RESPONSE" | jq . 2>/dev/null || echo "$API_RESPONSE"
    echo "   Verifique se o token GH_PAT_RUNNER tem as permissões corretas (escopo 'repo')." >&2
    exit 1
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
  sudo ./svc.sh install
  sudo ./svc.sh start
  echo "✅ Runner instalado e iniciado com sucesso para $REPO_NAME"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Processamento concluído!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⏳ Aguardando que os serviços iniciem e conectem ao GitHub..."
echo "   (Isso pode levar até 30 segundos)"
sleep 5

echo ""
echo "📊 Resumo dos runners:"
for REPO_NAME in "${REPOS[@]}"; do
  RUNNER_NAME="vps-${REPO_NAME}"
  SERVICE_NAME="actions.runner.${REPO_USER}-${REPO_NAME}.${RUNNER_NAME}.service"
  STATUS="⚠️  Inativo"
  
  # Tentar até 25 vezes com 2 segundos entre tentativas = até 50 segundos
  for attempt in {1..25}; do
    if systemctl is-active --quiet "$SERVICE_NAME"; then
      STATUS="✅ Ativo"
      break
    fi
    if (( attempt < 25 )); then
      sleep 2
    fi
  done
  
  if [[ "$STATUS" == "⚠️  Inativo" ]]; then
    STATUS="⚠️  Inativo (verificar com: systemctl status $SERVICE_NAME)"
  fi
  
  echo "  $REPO_NAME: $STATUS"
done
echo ""
