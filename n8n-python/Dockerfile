FROM n8nio/n8n:1.89.2

USER root
RUN apk update \
 && apk add --no-cache python3 py3-pip \
 && ln -sf python3 /usr/bin/python

# volta pra node, que é o usuário original do n8n
USER node

# Aqui você instala o fire e, em seguida, inicia o n8n
CMD ["sh","-c","pip install fire --break-system-packages && n8n start"]
