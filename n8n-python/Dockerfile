FROM n8nio/n8n:1.89.2

USER root

RUN apk update && \
    apk add --no-cache python3 py3-pip && \
    ln -sf python3 /usr/bin/python && \
    pip install fire --break-system-packages

USER node
