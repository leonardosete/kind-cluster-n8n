# ---------- Base oficial do n8n ----------
    FROM n8nio/n8n:1.106.3

    USER root
    
    # 1 ▸ Dependências: Python + pip
    RUN apk add --no-cache python3 py3-pip \
     && ln -sf python3 /usr/bin/python
    
    # 2 ▸ pnpm via Corepack (satisfaz "only-allow pnpm")
    RUN corepack enable \
     && corepack prepare pnpm@latest --activate
    
    # 3 ▸ Lib Python usada por n8n-nodes-python
    RUN pip install fire --break-system-packages
    
    # 4 ▸ Entrypoint custom: instala community-nodes se ainda não existem
    COPY docker-entrypoint-community.sh /usr/local/bin/docker-entrypoint-community.sh
    RUN chmod +x /usr/local/bin/docker-entrypoint-community.sh
    
    # 5 ▸ Esse passa a ser o entrypoint do contêiner
    ENTRYPOINT ["/usr/local/bin/docker-entrypoint-community.sh"]
    CMD ["start"]
    