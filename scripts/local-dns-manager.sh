#!/bin/bash
#set -euo pipefail

# ========================== CONFIG ==========================
DOMAIN="devops-master.shop"
API_BASE="https://developers.hostinger.com/api/dns/v1"
ZONE_URL="$API_BASE/zones/$DOMAIN"
AUTH_HEADER="Authorization: Bearer $VPS_API_TOKEN"

# ========================== VALIDATE TOKEN ==========================
if [[ -z "${VPS_API_TOKEN:-}" ]]; then
  echo "❌ Variável VPS_API_TOKEN não definida. Execute: source ~/.zshenv"
  exit 1
fi

# ========================== FUNCTIONS ==========================

list_records() {
  echo "📄 Listando todos os registros DNS de $DOMAIN..."
  curl -s "$ZONE_URL" --header "$AUTH_HEADER" | \
    jq -r '.[] | "\(.type)\t\(.name)\tTTL=\(.ttl)\t\(.records[0].content)"'
}

search_record() {
  read -rp "🔍 Parte do nome do registro que deseja buscar: " RECORD_NAME
  echo "📄 Resultado:"
  curl -s "$ZONE_URL" --header "$AUTH_HEADER" | \
    jq -r --arg name "$RECORD_NAME" '.[] | select(.name | test($name; "i")) | "\(.type)\t\(.name)\tTTL=\(.ttl)\t\(.records[0].content)"'
}

update_record() {
  read -rp "✏️  Nome do registro (ex: app): " NAME
  read -rp "🌐 Novo IP (formato A, ex: 168.231.96.100): " NEW_IP
  read -rp "⏱️  TTL (padrão: 300): " TTL
  TTL=${TTL:-300}

  echo "♻️ Atualizando registro $NAME -> $NEW_IP"
  curl -s -X PUT "$ZONE_URL" \
    --header "$AUTH_HEADER" \
    --header "Content-Type: application/json" \
    --data "[
      {
        \"name\": \"$NAME\",
        \"type\": \"A\",
        \"ttl\": $TTL,
        \"records\": [
          {\"content\": \"$NEW_IP\"}
        ]
      }
    ]" | jq
}

delete_record() {
  read -rp "🗑️ Nome do registro que deseja deletar: " RECORD_NAME

  RECORD_TYPE=$(curl -s "$ZONE_URL" --header "$AUTH_HEADER" | \
    jq -r --arg name "$RECORD_NAME" '.[] | select(.name == $name) | .type')

  if [[ -z "$RECORD_TYPE" || "$RECORD_TYPE" == "null" ]]; then
    echo "❌ Registro '$RECORD_NAME' não encontrado."
    return
  fi

  echo "⚠️ Deletando $RECORD_NAME do tipo $RECORD_TYPE..."

  curl -s -X DELETE "$ZONE_URL" \
    --header "$AUTH_HEADER" \
    --header "Content-Type: application/json" \
    --data "{
      \"filters\": [
        {
          \"name\": \"$RECORD_NAME\",
          \"type\": \"$RECORD_TYPE\"
        }
      ]
    }" | jq
}

create_record() {
  echo "🆕 Criar novo registro DNS"

  read -rp "📛 Nome do novo registro (ex: app, www): " NAME
  read -rp "📄 Tipo (A ou CNAME): " TYPE
  TYPE=$(echo "$TYPE" | tr '[:lower:]' '[:upper:]')

  if [[ "$TYPE" != "A" && "$TYPE" != "CNAME" ]]; then
    echo "❌ Tipo inválido. Apenas A ou CNAME são suportados."
    return
  fi

  read -rp "📥 Valor do registro (IP ou domínio): " CONTENT
  read -rp "⏱️ TTL (padrão: 300): " TTL
  TTL=${TTL:-300}

  # Verifica se já existe um registro com mesmo nome e tipo
  EXISTS=$(curl -s "$ZONE_URL" --header "$AUTH_HEADER" | \
    jq -r --arg name "$NAME" --arg type "$TYPE" '.[] | select(.name == $name and .type == $type)')

  if [[ -n "$EXISTS" ]]; then
    echo "❌ Já existe um registro com nome '$NAME' e tipo '$TYPE'."
    return
  fi

  # Monta payload
  JSON_PAYLOAD=$(jq -n \
    --arg name "$NAME" \
    --arg type "$TYPE" \
    --arg content "$CONTENT" \
    --argjson ttl "$TTL" \
    '{overwrite: false, zone: [ { name: $name, type: $type, ttl: $ttl, records: [ {content: $content} ] } ] }'
  )

  echo "🚀 Criando registro $NAME ($TYPE) → $CONTENT..."
  curl -s -X PUT "$ZONE_URL" \
    --header "$AUTH_HEADER" \
    --header "Content-Type: application/json" \
    --data "$JSON_PAYLOAD" | jq
}

# ========================== MENU ==========================

echo "🛠️ Gerenciador de DNS - $DOMAIN"
echo ""
select option in \
  "📄 Listar todos" \
  "🔍 Buscar por nome" \
  "♻️ Atualizar registro A" \
  "🗑️ Deletar registro" \
  "➕ Criar novo registro" \
  "🚪 Sair"; do

  case $REPLY in
    1) list_records ;;
    2) search_record ;;
    3) update_record ;;
    4) delete_record ;;
    5) create_record ;;
    6) echo "👋 Saindo..."; break ;;
    *) echo "❌ Opção inválida. Tente novamente." ;;
  esac
  echo ""
done
