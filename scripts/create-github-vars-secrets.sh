#!/usr/bin/env bash
# create-gh-env.sh  —  converte .env-* em GitHub Variables e/ou Secrets
# Uso:
#   ./create-gh-env.sh [vars|secrets|both]  [owner/repo]  [env_dir]
# -----------------------------------------------------------------------------
set -euo pipefail

# ── parâmetros ---------------------------------------------------------------
MODE="${1:-both}"                          # vars | secrets | both
REPO="${2:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
ENV_DIR="${3:-.chaves}"                    # diretório com .env-*
case "$MODE" in vars|secrets|both) ;; *)
  echo "❌ use vars, secrets ou both" >&2; exit 1 ;;
esac

# Arquivos que devem ser ignorados
EXCLUDE_LIST=( ".env-GH_PAT_TOKEN" )

upper() { tr '[:lower:]-' '[:upper:]_'; }

# ── coleta arquivos ----------------------------------------------------------
shopt -s nullglob
FILES=("$ENV_DIR"/.env-*)
shopt -u nullglob
(( ${#FILES[@]} )) || { echo "⚠️  Nenhum .env-* em '$ENV_DIR'"; exit 0; }

echo "📦 Repo: $REPO   | Modo: $MODE   | Arquivos: ${#FILES[@]}"

# ── processa ---------------------------------------------------------------
for file in "${FILES[@]}"; do
  base=$(basename "$file")
  for ex in "${EXCLUDE_LIST[@]}"; do
    [[ $base == "$ex" ]] && { echo "🚫 Ignorando $file"; continue 2; }
  done

  echo -e "\n➡️  $file"
  while IFS='=' read -r key value || [[ -n $key ]]; do
    key="$(echo "$key" | xargs)"
    value="$(echo "$value" | xargs)"
    [[ -z $key || $key == \#* ]] && continue
    [[ $value == "-" ]] && { echo "⚠️  Ignorando $key (placeholder '-')"; continue; }

    var_name="$(echo "$key" | upper)"
    printf '   • %s = %s\n' "$var_name" "$value"

    if [[ $MODE == vars || $MODE == both ]]; then
      gh variable set "$var_name" --repo "$REPO" --body "$value"
    fi
    if [[ $MODE == secrets || $MODE == both ]]; then
      printf '%s' "$value" | gh secret set "$var_name" --repo "$REPO" --body -
    fi
  done < "$file"
done

echo -e "\n✅ Concluído. Confira em Settings → $( \
  [[ $MODE == vars ]] && echo Variables || \
  [[ $MODE == secrets ]] && echo Secrets  || echo 'Variables & Secrets')"
