#!/usr/bin/env zsh
# Build & push multi-arch para sevenleo/n8n-python:latest
set -e
set -o pipefail

# ===== Config =====
IMAGE_REPO="sevenleo/n8n-python"
IMAGE_TAG="latest"
PLATFORMS="linux/amd64,linux/arm64"
BUILDER_NAME="${BUILDER_NAME:-multiarch}"

# ===== Verificações básicas =====
if ! command -v docker >/dev/null 2>&1; then
  echo "❌ Docker não encontrado no PATH."
  exit 1
fi

# ===== Login no Docker Hub com PAT =====
if [[ -z "${N8N_PYTHON_IMAGEM_CUSTOM_PAT:-}" ]]; then
  echo "❌ A variável de ambiente N8N_PYTHON_IMAGEM_CUSTOM_PAT não está definida."
  echo "   Ex.: export N8N_PYTHON_IMAGEM_CUSTOM_PAT='<seu PAT do Docker Hub>'"
  exit 1
fi

echo "🔐 Efetuando login no Docker Hub como 'sevenleo'..."
print -r -- "$N8N_PYTHON_IMAGEM_CUSTOM_PAT" | docker login -u "sevenleo" --password-stdin 1>/dev/null
echo "✅ Login ok."

# ===== Buildx builder multi-arch =====
if ! docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
  echo "🛠  Criando builder '$BUILDER_NAME'..."
  docker buildx create --name "$BUILDER_NAME" --use >/dev/null
  docker buildx inspect --bootstrap >/dev/null
else
  echo "🛠  Usando builder existente '$BUILDER_NAME'..."
  docker buildx use "$BUILDER_NAME" >/dev/null
  docker buildx inspect --bootstrap >/dev/null
fi

# ===== Build & Push =====
TAG="${IMAGE_REPO}:${IMAGE_TAG}"
echo "🚀 Buildando e publicando ${TAG} para ${PLATFORMS} ..."
docker buildx build \
  --no-cache \
  --platform "$PLATFORMS" \
  -t "$TAG" \
  --push \
  .

echo "✅ Concluído: ${TAG}"
