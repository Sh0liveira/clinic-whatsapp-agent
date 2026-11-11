#!/usr/bin/env bash
# ==============================================================================
# Script de Inicialização da Instância - Evolution API v2 (POSIX / Linux / macOS)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Carregar .env se existir
if [ -f "${PROJECT_ROOT}/.env" ]; then
  # shellcheck disable=SC2046
  export $(grep -v '^#' "${PROJECT_ROOT}/.env" | grep -v '^\s*$' | xargs -d '\n' 2>/dev/null || grep -v '^#' "${PROJECT_ROOT}/.env" | xargs -0)
fi

INSTANCE_NAME="${1:-${EVOLUTION_INSTANCE_NAME:-clinic-instance}}"
WEBHOOK_URL="${2:-${EVOLUTION_WEBHOOK_URL:-http://n8n:5678/webhook/evolution}}"
SERVER_URL="${EVOLUTION_SERVER_URL:-http://localhost:8080}"
API_KEY="${EVOLUTION_API_KEY:-}"

if [ -z "${API_KEY}" ]; then
  echo "ERRO: EVOLUTION_API_KEY não configurada no ambiente ou .env" >&2
  exit 1
fi

echo "=========================================================="
echo " Inicialização da Instância - Evolution API v2 (Bash)"
echo "=========================================================="
echo "Instância   : ${INSTANCE_NAME}"
echo "Server URL  : ${SERVER_URL}"
echo "Webhook URL : ${WEBHOOK_URL}"
echo ""

# 1. Verificar conectividade
echo "[1/3] Verificando se a Evolution API está acessível..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "apikey: ${API_KEY}" "${SERVER_URL}/instance/fetchInstances" || echo "000")
if [ "${HTTP_CODE}" = "000" ]; then
  echo "ERRO: Não foi possível alcançar a Evolution API em ${SERVER_URL}" >&2
  exit 1
fi
echo " -> Conexão estabelecida com sucesso (HTTP ${HTTP_CODE})."

# 2. Verificar se a instância já existe (idempotência)
echo "[2/3] Verificando existência da instância '${INSTANCE_NAME}'..."
INSTANCES_JSON=$(curl -s -H "apikey: ${API_KEY}" "${SERVER_URL}/instance/fetchInstances")

if echo "${INSTANCES_JSON}" | grep -q "\"${INSTANCE_NAME}\""; then
  echo " -> Instância '${INSTANCE_NAME}' já existe. Pulando criação."
else
  echo " -> Criando instância '${INSTANCE_NAME}'..."
  CREATE_PAYLOAD=$(cat <<EOF
{
  "instanceName": "${INSTANCE_NAME}",
  "token": "",
  "qrcode": true,
  "integration": "WHATSAPP-BAILEYS",
  "webhook": {
    "enabled": true,
    "url": "${WEBHOOK_URL}",
    "byEvents": false,
    "base64": true,
    "events": [
      "MESSAGES_UPSERT",
      "MESSAGES_UPDATE",
      "CONNECTION_UPDATE",
      "QRCODE_UPDATED"
    ]
  }
}
EOF
)
  CREATE_RESP=$(curl -s -w "\n%{http_code}" -X POST "${SERVER_URL}/instance/create" \
    -H "apikey: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d "${CREATE_PAYLOAD}")

  STATUS_CODE=$(echo "${CREATE_RESP}" | tail -n 1)
  BODY=$(echo "${CREATE_RESP}" | sed '$d')

  if [ "${STATUS_CODE}" = "200" ] || [ "${STATUS_CODE}" = "201" ]; then
    echo " -> Instância '${INSTANCE_NAME}' criada com sucesso!"
  elif echo "${BODY}" | grep -qi "already"; then
    echo " -> Instância já existia (${BODY}). Prosseguindo..."
  else
    echo "ERRO ao criar instância (HTTP ${STATUS_CODE}): ${BODY}" >&2
    exit 1
  fi
fi

# 3. Configurar / sincronizar Webhook
echo "[3/3] Configurando Webhook da instância para '${WEBHOOK_URL}'..."
WEBHOOK_PAYLOAD=$(cat <<EOF
{
  "webhook": {
    "enabled": true,
    "url": "${WEBHOOK_URL}",
    "byEvents": false,
    "base64": true,
    "events": [
      "MESSAGES_UPSERT",
      "MESSAGES_UPDATE",
      "CONNECTION_UPDATE",
      "QRCODE_UPDATED"
    ]
  }
}
EOF
)

curl -s -X POST "${SERVER_URL}/webhook/set/${INSTANCE_NAME}" \
  -H "apikey: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "${WEBHOOK_PAYLOAD}" > /dev/null

echo " -> Webhook configurado com sucesso!"
echo ""
echo "=========================================================="
echo " Instância '${INSTANCE_NAME}' configurada."
echo " Próximo passo: execute o script de QR Code:"
echo "   ./scripts/evolution-qrcode.sh"
echo "=========================================================="
