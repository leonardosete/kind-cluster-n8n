# Imagem oficial do n8n
FROM n8nio/n8n:1.89.2

USER root

# 1. Python - requerido por n8n-nodes-python
RUN apk add --no-cache python3 py3-pip \
 && ln -sf python3 /usr/bin/python

# 2. Habilita pnpm (via Corepack) para que o preinstall do evolution-api aceite
RUN corepack enable \
 && corepack prepare pnpm@latest --activate

# 3. Lib Python usada pelo node Python
RUN pip install fire --break-system-packages

USER node
CMD ["n8n", "start"]
