# Dockerfile
FROM n8nio/n8n:1.89.2

# 1. Fica como root para instalar OS packages, npm e pip
USER root

# 2. Instala Python3, pip e prepara o dir de custom nodes
RUN apk update \
 && apk add --no-cache python3 py3-pip \
 && ln -sf python3 /usr/bin/python \
 && mkdir -p /home/node/.n8n/custom

# 3. Instala os community nodes no diretório que o n8n vai buscar
RUN npm install \
      --prefix /home/node/.n8n/custom \
      n8n-nodes-evolution-api \
      n8n-nodes-python

# 4. Instala a lib fire para os nodes Python
RUN pip install fire --break-system-packages

# 5. Ajusta permissões para o usuário node
RUN chown -R node:node /home/node/.n8n

# 6. Informa ao n8n onde estão os módulos customizados
ENV N8N_CUSTOM_EXTENSIONS=/home/node/.n8n/custom

# 7. Volta para o usuário node e configura entrypoint
USER node

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["n8n", "start"]
