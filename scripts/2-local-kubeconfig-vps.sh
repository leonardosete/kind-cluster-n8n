#!/bin/bash

# Esse script deve ser executado com 'source'

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "⚠️  Esse script deve ser executado com 'source':"
  echo "    source $0"
  exit 1
fi

# 🔧 Variáveis configuráveis
VPS_USER="leosete"
VPS_HOST="srv809140.hstgr.cloud"
VPS_SSH_KEY="$HOME/.ssh/nova_vps_srv809140"
VPS_KUBECONFIG_PATH="/home/leosete/.kube/config"

LOCAL_KUBECONFIG="$HOME/.kube/config-vps"
VPS_IP="168.231.96.187"
VPS_SSH_PORT="63715"
VPS_CLUSTER_PORT="42885"

echo "::group::🚀 Baixando kubeconfig da VPS"

mkdir -p "$(dirname "$LOCAL_KUBECONFIG")"

if [[ -f "$LOCAL_KUBECONFIG" ]]; then
  mv "$LOCAL_KUBECONFIG" "${LOCAL_KUBECONFIG}.bak.$(date +%s)"
  echo "📦 Backup do kubeconfig antigo foi criado."
fi

scp -P "$VPS_SSH_PORT" -i "$VPS_SSH_KEY" -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST:$VPS_KUBECONFIG_PATH" "$LOCAL_KUBECONFIG"

if [[ $? -ne 0 ]]; then
  echo "❌ Falha ao baixar o kubeconfig da VPS."
  return 1
fi

echo "✅ kubeconfig copiado para: $LOCAL_KUBECONFIG"
echo "::endgroup::"

echo "::group::🛠️  Ajustando conteúdo do kubeconfig"

# Remove certificate-authority-data
sed -i.bak '/certificate-authority-data/d' "$LOCAL_KUBECONFIG"

# ### INÍCIO DA CORREÇÃO ###
# A sintaxe do comando 'sed' foi ajustada para ser compatível com macOS/BSD,
# colocando o texto a ser inserido em uma nova linha.
sed -i.bak '
/- cluster:/ a\
    insecure-skip-tls-verify: true
' "$LOCAL_KUBECONFIG"
# ### FIM DA CORREÇÃO ###

# Substitui o server para o IP público
sed -i.bak "s|server: https://.*|server: https://$VPS_IP:$VPS_CLUSTER_PORT|" "$LOCAL_KUBECONFIG"

rm "${LOCAL_KUBECONFIG}.bak"

echo "✅ kubeconfig atualizado com IP e TLS desabilitado"
echo "::endgroup::"

echo "::group::🎯 Ajustando contexto padrão"

export KUBECONFIG="$LOCAL_KUBECONFIG"
EXISTING_USER=$(kubectl config view --kubeconfig="$KUBECONFIG" -o jsonpath='{.users[0].name}')

if [[ -z "$EXISTING_USER" ]]; then
  echo "❌ Usuário não encontrado no kubeconfig baixado."
  return 1
fi

kubectl config set-context kind-kind \
  --cluster=kind-kind \
  --user="$EXISTING_USER" \
  --kubeconfig="$KUBECONFIG" > /dev/null

kubectl config use-context kind-kind --kubeconfig="$KUBECONFIG" > /dev/null

echo "✅ Contexto 'kind-kind' ajustado com sucesso!"
echo "👤 Usuário: $EXISTING_USER"
echo "📄 KUBECONFIG está configurado para: $KUBECONFIG"
echo "::endgroup::"