
# 🚀 Provisionamento Kubernetes + Helm (n8n Stack) com Ansible

Este projeto automatiza a configuração de um ambiente Kubernetes completo em um servidor Debian, utilizando:

- [x] Kubernetes via Kind
- [x] Helm
- [x] cert-manager + ClusterIssuer
- [x] PostgreSQL (via Helm)
- [x] n8n (via Helm com domínio e TLS via Let's Encrypt)

---

## 📁 Estrutura do projeto

```bash
create-kind-cluster/
├── ansible-hostinger/
│   ├── ansible.cfg
│   ├── inventory.ini
│   └── setup-servidor.yml
├── roles/
│   ├── cert-bundle/      # Helm install do ClusterIssuer
│   ├── n8n-postgres/     # Helm chart PostgreSQL
│   └── n8n/              # Helm chart n8n
├── cert-bundle/          # Chart Helm local (ClusterIssuer)
├── n8n/                  # Chart Helm local (n8n)
├── n8n-postgres/         # Chart Helm local (PostgreSQL)
└── create-kind-cluster.sh  # Script principal de execução
```

---

## 🧰 Pré-requisitos

- Servidor Debian remoto com acesso via SSH (com chave pública configurada)
- Helm instalado localmente
- Python 3 + Ansible instalados na máquina local

---

## 🚀 Como executar

Para iniciar toda a automação, execute:

```bash
bash /Users/leonardosete/kind-cluster-n8n/create-kind-cluster.sh
```

Esse script orquestra o ambiente Kubernetes local via Kind e executa o Ansible com o seguinte comando:

```bash
ansible-playbook ansible-hostinger/setup-servidor.yml -i ansible-hostinger/inventory.ini
```

---

## 🧠 O que o playbook faz

- Instala Kind, kubectl, Helm, Docker e outras dependências
- Prepara o cluster local Kubernetes
- Instala cert-manager
- Instala ClusterIssuer via chart Helm `cert-bundle`
- Instala PostgreSQL via chart Helm `n8n-postgres`
- Instala o n8n via chart Helm `n8n`
- Gera a URL final de acesso ao n8n com HTTPS

---

## 🏷️ Execução parcial com tags

Você pode rodar partes específicas usando tags:

```bash
# Executa somente o cert-bundle
ansible-playbook setup-servidor.yml --tags cert-bundle

# Executa somente o deploy do PostgreSQL
ansible-playbook setup-servidor.yml --tags n8n-postgres

# Executa somente o deploy do n8n
ansible-playbook setup-servidor.yml --tags n8n
```

---

## 🌐 Acesso final ao n8n

Após o provisionamento, acesse sua instância:

🔗 **https://n8n.antonellagoldsemijoias.com**

**Usuário:** `admin`  
**Senha:** `superadmin123` (ou valor configurado no `values.yaml`)

---

## 📌 Observações

- Os charts Helm são mantidos localmente no projeto e sincronizados com o servidor via Ansible.
- A estrutura com `roles` permite modularidade, reaproveitamento e escalabilidade.
- A instalação usa `helm upgrade --install` para garantir que a execução seja idempotente.

---

## 💡 Dicas futuras

- Criar role para backup automatizado do PostgreSQL
- Integrar com Prometheus + Grafana via Helm
- Versionar os `values.yaml` por ambiente (dev, staging, prod)
- Automatizar deploy contínuo com GitHub Actions ou GitLab CI

---

## 🙌 Autor

Automação e DevOps por **Leonardo Sete** 💪
