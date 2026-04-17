param(
    [ValidateSet('install', 'start', 'stop', 'status', 'logs', 'restart', 'reset', 'profiles', 'open')]
    [string]$Action
)

$ErrorActionPreference = 'Stop'
$BocaDockerDir = Join-Path $PSScriptRoot 'boca-docker'
$ProfilesScript = Join-Path $PSScriptRoot 'setup_boca_profiles.ps1'
$BocaUrl = 'http://localhost:8000/boca'
$ComposeArgs = @('-f', 'docker-compose.yml', '-f', 'docker-compose.prod.yml')

function Write-Section([string]$Text) {
    Write-Host ''
    Write-Host "Caramel Coders BOCA - $Text" -ForegroundColor Cyan
}

function Assert-BocaDockerDir {
    if (-not (Test-Path $BocaDockerDir)) {
        throw "Diretorio nao encontrado: $BocaDockerDir"
    }
}

function Test-Prerequisites {
    & docker --version | Out-Null
    & docker compose version --short | Out-Null
    & docker info | Out-Null
}

function Invoke-BocaCompose([string[]]$Arguments) {
    Assert-BocaDockerDir
    Push-Location $BocaDockerDir
    try {
        & docker compose @ComposeArgs @Arguments
    }
    finally {
        Pop-Location
    }
}

function Wait-Boca {
    $deadline = (Get-Date).AddMinutes(3)
    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri $BocaUrl -TimeoutSec 10
            if ($response.StatusCode -in 200, 302) {
                return $true
            }
        }
        catch {
        }
        Start-Sleep -Seconds 5
    }
    return $false
}

function Apply-Profiles {
    Assert-BocaDockerDir
    & $ProfilesScript
}

function Install-Boca {
    Write-Section 'Install'
    Test-Prerequisites
    Invoke-BocaCompose @('up', '-d', '--build')
    if (-not (Wait-Boca)) {
        throw 'BOCA nao respondeu dentro do tempo esperado.'
    }
    Apply-Profiles
    Write-Host "BOCA: $BocaUrl"
    Write-Host 'Grafana: http://localhost:3001'
}

function Start-Boca {
    Write-Section 'Start'
    Invoke-BocaCompose @('up', '-d')
    if (-not (Wait-Boca)) {
        throw 'BOCA nao respondeu dentro do tempo esperado.'
    }
    Write-Host "BOCA: $BocaUrl"
}

function Stop-Boca {
    Write-Section 'Stop'
    Invoke-BocaCompose @('down')
}

function Get-BocaStatus {
    Write-Section 'Status'
    Invoke-BocaCompose @('ps')
}

function Get-BocaLogs {
    Write-Section 'Logs'
    Invoke-BocaCompose @('logs', '-f', '--tail=50')
}

function Restart-Boca {
    Write-Section 'Restart'
    Invoke-BocaCompose @('restart')
    if (-not (Wait-Boca)) {
        throw 'BOCA nao respondeu dentro do tempo esperado.'
    }
    Write-Host "BOCA: $BocaUrl"
}

function Reset-Boca {
    Write-Section 'Reset'
    $confirmation = Read-Host 'Digite SIM para remover containers e volumes'
    if ($confirmation -ne 'SIM') {
        Write-Host 'Operacao cancelada.'
        return
    }
    Invoke-BocaCompose @('down', '-v')
}

function Open-Boca {
    Start-Process $BocaUrl
}

function Show-Menu {
    while ($true) {
        Write-Section 'Menu'
        Write-Host '1. install'
        Write-Host '2. start'
        Write-Host '3. stop'
        Write-Host '4. status'
        Write-Host '5. logs'
        Write-Host '6. restart'
        Write-Host '7. reset'
        Write-Host '8. profiles'
        Write-Host '9. open'
        Write-Host '0. sair'
        $choice = Read-Host 'Escolha uma opcao'
        switch ($choice) {
            '1' { Install-Boca }
            '2' { Start-Boca }
            '3' { Stop-Boca }
            '4' { Get-BocaStatus }
            '5' { Get-BocaLogs }
            '6' { Restart-Boca }
            '7' { Reset-Boca }
            '8' { Apply-Profiles }
            '9' { Open-Boca }
            '0' { return }
            default { Write-Host 'Opcao invalida.' }
        }
    }
}

switch ($Action) {
    'install' { Install-Boca }
    'start' { Start-Boca }
    'stop' { Stop-Boca }
    'status' { Get-BocaStatus }
    'logs' { Get-BocaLogs }
    'restart' { Restart-Boca }
    'reset' { Reset-Boca }
    'profiles' { Apply-Profiles }
    'open' { Open-Boca }
    default { Show-Menu }
}
