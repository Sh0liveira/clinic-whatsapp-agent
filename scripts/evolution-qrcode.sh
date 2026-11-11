#!/usr/bin/env bash
# ==============================================================================
# Script para Extrair QR Code / Base64 / Pairing Code da Evolution API v2
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ -f "${PROJECT_ROOT}/.env" ]; then
  # shellcheck disable=SC2046
  export $(grep -v '^#' "${PROJECT_ROOT}/.env" | grep -v '^\s*$' | xargs -d '\n' 2>/dev/null || grep -v '^#' "${PROJECT_ROOT}/.env" | xargs -0)
fi

INSTANCE_NAME="${1:-${EVOLUTION_INSTANCE_NAME:-clinic-instance}}"
SERVER_URL="${EVOLUTION_SERVER_URL:-http://localhost:8080}"
API_KEY="${EVOLUTION_API_KEY:-}"

if [ -z "${API_KEY}" ]; then
  echo "ERRO: EVOLUTION_API_KEY não configurada no ambiente ou .env" >&2
  exit 1
fi

echo "Consultando estado da conexão para '${INSTANCE_NAME}'..."
STATE=$(curl -s -H "apikey: ${API_KEY}" "${SERVER_URL}/instance/connectionState/${INSTANCE_NAME}" || echo "{}")

if echo "${STATE}" | grep -q '"open"'; then
  echo "Instância '${INSTANCE_NAME}' já está CONECTADA (Status: open)."
  exit 0
fi

echo "Obtendo dados de conexão (QR Code / Pairing Code)..."
RESP=$(curl -s -H "apikey: ${API_KEY}" "${SERVER_URL}/instance/connect/${INSTANCE_NAME}")

# Extrair base64 com sed/grep sem exigir jq obrigatoriamente
B64=$(echo "${RESP}" | grep -o '"base64":"[^"]*' | cut -d'"' -f4 | sed 's/^data:image\/[^;]*;base64,//' || true)
CODE=$(echo "${RESP}" | grep -o '"code":"[^"]*' | cut -d'"' -f4 || true)
PAIRING=$(echo "${RESP}" | grep -o '"pairingCode":"[^"]*' | cut -d'"' -f4 || true)

echo "=========================================================="
echo " DADOS DE AUTENTICAÇÃO WHATSAPP"
echo "=========================================================="

if [ -n "${PAIRING}" ]; then
  echo "Código de Pareamento (Pairing Code): ${PAIRING}"
fi

if [ -n "${CODE}" ]; then
  echo "String do QR Code: ${CODE}"
fi

if [ -n "${B64}" ]; then
  OUTPUT_PNG="${PROJECT_ROOT}/qrcode.png"
  if command -v base64 >/dev/null 2>&1; then
    echo "${B64}" | base64 -d > "${OUTPUT_PNG}" 2>/dev/null || echo "${B64}" | base64 -D > "${OUTPUT_PNG}" 2>/dev/null || true
    if [ -f "${OUTPUT_PNG}" ] && [ -s "${OUTPUT_PNG}" ]; then
      echo "-> Imagem do QR Code salva com sucesso em: ${OUTPUT_PNG}"
    fi
  fi
fi

echo ""
echo "Abra o WhatsApp no celular -> Aparelhos Conectados -> Conectar Aparelho e escaneie o QR Code."
