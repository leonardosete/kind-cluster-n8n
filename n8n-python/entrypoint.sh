#!/usr/bin/env sh
# entrypoint.sh

# Aqui você pode colocar comandos adicionais que precisar rodar
# antes de iniciar o n8n (por exemplo, migrações, hooks, etc).

# Finalmente, executa o comando padrão (n8n start)
exec "$@"
