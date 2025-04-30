#!/usr/bin/env bash
# create-github-secrets.sh  –  compatível com Bash 3.2 (macOS)
set -euo pipefail

#######################################################################
# Configurações                                                       #
#######################################################################
REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
ENV_DIR=".chaves"

# Encontra todos os .env-* no diretório configurado
ENV_FILES=()
for f in "$ENV_DIR"/.env-*; do
  [ -f "$f" ] && ENV_FILES+=("$f")
done

[ ${#ENV_FILES[@]} -eq 0 ] && {
  echo "❌ Nenhum .env-* encontrado em $ENV_DIR"; exit 1; }

echo "📦 Criando secrets no repositório: $REPO"
for f in "${ENV_FILES[@]}"; do echo "  • $f"; done

#######################################################################
# Funções auxiliares                                                  #
#######################################################################
upper() { printf '%s' "$1" | tr '[:lower:]-' '[:upper:]_'; }
# ^ converte para MAIÚSCULO e troca hífen ( - ) por underscore ( _ )

#######################################################################
# Loop principal                                                      #
#######################################################################
for file in "${ENV_FILES[@]}"; do
  APP_NAME=$(basename "$file" | sed 's/.env-//')
  APP_PREFIX=$(upper "$APP_NAME")          # hífens → _

  echo -e "\n➡️  Processando $file (prefixo ${APP_PREFIX}_)"

  while IFS= read -r line || [ -n "$line" ]; do
    # pula comentários e linhas vazias
    case "$line" in ""|\#*) continue ;; esac

    key=${line%%=*}
    value=${line#*=}

    # remove aspas
    value=${value#\"}; value=${value%\"}

    SECRET_NAME=$(upper "${APP_PREFIX}_${key}")

    echo "   • gh secret set $SECRET_NAME"
    printf '%s' "$value" | gh secret set "$SECRET_NAME" \
      --repo "$REPO" \
      --body -            # (sem --visibility)
  done < "$file"
done

echo -e "\n✅ Todos os secrets foram criados/atualizados."
