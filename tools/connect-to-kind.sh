#!/bin/bash

# Variáveis configuráveis
SSH_KEY="$HOME/.ssh/hostinger-vps"
VPS_USER="root"
VPS_HOST="srv774237.hstgr.cloud"
REMOTE_KUBECONFIG="/root/.kube/config"
LOCAL_KUBECONFIG="$HOME/.kube/config-vps"
VPS_IP="82.29.61.99"

# Baixa o kubeconfig da VPS usando rsync
rm $LOCAL_KUBECONFIG
rsync -avz -e "ssh -i $SSH_KEY" $VPS_USER@$VPS_HOST:$REMOTE_KUBECONFIG $LOCAL_KUBECONFIG
chmod 600 "$LOCAL_KUBECONFIG"

# Define KUBECONFIG localmente
export KUBECONFIG=$LOCAL_KUBECONFIG

# Aplica ajuste do cluster com IP público e TLS ignorado
kubectl config set-cluster kind-kind \
  --server="https://$VPS_IP:42885" \
  --insecure-skip-tls-verify=true \
  --kubeconfig=$LOCAL_KUBECONFIG

# Garante que o contexto aponte para o usuário correto que já existe no kubeconfig
EXISTING_USER=$(kubectl config view --kubeconfig=$LOCAL_KUBECONFIG -o jsonpath='{.users[0].name}')

kubectl config set-context kind-kind \
  --cluster=kind-kind \
  --user="$EXISTING_USER" \
  --kubeconfig=$LOCAL_KUBECONFIG


