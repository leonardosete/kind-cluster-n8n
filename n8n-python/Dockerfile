FROM n8nio/n8n:1.89.2

USER root

# 1) Instala Python e prepara pasta de custom nodes
RUN apk update \
 && apk add --no-cache python3 py3-pip \
 && ln -sf python3 /usr/bin/python \
 && mkdir -p /home/node/.n8n/custom

# 2) Habilita o pnpm via Corepack (não precisa npm install -g)
RUN corepack enable \
 && corepack prepare pnpm@latest --activate

# 3) Usa o pnpm para instalar e compilar os community nodes  
RUN pnpm install \
      --dir /home/node/.n8n/custom \
      n8n-nodes-evolution-api \
      n8n-nodes-python

# 4) Instala o fire para os nodes Python
RUN pip install fire --break-system-packages

# 5) Ajusta dono e permissões
RUN chown -R node:node /home/node/.n8n

# 6) Avisa ao n8n onde buscar pelos módulos customizados
ENV N8N_CUSTOM_EXTENSIONS=/home/node/.n8n/custom

# 7) Copia o entrypoint (como root) e libera a execução
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
 && chown node:node /entrypoint.sh

# 8) Volta para o user node
USER node

ENTRYPOINT ["/entrypoint.sh"]
CMD ["n8n","start"]
