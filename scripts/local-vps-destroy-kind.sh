#!/bin/bash
set -euo pipefail

# ========================== CONFIGURAÇÕES ==========================
SSH_KEY="${SSH_KEY:-$HOME/.ssh/nova_vps_srv809140}"
VPS_HOST="${VPS_HOST:-srv809140.hstgr.cloud}"

# ========================== EXECUÇÃO REMOTA ==========================
echo "🧨 Deletando cluster KIND na VPS $VPS_HOST..."

ssh -i "$SSH_KEY" root@"$VPS_HOST" bash -s <<'EOS'
set -euo pipefail

echo "📦 Verificando instalação do kind..."
if ! command -v kind &> /dev/null; then
  echo "❌ O 'kind' não está instalado na VPS."
  exit 1
fi

echo "🧹 Deletando cluster KIND..."
kind delete cluster
rm -rf /root/.kube

echo "✅ Cluster KIND deletado com sucesso!"
EOS
echo "✅ Cluster KIND deletado com sucesso na VPS $VPS_HOST!"
