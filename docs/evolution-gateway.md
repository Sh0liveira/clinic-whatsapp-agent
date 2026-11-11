# Evolution API v2 - WhatsApp Gateway Setup & Connection

Este guia detalha a inicialização, configuração de Webhook e pareamento via QR Code da instância WhatsApp da clínica na Evolution API (v2.3.7).

---

## 1. Variáveis de Ambiente (12-Factor App)

As variáveis pertinentes à Evolution API estão documentadas no [.env.example](../.env.example):

| Variável | Padrão / Exemplo | Descrição |
|---|---|---|
| `EVOLUTION_SERVER_URL` | `http://localhost:8080` | URL base do gateway Evolution API |
| `EVOLUTION_API_KEY` | *(sua chave global)* | Chave de autenticação (`apikey`) |
| `EVOLUTION_INSTANCE_NAME` | `clinic-instance` | Nome único da instância WhatsApp da clínica |
| `EVOLUTION_WEBHOOK_URL` | `http://n8n:5678/webhook/evolution` | Endpoint interno da rede Docker apontando para o n8n |

---

## 2. Inicialização e Configuração do Webhook

Os scripts são **idempotentes**: caso a instância já exista, a criação é ignorada e os webhooks são sincronizados.

### Via Makefile (Multiplataforma)
```bash
make evolution-init
```

### Via PowerShell (Windows)
```powershell
powershell -ExecutionPolicy Bypass -File scripts/evolution-init.ps1
```
*Parâmetros opcionais:*
```powershell
powershell -ExecutionPolicy Bypass -File scripts/evolution-init.ps1 -InstanceName "minha-clinica" -WebhookUrl "http://n8n:5678/webhook/evolution"
```

### Via Bash (Linux / macOS / CI)
```bash
chmod +x scripts/*.sh
./scripts/evolution-init.sh
```

---

## 3. Conexão e Leitura do QR Code

Ao executar o script de QR Code:
1. Ele consulta a rota `/instance/connect/{instance}`.
2. Extrai o Base64 da imagem e salva em `qrcode.png` na raiz do projeto.
3. Exibe o `pairingCode` (caso prefira parear por código de 8 dígitos) e a string bruta do QR Code.
4. No Windows, abre automaticamente o visualizador de imagens com o QR Code.

### Via Makefile
```bash
make evolution-qr
```

### Via PowerShell
```powershell
powershell -ExecutionPolicy Bypass -File scripts/evolution-qrcode.ps1
```
*(Para não abrir a janela de imagem automaticamente, use a flag `-NoImage`)*.

### Via Bash
```bash
./scripts/evolution-qrcode.sh
```

### Via cURL / Linha de Comando Pura

#### 1. Gerar/Buscar QR Code (Base64 + Pairing Code):
```bash
curl -s -X GET "http://localhost:8080/instance/connect/clinic-instance" \
  -H "apikey: SUA_EVOLUTION_API_KEY"
```

#### 2. Extrair imagem PNG diretamente no terminal Linux/macOS:
```bash
curl -s -X GET "http://localhost:8080/instance/connect/clinic-instance" \
  -H "apikey: SUA_EVOLUTION_API_KEY" \
  | grep -o '"base64":"[^"]*' \
  | cut -d',' -f2 \
  | base64 -d > qrcode.png
```

---

## 4. Passo a Passo para Conectar no Aparelho

1. Abra o **WhatsApp** no aparelho celular de testes da clínica.
2. Vá em **Configurações / Ajustes** -> **Aparelhos Conectados**.
3. Toque em **Conectar um aparelho**.
4. Aponte a câmera para a imagem gerada em `qrcode.png` (ou utilize o código de pareamento, se preferir).
5. Após o pareamento, o status da instância muda para `open`.

### Verificar Estado da Conexão
```bash
curl -s -X GET "http://localhost:8080/instance/connectionState/clinic-instance" \
  -H "apikey: SUA_EVOLUTION_API_KEY"
```
Resposta esperada após pareamento:
```json
{"instance":{"instanceName":"clinic-instance","state":"open"}}
```

---

## 5. Eventos de Webhook Monitorados

A instância está parametrizada com os seguintes eventos habilitados apontando para o n8n:
- `MESSAGES_UPSERT`: Mensagens recebidas e enviadas (gatilho principal do agente IA na Fase 4).
- `MESSAGES_UPDATE`: Atualização de leitura/entrega de mensagens.
- `CONNECTION_UPDATE`: Mudança no status da conexão (conexão aberta, desconexão, expiração do QR Code).
- `QRCODE_UPDATED`: Notificação de novo QR Code gerado pelo Baileys.
