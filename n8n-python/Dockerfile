FROM n8nio/n8n:1.89.2

USER root
RUN apk update && apk add --no-cache python3 py3-pip \
 && ln -sf python3 /usr/bin/python \
 && mkdir -p /home/node/.n8n/custom

# ---- aqui mudamos ----
RUN npm install \
      --prefix /home/node/.n8n/custom \
      --ignore-scripts \
      n8n-nodes-evolution-api \
      n8n-nodes-python

RUN pip install fire --break-system-packages

RUN chown -R node:node /home/node/.n8n

ENV N8N_CUSTOM_EXTENSIONS=/home/node/.n8n/custom

USER node
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["n8n","start"]
