#!/bin/bash

set -e  # Encerra o script em caso de erro

# Caminhos
ANSIBLE_DIR="$(dirname "$0")/ansible-hostinger"
#CONNECT_SCRIPT="$(dirname "$0")/tools/connect-to-kind.sh"
CONNECT_SCRIPT="/Users/leonardosete/kind-cluster-n8n/tools/connect-to-kind.sh"
LOCAL_KUBECONFIG="$HOME/.kube/config-vps"


# 1. Garantindo fingerprint SSH atualizado
echo "🔑 Atualizando fingerprint SSH do host..."
ssh-keyscan -H srv774237.hstgr.cloud >> ~/.ssh/known_hosts
echo "✅ Fingerprint SSH atualizado."

# 2. Executando Ansible Playbook
if [ -d "$ANSIBLE_DIR" ]; then
  cd "$ANSIBLE_DIR"
  echo "▶️ Executando playbook Ansible..."
  ansible-playbook -i inventory.ini setup-servidor.yml

else
  echo "❌ Diretório do Ansible não encontrado: $ANSIBLE_DIR"
  exit 1
fi

# 3. Conectando ao cluster KIND
if [ -x "$CONNECT_SCRIPT" ]; then
  echo "🔗 Executando script de conexão com KIND..."
  bash "$CONNECT_SCRIPT"
  KUBECONFIG="$LOCAL_KUBECONFIG"
  kubectl get pods --all-namespaces
else
  echo "❌ Script de conexão não encontrado ou não é executável: $CONNECT_SCRIPT"
  exit 1
fi

# 4. Mensagem final personalizada
echo -e "\n✅ Setup concluído com sucesso!"

cat <<'EOF'

🧰 Ferramentas instaladas:
  - Docker
  - Docker Compose
  - KIND (Kubernetes in Docker)
  - kubectl
  - Python + pip
  - Helm
  - Pacotes de monitoramento: htop, btop, ncdu, duf, etc.

🧾 MotD atualizado com comandos úteis ao acessar via SSH.

🧠 Para carregar as novas configurações do bash:
   → Execute: source ~/.bashrc
   → Ou desconecte e conecte novamente no terminal.

🔑 Se quiser gerar nova chave SSH com outro e-mail:
   → ansible-playbook -i inventory.ini setup-servidor.yml -e "ssh_email=outro@exemplo.com"

☸️ Use o comando 'kubectl' para interagir com seu cluster Kubernetes remoto.

🚀 Tudo pronto para usar! Divirta-se!

EOF
