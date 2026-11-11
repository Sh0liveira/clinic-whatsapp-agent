param(
    [string]$InstanceName,
    [string]$ServerUrl,
    [string]$ApiKey,
    [switch]$NoImage
)

$ErrorActionPreference = "Stop"

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

$InstanceName = if ($InstanceName) { $InstanceName } elseif ($env:EVOLUTION_INSTANCE_NAME) { $env:EVOLUTION_INSTANCE_NAME } else { "clinic-instance" }
$ServerUrl    = if ($ServerUrl) { $ServerUrl } elseif ($env:EVOLUTION_SERVER_URL) { $env:EVOLUTION_SERVER_URL } else { "http://localhost:8080" }
$ApiKey       = if ($ApiKey) { $ApiKey } elseif ($env:EVOLUTION_API_KEY) { $env:EVOLUTION_API_KEY } else { "" }

if (-not $ApiKey) {
    Write-Error "ERRO: EVOLUTION_API_KEY não informada e não encontrada no .env"
    exit 1
}

$headers = @{
    "apikey"       = $ApiKey
    "Content-Type" = "application/json"
}

Write-Host "Obtendo QR Code de conexão para a instância '$InstanceName'..." -ForegroundColor Cyan

# 1. Verificar estado da conexão
try {
    $state = Invoke-RestMethod -Uri "$ServerUrl/instance/connectionState/$InstanceName" -Method Get -Headers $headers
    $currentState = if ($state.instance.state) { $state.instance.state } else { $state.state }
    if ($currentState -eq "open") {
        Write-Host "Aviso: A instância '$InstanceName' JÁ ESTÁ CONECTADA (Status: open)!" -ForegroundColor Green
        exit 0
    }
} catch {
    Write-Host "Consultando connect..." -ForegroundColor DarkGray
}

# 2. Solicitar QR Code / Connect
try {
    $connectResp = Invoke-RestMethod -Uri "$ServerUrl/instance/connect/$InstanceName" -Method Get -Headers $headers
} catch {
    Write-Error "Falha ao conectar com a instância '$InstanceName': $_"
    exit 1
}

$base64Data = $null
if ($connectResp.base64) {
    $base64Data = $connectResp.base64
} elseif ($connectResp.qrcode -and $connectResp.qrcode.base64) {
    $base64Data = $connectResp.qrcode.base64
}

$pairingCode = $null
if ($connectResp.pairingCode) {
    $pairingCode = $connectResp.pairingCode
}

$code = $null
if ($connectResp.code) {
    $code = $connectResp.code
} elseif ($connectResp.qrcode -and $connectResp.qrcode.code) {
    $code = $connectResp.qrcode.code
}

Write-Host "==========================================================" -ForegroundColor Green
Write-Host " DADOS DE AUTENTICAÇÃO WHATSAPP" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

if ($pairingCode) {
    Write-Host "Código de Pareamento (Pairing Code): $pairingCode" -ForegroundColor Yellow
}

if ($code) {
    Write-Host "String do QR Code: $code" -ForegroundColor DarkCyan
}

if ($base64Data) {
    # Remover cabeçalho se houver (data:image/png;base64,)
    $rawBase64 = $base64Data
    if ($rawBase64.Contains(",")) {
        $rawBase64 = $rawBase64.Substring($rawBase64.IndexOf(",") + 1)
    }
    
    $outputPath = Join-Path $ProjectRoot "qrcode.png"
    [System.IO.File]::WriteAllBytes($outputPath, [System.Convert]::FromBase64String($rawBase64))
    Write-Host ""
    Write-Host "-> Imagem do QR Code salva com sucesso em: $outputPath" -ForegroundColor Cyan

    if (-not $NoImage) {
        Write-Host "-> Abrindo imagem do QR Code para leitura no aparelho..." -ForegroundColor Yellow
        Start-Process $outputPath
    }
} else {
    Write-Host "Nota: A API não retornou imagem base64 diretamente nesta chamada (pode estar conectando ou já conectada)." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Abra o WhatsApp no celular -> Aparelhos Conectados -> Conectar Aparelho e escaneie o QR Code." -ForegroundColor White
