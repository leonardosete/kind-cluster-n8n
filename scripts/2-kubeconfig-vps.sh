# Esse script deve ser executado com 'source'

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "⚠️  Esse script deve ser executado com 'source':"
  echo "    source $0"
  exit 1
fi

## ATENÇÃO: Este script deve ser executado na máquina local, não na VPS.

## E SOMENTE DEPOIS DE EXECUTAR O PRIMEIRO WORKFLOW DO KIND.

# Este script é responsável por baixar o kubeconfig da VPS e ajustá-lo para uso local.
# Ele remove a configuração de certificate-authority-data e adiciona insecure-skip-tls-verify: true.
# Além disso, ele substitui o endereço do servidor pelo IP público da VPS e ajusta o contexto padrão.
# O script também faz um backup do kubeconfig antigo, caso exista, e informa o usuário sobre o sucesso ou falha das operações.
# 🚀 Script para baixar e ajustar kubeconfig da VPS

# 🔧 Variáveis configuráveis
VPS_USER="root"
VPS_HOST="srv809140.hstgr.cloud"
VPS_SSH_KEY="$HOME/.ssh/nova_vps_srv809140"
VPS_KUBECONFIG_PATH="/root/.kube/config"

LOCAL_KUBECONFIG="$HOME/.kube/config-vps"
VPS_IP="168.231.96.187"
VPS_CLUSTER_PORT="42885"

echo "::group::🚀 Baixando kubeconfig da VPS"

mkdir -p ~/.kube

# Remove kubeconfig antigo se existir
if [[ -f "$LOCAL_KUBECONFIG" ]]; then
  rm "$LOCAL_KUBECONFIG"
  echo "📦 Limpeza feita"
fi

# Realiza o SCP
scp -i "$VPS_SSH_KEY" -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST:$VPS_KUBECONFIG_PATH" "$LOCAL_KUBECONFIG"
echo "✅ kubeconfig copiado para: $LOCAL_KUBECONFIG"
echo "::endgroup::"

# Ajusta conteúdo
echo "::group::🛠️ Ajustando conteúdo do kubeconfig"

# Remove certificate-authority-data
sed -i '' '/certificate-authority-data/d' "$LOCAL_KUBECONFIG"

# Insere insecure-skip-tls-verify: true
sed -i '' '/cluster:/a\
    insecure-skip-tls-verify: true
' "$LOCAL_KUBECONFIG"

# Substitui o server para o IP público
sed -i '' "s|server: https://.*|server: https://$VPS_IP:$VPS_CLUSTER_PORT|" "$LOCAL_KUBECONFIG"

echo "✅ kubeconfig atualizado com IP e TLS desabilitado"
echo "::endgroup::"

# Ajusta contexto
echo "::group::🎯 Ajustando contexto padrão"

export KUBECONFIG="$LOCAL_KUBECONFIG"
EXISTING_USER=$(kubectl config view --kubeconfig="$KUBECONFIG" -o jsonpath='{.users[0].name}')

if [[ -z "$EXISTING_USER" ]]; then
  echo "❌ Usuário não encontrado no kubeconfig"
  exit 1
fi

kubectl config set-context kind-kind \
  --cluster=kind-kind \
  --user="$EXISTING_USER" \
  --kubeconfig="$KUBECONFIG" > /dev/null

kubectl config use-context kind-kind --kubeconfig="$KUBECONFIG" > /dev/null

echo "✅ Contexto 'kind-kind' ajustado com sucesso!"
echo "👤 Usuário: $EXISTING_USER"
echo "📄 KUBECONFIG: $KUBECONFIG"
echo "::endgroup::"
