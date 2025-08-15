#!/usr/bin/env bash
# build-n8n-python-latest.sh
# Build & push multi-arch para sevenleo/n8n-python:latest
set -euo pipefail

IMAGE_REPO="sevenleo/n8n-python"
IMAGE_TAG="latest"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
BUILDER_NAME="${BUILDER_NAME:-multiarch}"
DOCKER_USER="${DOCKER_USER:-sevenleo}"

# 1) Checagens básicas
if ! command -v docker >/dev/null 2>&1; then
  echo "❌ Docker não encontrado no PATH."
  exit 1
fi

if [[ -z "${N8N_PYTHON_IMAGEM_CUSTOM_PAT:-}" ]]; then
  echo "❌ A env N8N_PYTHON_IMAGEM_CUSTOM_PAT não está definida."
  echo "   Ex.: export N8N_PYTHON_IMAGEM_CUSTOM_PAT='<seu PAT do Docker Hub>'"
  exit 1
fi

# 2) Login no Docker Hub via PAT (stdin)
echo "🔐 Efetuando login no Docker Hub como '${DOCKER_USER}'..."
# use printf sem quebra de linha para evitar prompt interativo
printf '%s' "$N8N_PYTHON_IMAGEM_CUSTOM_PAT" | docker login -u "$DOCKER_USER" --password-stdin 1>/dev/null
echo "✅ Login ok."

# 3) Builder buildx multi-arch
if ! docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
  echo "🛠  Criando builder '$BUILDER_NAME'..."
  docker buildx create --name "$BUILDER_NAME" --use >/dev/null
  docker buildx inspect --bootstrap >/dev/null
else
  echo "🛠  Usando builder existente '$BUILDER_NAME'..."
  docker buildx use "$BUILDER_NAME" >/dev/null
  docker buildx inspect --bootstrap >/dev/null
fi

# 4) Build & Push
TAG="${IMAGE_REPO}:${IMAGE_TAG}"
echo "🚀 Buildando e publicando ${TAG} para ${PLATFORMS} ..."
docker buildx build \
  --no-cache \
  --platform "$PLATFORMS" \
  -t "$TAG" \
  --push \
  .

echo "✅ Concluído: ${TAG}"
# Opcional: docker logout
# docker logout
