# Implementation Plan: WhatsApp AI Triage System

## Contexto & Objetivos
- **Objetivo de Negócio:** Construir um protótipo local funcional de triagem de pacientes via WhatsApp para clínicas e consultórios, possibilitando a gravação de uma demonstração em vídeo (Loom) de 45 segundos para prospecção B2B.
- **Objetivo Técnico:** Estruturar o repositório sob padrões profissionais de engenharia de software (12-Factor App, conteinerização Docker, CI/CD com GitHub Actions, testes de integração de mensageria e versionamento de engenharia de prompt).

## Stack Tecnológica
- **Orquestrador de Fluxos:** n8n (Community/Self-Hosted)
- **Gateway de WhatsApp:** Evolution API (v2.x)
- **LLM / Raciocínio:** Google Gemini API (Gemini 1.5 / 2.0 Flash via Google AI Studio)
- **Persistência / CRM:** Google Sheets API
- **Infraestrutura Local:** Docker & Docker Compose
- **Qualidade & CI/CD:** GitHub Actions (Linting de Compose, JSON Linter, Gitleaks para secret scanning)
- **Automação de Scripts:** Makefile / Shell Script / Python (Smoke tests)

## Diretrizes de Git & Versionamento (GitFlow)
- Todo o desenvolvimento deve ocorrer a partir da branch `develop`.
- Cada fase deve ser executada obrigatoriamente em sua respectiva branch isolada:
  - Fase 1: `feature/infra-docker-setup`
  - Fase 2: `feature/evolution-gateway`
  - Fase 3: `feature/agent-prompts`
  - Fase 4: `feature/n8n-workflow`
  - Fase 5: `feature/ci-and-tests`
  - Fase 6: `feature/docs-readme`
- Ao concluir as tarefas de uma branch, o agente deve realizar o commit semântico e retornar para o usuário validar antes de realizar o merge ou seguir para a próxima.
---

## Estrutura do Diretório do Projeto

.
|-- .github/
|   `-- workflows/
|       `-- ci.yml               # Pipeline CI (compose lint, json lint, secret scan)
|-- docker-compose.yml           # Definição multi-container (n8n, evolution-api, redis/db)
|-- .env.example                 # Template documentado de variáveis de ambiente
|-- Makefile                     # Atalhos de execução (setup, run, down, test)
|-- prompts/
|   |-- triage_system_prompt.md  # System prompt versionado da assistente clínica
|   `-- booking_tool_schema.json # Declaração da ferramenta/schema de agendamento
|-- workflows/
|   `-- whatsapp_triage.json     # Export do workflow do n8n para versionamento
|-- tests/
|   |-- fixtures/                # Mocks de payloads recebidos da Evolution API
|   |   |-- text_message.json
|   |   `-- audio_message.json
|   `-- smoke_test.sh            # Script de teste de fumaça disparando webhooks locais
|-- docs/
|   `-- architecture.md          # Diagramas de sequência e topologia Mermaid
`-- README.md                    # Apresentação do projeto e guia de inicialização

---

## Fases de Execução

### Fase 1: Arquitetura e Infraestrutura de Containers (Docker)
- [ ] 1.1. Criar o arquivo `.env.example` contendo todas as variáveis exigidas (N8N_*, EVOLUTION_*, GEMINI_API_KEY, portas e chaves de criptografia).
- [ ] 1.2. Criar o `docker-compose.yml` integrando n8n e Evolution API em uma mesma rede Docker interna (bridge), configurando volumes persistentes para dados e instâncias.
- [ ] 1.3. Criar `Makefile` (ou `setup.sh`) com comandos padrão:
  - make setup: Cria cópia do .env e prepara diretórios.
  - make run: Executa docker compose up -d.
  - make logs: Monitora logs unificados.
  - make down: Encerra e limpa containers.
- [ ] 1.4. Validar inicialização local dos containers (docker compose up -d) e verificar se os painéis respondem nas portas configuradas.

### Fase 2: Configuração e Conexão da Evolution API
- [x] 2.1. Criar script curl/HTTP para inicializar a instância de WhatsApp da clínica via Evolution API.
- [x] 2.2. Configurar o Webhook global ou da instância apontando para a URL de webhook do n8n (http://n8n:5678/webhook/... ou porta mapeada).
- [x] 2.3. Gerar o QR Code no terminal/interface e documentar o comando para conectar o aparelho telefônico de teste.

### Fase 3: Engenharia de Prompts & Versionamento de IA
- [ ] 3.1. Criar o arquivo `prompts/triage_system_prompt.md` detalhando as instruções do agente:
  - Papel: Secretária virtual humanizada e cordial de uma clínica médica/odontológica.
  - Limite de resposta: Mensagens curtas e naturais (máximo 2 a 3 frases).
  - Regra de extração: Identificar e coletar estritamente 3 entidades obrigatórias: Nome Completo, Procedimento de Interesse e Turno de Preferência (Manhã/Tarde).
- [ ] 3.2. Criar `prompts/booking_tool_schema.json` definindo a Tool/Function Calling necessária para disparar a inserção na planilha somente com os 3 parâmetros preenchidos.

### Fase 4: Orquestração do Workflow no n8n
- [ ] 4.1. Configurar nó de Webhook Trigger (POST) para escutar eventos de mensagens recebidas (MESSAGES_UPSERT) da Evolution API.
- [ ] 4.2. Adicionar nó de Advanced AI Agent configurado com a API do Google Gemini.
- [ ] 4.3. Conectar o nó de Window Buffer Memory, parametrizando a chave de sessão (Session ID) com o identificador do remetente (remoteJid ou telefone) para preservar o histórico conversacional.
- [ ] 4.4. Conectar o nó do Google Sheets como ferramenta (Tool) da IA para registrar linhas com: [Data/Hora, Telefone, Nome, Procedimento, Turno].
- [ ] 4.5. Configurar o retorno HTTP enviando a mensagem final sintetizada de volta ao WhatsApp do usuário via endpoint de envio de texto da Evolution API.
- [ ] 4.6. Exportar o workflow concluído em formato JSON e versioná-lo em `workflows/whatsapp_triage.json`.

### Fase 5: Testes de Integração, Mocks & CI/CD
- [ ] 5.1. Criar pasta `tests/fixtures/` e salvar exemplos reais de JSON recebidos da Evolution API (text_message.json e audio_message.json).
- [ ] 5.2. Criar script de fumaça (`tests/smoke_test.sh`) que dispara uma requisição POST com o mock de mensagem diretamente contra o webhook do n8n local e valida o status 200 OK.
- [ ] 5.3. Configurar pipeline do GitHub Actions em `.github/workflows/ci.yml`:
  - Step de verificação de sintaxe: docker compose config.
  - Step de validação de JSONs do repositório (workflows e schemas).
  - Step de auditoria de segurança com Gitleaks para prevenir vazamento de secrets/API Keys.

### Fase 6: Documentação & Validação Final de Portfólio
- [ ] 6.1. Elaborar `README.md` completo:
  - Diagrama de arquitetura em blocos utilizando notação nativa Mermaid.
  - Visão geral da regra de negócio da triagem clínica.
  - Passo a passo de reprodução local (Quickstart com Docker).
  - Tabela explicativa das variáveis do .env.example.
- [ ] 6.2. Documentar o roteiro de execução do fluxo ponta a ponta no WhatsApp e validação da inserção de dados na planilha.
- [ ] 6.3. Incluir seção no README reservando o espaço para o link do vídeo demonstrativo (Loom).