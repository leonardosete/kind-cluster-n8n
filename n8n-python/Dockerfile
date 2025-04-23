FROM n8nio/n8n:1.89.2

USER root

# 1) instala pnpm além do Node e do Python
RUN apk update \
 && apk add --no-cache python3 py3-pip \
 && ln -sf python3 /usr/bin/python \
 && npm install -g pnpm \
 && mkdir -p /home/node/.n8n/custom

# 2) usa pnpm para puxar e construir os community nodes
RUN pnpm install \
      --dir /home/node/.n8n/custom \
      n8n-nodes-evolution-api \
      n8n-nodes-python

# 3) instala o fire para o node-python
RUN pip install fire --break-system-packages

# 4) corrige dono/permissões
RUN chown -R node:node /home/node/.n8n

# 5) diz ao n8n onde buscar
ENV N8N_CUSTOM_EXTENSIONS=/home/node/.n8n/custom

# 6) entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER node
ENTRYPOINT ["/entrypoint.sh"]
CMD ["n8n","start"]
