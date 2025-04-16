#!/bin/bash

# Verifica se o script está sendo executado com 'source'
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "⚠️  Esse script deve ser executado com 'source':"
  echo "    source $0"
  exit 1
fi

echo "🔍 Procurando arquivo kubeconfig-vps.zip (busca rápida)..."

# Busca em locais comuns e com profundidade limitada
ZIP_FILE=$(find "$HOME/Downloads" "$HOME" -maxdepth 2 -type f -name "kubeconfig-vps.zip" 2>/dev/null | head -n 1)

if [ -z "$ZIP_FILE" ]; then
  echo "❌ Arquivo kubeconfig-vps.zip não encontrado nos diretórios comuns."
  echo "🔎 Você pode mover o arquivo para ~/Downloads e tentar novamente."
  return 1
fi

echo "📦 Encontrado: $ZIP_FILE"
TMP_DIR=$(mktemp -d)

# Descompacta e move para ~/.kube
unzip -o "$ZIP_FILE" -d "$TMP_DIR" > /dev/null
rm -f "$ZIP_FILE"

mkdir -p "$HOME/.kube"
mv "$TMP_DIR/config-vps" "$HOME/.kube/config-vps"
rm -rf "$TMP_DIR"

echo "✅ kubeconfig extraído e movido para ~/.kube/config-vps"

# Corrige contexto como antes
KUBECONFIG_PATH="$HOME/.kube/config-vps"
export KUBECONFIG="$KUBECONFIG_PATH"

if [ ! -f "$KUBECONFIG_PATH" ]; then
  echo "❌ Arquivo kubeconfig não encontrado em: $KUBECONFIG_PATH"
  return 1
fi

EXISTING_USER=$(kubectl config view --kubeconfig="$KUBECONFIG_PATH" -o jsonpath='{.users[0].name}')
if [ -z "$EXISTING_USER" ]; then
  echo "❌ Não foi possível encontrar um usuário no kubeconfig."
  return 1
fi

kubectl config set-context kind-kind \
  --cluster=kind-kind \
  --user="$EXISTING_USER" \
  --kubeconfig="$KUBECONFIG_PATH" > /dev/null

kubectl config use-context kind-kind --kubeconfig="$KUBECONFIG_PATH" > /dev/null

# Log final
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Contexto 'kind-kind' corrigido com sucesso!"
echo "👤 Usuário:     $EXISTING_USER"
echo "📄 KUBECONFIG:  $KUBECONFIG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
