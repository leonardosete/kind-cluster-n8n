#!/bin/bash

# Caminho do kubeconfig exportado da VPS
KUBECONFIG_PATH="${1:-$HOME/.kube/config-vps}"

echo "🔧 Corrigindo kubeconfig: $KUBECONFIG_PATH"

# Define variável de ambiente KUBECONFIG
export KUBECONFIG="$KUBECONFIG_PATH"

# Verifica se o arquivo existe
if [ ! -f "$KUBECONFIG_PATH" ]; then
  echo "❌ Arquivo kubeconfig não encontrado em: $KUBECONFIG_PATH"
  exit 1
fi

# Extrai o nome do usuário existente
EXISTING_USER=$(kubectl config view --kubeconfig="$KUBECONFIG_PATH" -o jsonpath='{.users[0].name}')

if [ -z "$EXISTING_USER" ]; then
  echo "❌ Não foi possível encontrar um usuário no kubeconfig."
  exit 1
fi

# Define contexto corretamente
kubectl config set-context kind-kind \
  --cluster=kind-kind \
  --user="$EXISTING_USER" \
  --kubeconfig="$KUBECONFIG_PATH"

# Define o current-context para que ferramentas como OpenLens funcionem
kubectl config use-context kind-kind --kubeconfig="$KUBECONFIG_PATH"

echo "✅ Contexto 'kind-kind' corrigido e ativado com usuário: $EXISTING_USER"
