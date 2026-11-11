.PHONY: help setup run logs down restart status evolution-init evolution-qr

help:
	@echo "Comandos disponíveis:"
	@echo "  make setup          - Cria o arquivo .env a partir de .env.example se não existir"
	@echo "  make run            - Sobe os containers em background (docker compose up -d)"
	@echo "  make logs           - Acompanha os logs unificados de todos os containers"
	@echo "  make down           - Para e remove os containers e redes"
	@echo "  make restart        - Reinicia os serviços"
	@echo "  make status         - Exibe o status dos containers"
	@echo "  make evolution-init - Inicializa e configura a instância do WhatsApp na Evolution API"
	@echo "  make evolution-qr   - Gera o QR Code de autenticação do WhatsApp"

setup:
	@if not exist .env (copy .env.example .env) else (echo .env já existe) 2>nul || cp -n .env.example .env || true
	@echo "Setup de ambiente concluído."

run:
	docker compose up -d

logs:
	docker compose logs -f

down:
	docker compose down

restart:
	docker compose restart

status:
	docker compose ps

evolution-init:
	@if exist scripts\evolution-init.ps1 (powershell -ExecutionPolicy Bypass -File scripts/evolution-init.ps1) else (bash scripts/evolution-init.sh)

evolution-qr:
	@if exist scripts\evolution-qrcode.ps1 (powershell -ExecutionPolicy Bypass -File scripts/evolution-qrcode.ps1) else (bash scripts/evolution-qrcode.sh)
