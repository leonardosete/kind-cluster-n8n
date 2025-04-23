FROM n8nio/n8n:1.89.2

USER root
RUN apk update && apk add --no-cache python3 py3-pip \
 && ln -sf python3 /usr/bin/python \
 && mkdir -p /home/node/.n8n/custom

# install community nodes (ignorando scripts que quebram)
RUN npm install \
      --prefix /home/node/.n8n/custom \
      --ignore-scripts \
      n8n-nodes-evolution-api \
      n8n-nodes-python

# instala o fire
RUN pip install fire --break-system-packages

# garante permissão no dir do n8n
RUN chown -R node:node /home/node/.n8n

# copia o entrypoint e já chmoda como root
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
 && chown node:node /entrypoint.sh

# variáveis de ambiente
ENV N8N_CUSTOM_EXTENSIONS=/home/node/.n8n/custom

# agora sim troca para node
USER node

ENTRYPOINT ["/entrypoint.sh"]
CMD ["n8n","start"]
