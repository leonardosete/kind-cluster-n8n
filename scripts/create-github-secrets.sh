#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
ENV_DIR=".chaves"

ENV_FILES=()
for f in "$ENV_DIR"/.env-*; do
  [ -f "$f" ] && ENV_FILES+=("$f")
done

[ ${#ENV_FILES[@]} -eq 0 ] && {
  echo "❌ Nenhum .env-* encontrado em $ENV_DIR"
  exit 1
}

echo "📦 Criando secrets no repositório: $REPO"
for f in "${ENV_FILES[@]}"; do echo "  • $f"; done

upper() { printf '%s' "$1" | tr '[:lower:]-' '[:upper:]_'; }

for file in "${ENV_FILES[@]}"; do
  APP_NAME=$(basename "$file" | sed 's/.env-//')
  APP_PREFIX=$(upper "$APP_NAME")

  echo -e "\n➡️  Processando $file (prefixo ${APP_PREFIX}_)"

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ""|\#*) continue ;; esac

    key=$(echo "${line%%=*}" | xargs)
    value=$(echo "${line#*=}" | xargs)

    if [[ -z "$key" || -z "$value" ]]; then
      echo "⚠️  Pulando linha inválida ou com valor vazio: $line"
      continue
    fi

    SECRET_NAME=$(upper "${APP_PREFIX}_${key}")

    echo "   • gh secret set $SECRET_NAME"
    printf '%s' "$value" | gh secret set "$SECRET_NAME" \
      --repo "$REPO" \
      --body -
  done < "$file"
done

echo -e "\n✅ Todos os secrets foram criados/atualizados com sucesso."
