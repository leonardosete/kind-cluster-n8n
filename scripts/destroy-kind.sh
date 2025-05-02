#!/bin/bash

echo "🧨 Deletando cluster KIND..."

if ! command -v kind &> /dev/null; then
  echo "❌ O 'kind' não está instalado na VPS."
  exit 1
fi

kind delete cluster

if [ $? -eq 0 ]; then
  echo "✅ Cluster KIND deletado com sucesso!"
else
  echo "⚠️ Ocorreu um erro ao tentar deletar o cluster."
fi
