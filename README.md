# 🔧 Provisionamento de Cluster KIND + n8n via Ansible e GitHub Actions

Este repositório provisiona uma VPS com Debian, instala um cluster Kubernetes usando KIND e realiza o deploy do [n8n](https://n8n.io/) com PostgreSQL, utilizando Ansible e Helm. Toda a automação pode ser executada por workflows do GitHub Actions.

---

## 📦 Estrutura do Projeto

```bash
kind-cluster-n8n/
├── ansible-hostinger/
│   ├── setup-servidor.yml          # Prepara a VPS, instala Docker, KIND, kubectl, Helm
│   ├── deploy-apps.yml             # Faz deploy do n8n e dependências via Helm
│   ├── inventory.ini               # Definição do host da VPS para Ansible
│   ├── ansible.cfg                 # Configuração geral do Ansible
│   └── vps-templates-base/         # Templates como bashrc, motd, kind-config.yaml
├── tools/
│   └── fix-kubeconfig-context.sh   # Corrige o contexto do kubeconfig para uso local
├── .github/
│   └── workflows/
│       ├── create-kind-cluster.yaml  # Workflow para configurar a VPS e o cluster
│       └── deploy-apps.yaml          # Workflow para deploy das aplicações
```

---

## ⚙️ O que é automatizado?

### Setup do Servidor (via `setup-servidor.yml`)

- Atualização de pacotes e instalação de:
  - Docker + Docker Compose
  - Python + pip
  - kubectl
  - Helm
  - KIND
  - Ferramentas úteis (htop, ncdu, btop, duf, etc.)
- Configuração do `.bashrc` e `motd` personalizados
- Criação do cluster KIND com:
  - Portas mapeadas: `80`, `443`, `6443 -> 42885`
  - Ingress Controller (NGINX)
- Exportação automática do kubeconfig da VPS

### Deploy das Aplicações (via `deploy-apps.yml`)

- Criação do namespace `n8n-vps`
- Deploy via Helm:
  - `cert_bundle`: ClusterIssuer e TLS (se necessário)
  - `n8n_postgres`: banco de dados PostgreSQL
  - `n8n`: aplicação principal
- Geração de URL final do serviço n8n como `/tmp/n8n-final-url.txt`

---

## 🚀 Execução via GitHub Actions

### 🔧 1. `create-kind-cluster.yaml`
- Prepara a VPS e cluster Kubernetes
- Ajusta o kubeconfig com IP da VPS e TLS desabilitado
- Salva o kubeconfig como artifact

### 🚀 2. `deploy-apps.yaml`
- Conecta via SSH na VPS
- Executa o `deploy-apps.yml`
- Exibe a URL final do n8n no terminal do GitHub Actions


---

## 🧠 Como usar localmente (após o provisionamento)

1. Acesse a aba **Actions** no GitHub;
2. Baixe o arquivo `kubeconfig-vps.zip` gerado pelo workflow;
3. Acesse no mínimo a raíz do repositório "kind-cluster-n8n";
4. Execute o script de correção de contexto (ele localizará e aplicará o kubeconfig automaticamente);

cd kind-cluster-n8n
source /tools/fix-kubeconfig-context.sh

## 🌐 Acesso ao n8n

O link final é exibido no terminal do GitHub Actions após o deploy:

```
🌐 Seu n8n está disponível em:
https://n8n-kind.seu-dominio.com
```

---

## 📌 Requisitos

- VPS com Debian acessível por SSH
- Chave SSH configurada nas GitHub Secrets (`SSH_PRIVATE_KEY`)
- As variáveis de ambiente:
  - `VPS_IP` e `VPS_CLUSTER_PORT` configuradas no repositório (GitHub Actions)

---

## ✅ Próximos passos sugeridos

- [ ] Adicionar ArgoCD para GitOps completo
- [ ] Adicionar stack de observabilidade: Prometheus, Grafana, Loki
- [ ] Configurar SSL automático via Cert-Manager + ClusterIssuer
- [ ] Automatizar deploy contínuo via push em repositórios de apps

---

## 🛠️ Autor

> Desenvolvido por [Leonardo Sete](https://github.com/leonardosete) • DevOps & SRE