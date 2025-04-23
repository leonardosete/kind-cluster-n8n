#!/usr/bin/env sh
# roda como root ainda em cima do n8n:1.89.2
pip install fire --break-system-packages
# teste - agora executa o comando padrão do container
exec "$@"
