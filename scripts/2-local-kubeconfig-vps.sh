#!/bin/bash

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
VPS_USER="leosete"
VPS_HOST="srv809140.hstgr.cloud"
VPS_SSH_KEY="$HOME/.ssh/nova_vps_srv809140"
# ATENÇÃO: Verifique se este caminho está correto no servidor. Geralmente é /home/usuario/.kube/config
VPS_KUBECONFIG_PATH="/home/leosete/.kube/config"

LOCAL_KUBECONFIG="$HOME/.kube/config-vps"
VPS_IP="168.231.96.187"
VPS_SSH_PORT="63715"
VPS_CLUSTER_PORT="42885"

echo "::group::🚀 Baixando kubeconfig da VPS"

mkdir -p "$(dirname "$LOCAL_KUBECONFIG")"

# Faz backup do kubeconfig antigo se existir, em vez de remover
if [[ -f "$LOCAL_KUBECONFIG" ]]; then
  mv "$LOCAL_KUBECONFIG" "${LOCAL_KUBECONFIG}.bak.$(date +%s)"
  echo "📦 Backup do kubeconfig antigo foi criado."
fi

# Realiza o SCP
# CORREÇÃO: Usado -P (maiúsculo) para a porta.
scp -P "$VPS_SSH_PORT" -i "$VPS_SSH_KEY" -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST:$VPS_KUBECONFIG_PATH" "$LOCAL_KUBECONFIG"

# Verifica se o download falhou
if [[ $? -ne 0 ]]; then
  echo "❌ Falha ao baixar o kubeconfig da VPS. Verifique as configurações de SSH, caminhos e conexão."
  # Usa 'return' para parar a execução do script sem fechar o terminal
  return 1
fi

echo "✅ kubeconfig copiado para: $LOCAL_KUBECONFIG"
echo "::endgroup::"

# Ajusta conteúdo
echo "::group::🛠️  Ajustando conteúdo do kubeconfig"

# CORREÇÃO: Adicionada a extensão .bak para compatibilidade entre Linux e macOS.
# Remove certificate-authority-data
sed -i.bak '/certificate-authority-data/d' "$LOCAL_KUBECONFIG"

# Insere insecure-skip-tls-verify: true
# A busca foi melhorada para ser mais específica
sed -i.bak '/- cluster:/a\    insecure-skip-tls-verify: true' "$LOCAL_KUBECONFIG"

# Substitui o server para o IP público
sed -i.bak "s|server: https://.*|server: https://$VPS_IP:$VPS_CLUSTER_PORT|" "$LOCAL_KUBECONFIG"

# Remove o arquivo de backup criado pelo sed
rm "${LOCAL_KUBECONFIG}.bak"

echo "✅ kubeconfig atualizado com IP e TLS desabilitado"
echo "::endgroup::"

# Ajusta contexto
echo "::group::🎯 Ajustando contexto padrão"

export KUBECONFIG="$LOCAL_KUBECONFIG"
EXISTING_USER=$(kubectl config view --kubeconfig="$KUBECONFIG" -o jsonpath='{.users[0].name}')

if [[ -z "$EXISTING_USER" ]]; then
  echo "❌ Usuário não encontrado no kubeconfig baixado. O arquivo pode estar malformado."
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