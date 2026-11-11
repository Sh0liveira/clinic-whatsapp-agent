param(
    [string]$InstanceName,
    [string]$WebhookUrl,
    [string]$ServerUrl,
    [string]$ApiKey
)

$ErrorActionPreference = "Stop"

# Helper para carregar variáveis do .env caso não estejam definidas no ambiente
function Load-DotEnv {
    param([string]$FilePath = ".env")
    if (Test-Path $FilePath) {
        Get-Content $FilePath | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
                $parts = $line -split "=", 2
                $key = $parts[0].Trim()
                $val = $parts[1].Trim().Trim('"').Trim("'")
                if (-not [System.Environment]::GetEnvironmentVariable($key)) {
                    [System.Environment]::SetEnvironmentVariable($key, $val, "Process")
                }
            }
        }
    }
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..")
Load-DotEnv (Join-Path $ProjectRoot ".env")

# Valores e fallbacks (12-Factor App)
$InstanceName = if ($InstanceName) { $InstanceName } elseif ($env:EVOLUTION_INSTANCE_NAME) { $env:EVOLUTION_INSTANCE_NAME } else { "clinic-instance" }
$WebhookUrl   = if ($WebhookUrl) { $WebhookUrl } elseif ($env:EVOLUTION_WEBHOOK_URL) { $env:EVOLUTION_WEBHOOK_URL } else { "http://n8n:5678/webhook/evolution" }
$ServerUrl    = if ($ServerUrl) { $ServerUrl } elseif ($env:EVOLUTION_SERVER_URL) { $env:EVOLUTION_SERVER_URL } else { "http://localhost:8080" }
$ApiKey       = if ($ApiKey) { $ApiKey } elseif ($env:EVOLUTION_API_KEY) { $env:EVOLUTION_API_KEY } else { "" }

if (-not $ApiKey) {
    Write-Error "ERRO: EVOLUTION_API_KEY não foi informada e não foi encontrada no ambiente ou .env"
    exit 1
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Inicialização da Instância - Evolution API v2" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Instância   : $InstanceName"
Write-Host "Server URL  : $ServerUrl"
Write-Host "Webhook URL : $WebhookUrl"
Write-Host ""

$headers = @{
    "apikey"       = $ApiKey
    "Content-Type" = "application/json"
}

# 1. Verificar conectividade com a Evolution API
Write-Host "[1/3] Verificando se a Evolution API está acessível..." -ForegroundColor Yellow
try {
    $healthCheck = Invoke-RestMethod -Uri "$ServerUrl/instance/fetchInstances" -Method Get -Headers $headers -TimeoutSec 10
    Write-Host " -> Conexão com Evolution API estabelecida com sucesso." -ForegroundColor Green
} catch {
    Write-Error "Não foi possível conectar a Evolution API em $($ServerUrl): $_"
    exit 1
}

# 2. Verificar se a instância já existe
Write-Host "[2/3] Verificando existência da instância '$InstanceName'..." -ForegroundColor Yellow
$instanceExists = $false
try {
    $existing = Invoke-RestMethod -Uri "$ServerUrl/instance/fetchInstances" -Method Get -Headers $headers
    if ($existing) {
        foreach ($inst in $existing) {
            $name = if ($inst.name) { $inst.name } else { $inst.instance.instanceName }
            if ($name -eq $InstanceName) {
                $instanceExists = $true
                break
            }
        }
    }
} catch {
    Write-Host "Aviso ao listar instâncias: $_" -ForegroundColor DarkGray
}

if ($instanceExists) {
    Write-Host " -> Instância '$InstanceName' já existe. Pulando criação (idempotente)." -ForegroundColor Cyan
} else {
    Write-Host " -> Criando instância '$InstanceName'..." -ForegroundColor Yellow
    $createBody = @{
        instanceName = $InstanceName
        token        = ""
        qrcode       = $true
        integration  = "WHATSAPP-BAILEYS"
        webhook      = @{
            enabled  = $true
            url      = $WebhookUrl
            byEvents = $false
            base64   = $true
            events   = @(
                "MESSAGES_UPSERT",
                "MESSAGES_UPDATE",
                "CONNECTION_UPDATE",
                "QRCODE_UPDATED"
            )
        }
    } | ConvertTo-Json -Depth 5

    try {
        $createResponse = Invoke-RestMethod -Uri "$ServerUrl/instance/create" -Method Post -Headers $headers -Body $createBody
        Write-Host " -> Instância '$InstanceName' criada com sucesso!" -ForegroundColor Green
    } catch {
        $respBody = $_.ErrorDetails.Message
        if ($respBody -like "*already exists*" -or $respBody -like "*already in use*") {
            Write-Host " -> Instância '$InstanceName' já constava como criada." -ForegroundColor Cyan
        } else {
            Write-Error "Falha ao criar instância: $_ `n$respBody"
            exit 1
        }
    }
}

# 3. Configurar/Atualizar Webhook explicitamente (garante idempotência e sincronização de URL)
Write-Host "[3/3] Configurando Webhook da instância para '$WebhookUrl'..." -ForegroundColor Yellow
$webhookBody = @{
    webhook = @{
        enabled  = $true
        url      = $WebhookUrl
        byEvents = $false
        base64   = $true
        events   = @(
            "MESSAGES_UPSERT",
            "MESSAGES_UPDATE",
            "CONNECTION_UPDATE",
            "QRCODE_UPDATED"
        )
    }
} | ConvertTo-Json -Depth 5

try {
    $webhookResponse = Invoke-RestMethod -Uri "$ServerUrl/webhook/set/$InstanceName" -Method Post -Headers $headers -Body $webhookBody
    Write-Host " -> Webhook configurado com sucesso!" -ForegroundColor Green
} catch {
    Write-Warning "Falha ao definir webhook na rota /webhook/set: $_"
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host " Instância '$InstanceName' pronta para conexão!" -ForegroundColor Green
Write-Host " Próximo passo: execute o script de QR Code para parear:" -ForegroundColor Green
Write-Host "   powershell -ExecutionPolicy Bypass -File scripts/evolution-qrcode.ps1" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green
