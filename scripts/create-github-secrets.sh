#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# create-github-secrets.sh
# -----------------------------------------------------------------------------
# Lê todos os arquivos .env-* dentro do diretório .chaves e cria/atualiza
# GitHub Secrets com as chaves exatamente como aparecem em cada arquivo,
# **sem** adicionar prefixo algum.
# -----------------------------------------------------------------------------
set -euo pipefail

# Repositório alvo ("owner/repo"). Se não for passado, usa o repo atual.
REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
ENV_DIR=".chaves"

# -----------------------------------------------------------------------------
# Funções utilitárias
# -----------------------------------------------------------------------------
# Converte para UPPERCASE e troca '-' por '_'
upper() {
  echo "$1" | tr '[:lower:]' '[:upper:]' | tr '-' '_'
}

# -----------------------------------------------------------------------------
# Coleta arquivos .env-* (ignora se o glob não encontrar nada)
# -----------------------------------------------------------------------------
shopt -s nullglob
ENV_FILES=("$ENV_DIR"/.env-*)
shopt -u nullglob

if (( ${#ENV_FILES[@]} == 0 )); then
  echo "❌ Nenhum arquivo .env-* encontrado em $ENV_DIR" >&2
  exit 1
fi

echo "📦 Criando/atualizando secrets no repositório: $REPO"
printf '  • %s\n' "${ENV_FILES[@]}"

# -----------------------------------------------------------------------------
# Processa cada arquivo .env-*
# -----------------------------------------------------------------------------
for file in "${ENV_FILES[@]}"; do
  echo -e "\n➡️  Processando $file"

  # Lê linha por linha no formato KEY=VALUE (suporta espaços antes/depois do '=')
  while IFS='=' read -r key value || [[ -n $key ]]; do
    # Remove espaços e ignora comentários/linhas vazias
    key="$(echo "$key" | xargs)"
    value="$(echo "$value" | xargs)"
    [[ -z $key || $key == \#* ]] && continue

    if [[ -z $value ]]; then
      echo "⚠️  Pulando linha sem valor: $key" >&2
      continue
    fi

    secret_name="$(upper "$key")"
    echo "   • Definindo secret $secret_name"

    # Envia o valor via stdin para evitar logs acidentais
    echo -n "$value" | gh secret set "$secret_name" --repo "$REPO" --body -
  done < "$file"
done

echo -e "\n✅ Todos os secrets foram criados/atualizados com sucesso."
