# Imagem oficial do n8n
FROM n8nio/n8n:1.89.2

USER root

# Dependências de Python (para n8n-nodes-python)
RUN apk add --no-cache python3 py3-pip \
 && ln -sf python3 /usr/bin/python

# Cria o diretório padrão de nós: ~/.n8n/nodes
RUN mkdir -p /home/node/.n8n/nodes

# ---- habilita pnpm e instala os community nodes dentro de ~/.n8n/nodes ----
RUN corepack enable \
 && corepack prepare pnpm@latest --activate \
 && pnpm install \
      --dir /home/node/.n8n/nodes \
      n8n-nodes-evolution-api \
      n8n-nodes-python

# Lib python usada pelo node python
RUN pip install fire --break-system-packages

# Corrige dono dos arquivos
RUN chown -R node:node /home/node/.n8n

# NÃO definimos N8N_CUSTOM_EXTENSIONS.
# O n8n sempre procura ~/.n8n/nodes por padrão.
USER node

CMD ["n8n","start"]
