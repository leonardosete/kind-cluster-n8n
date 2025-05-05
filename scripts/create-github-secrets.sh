#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# create-github-secrets.sh
# -----------------------------------------------------------------------------
# Lê todos os arquivos .env-* dentro do diretório .chaves e cria/atualiza
# GitHub Secrets com as chaves exatamente como aparecem em cada arquivo,
# **sem** adicionar prefixo algum.  Agora ignora explicitamente o arquivo
# `.env-GH_PAT_TOKEN` para evitar o overwrite do token de acesso.
# -----------------------------------------------------------------------------
set -euo pipefail

# Repositório alvo ("owner/repo"). Se não for passado, usa o repo atual.
REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
ENV_DIR=".chaves"
EXCLUDE_FILE=".env-GH_PAT_TOKEN"  # arquivo a ser ignorado

# -----------------------------------------------------------------------------
# Funções utilitárias
# -----------------------------------------------------------------------------
upper() { echo "$1" | tr '[:lower:]' '[:upper:]' | tr '-' '_'; }

# -----------------------------------------------------------------------------
# Coleta arquivos .env-* (exceto o EXCLUDE_FILE)
# -----------------------------------------------------------------------------
shopt -s nullglob
ENV_FILES=()
for path in "$ENV_DIR"/.env-*; do
  [[ $(basename "$path") == "$EXCLUDE_FILE" ]] && continue
  ENV_FILES+=("$path")
done
shopt -u nullglob

if (( ${#ENV_FILES[@]} == 0 )); then
  echo "❌ Nenhum arquivo .env-* encontrado em $ENV_DIR (após exclusão)" >&2
  exit 1
fi

echo "📦 Criando/atualizando secrets no repositório: $REPO"
printf '  • %s\n' "${ENV_FILES[@]}"

# -----------------------------------------------------------------------------
# Processa cada arquivo .env-*
# -----------------------------------------------------------------------------
for file in "${ENV_FILES[@]}"; do
  echo -e "\n➡️  Processando $file"

  while IFS='=' read -r key value || [[ -n $key ]]; do
    key="$(echo "$key" | xargs)"
    value="$(echo "$value" | xargs)"
    [[ -z $key || $key == \#* ]] && continue

    if [[ -z $value ]]; then
      echo "⚠️  Pulando linha sem valor: $key" >&2
      continue
    fi

    secret_name="$(upper "$key")"
    echo "   • Definindo secret $secret_name"
    echo -n "$value" | gh secret set "$secret_name" --repo "$REPO" --body -
  done < "$file"
done

echo -e "\n✅ Todos os secrets foram criados/atualizados com sucesso."
