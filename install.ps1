<#
.SYNOPSIS
    Instala os programas listados em packages\*.json usando o winget.

.PARAMETER Category
    Nomes dos arquivos (sem .json) a instalar. Sem valor, instala todos.

.PARAMETER WhatIf
    Mostra o que seria instalado, sem instalar.

.EXAMPLE
    .\install.ps1
    .\install.ps1 -Category editors
    .\install.ps1 -Category editors, dev-tools -WhatIf
#>
[CmdletBinding()]
param(
    [string[]]$Category,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error 'winget nao encontrado. Instale/atualize o "App Installer" pela Microsoft Store.'
}

$packagesDir = Join-Path $PSScriptRoot 'packages'
$files = Get-ChildItem -Path $packagesDir -Filter '*.json' | Sort-Object Name

if ($Category) {
    $files = $files | Where-Object { $Category -contains $_.BaseName }
    $missing = $Category | Where-Object { $files.BaseName -notcontains $_ }
    if ($missing) { Write-Warning "Categorias nao encontradas: $($missing -join ', ')" }
}

$commonArgs = @('-e', '--silent', '--accept-package-agreements', '--accept-source-agreements')

# Codigos de saida do winget que nao sao falha
$WINGET_NO_UPDATE       = -1978335189  # 0x8A15002B: ja esta na versao mais recente
$WINGET_REBOOT_REQUIRED = -1978334967  # 0x8A150109: instalou, mas precisa reiniciar

$failed = @()
$rebootFor = @()

# Ativa recursos opcionais do Windows (campo "windowsFeatures" no JSON).
# Retorna $true se algum recurso foi ativado agora e pede reinicio.
function Enable-RequiredFeatures([string[]]$Features) {
    $restart = $false
    foreach ($feature in $Features) {
        $state = (Get-WindowsOptionalFeature -Online -FeatureName $feature).State
        if ($state -eq 'Enabled') {
            Write-Host "            recurso $feature ja ativo" -ForegroundColor DarkGray
            continue
        }
        Write-Host "            ativando recurso $feature" -ForegroundColor Green
        $result = Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart
        if ($result.RestartNeeded) { $restart = $true }
    }
    return $restart
}

foreach ($file in $files) {
    $data = Get-Content $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "`n=== $($data.category) ($($file.BaseName)) ===" -ForegroundColor Cyan

    foreach ($pkg in $data.packages) {
        $label = if ($pkg.name) { $pkg.name } else { $pkg.id }

        if ($pkg.windowsFeatures) {
            if ($WhatIf) {
                Write-Host "  [whatif]  ativar recursos: $($pkg.windowsFeatures -join ', ')" -ForegroundColor Yellow
            } elseif (Enable-RequiredFeatures $pkg.windowsFeatures) {
                $rebootFor += $label
            }
        }

        winget list --id $pkg.id -e --accept-source-agreements *> $null
        if ($LASTEXITCODE -eq 0) {
            if (-not $pkg.upgrade) {
                Write-Host "  [ok]      $label (ja instalado)" -ForegroundColor DarkGray
                continue
            }

            # Pacotes com "upgrade": true sao atualizados mesmo ja instalados
            $upgradeArgs = @('upgrade', '--id', $pkg.id) + $commonArgs
            if ($WhatIf) {
                Write-Host "  [whatif]  winget $($upgradeArgs -join ' ')" -ForegroundColor Yellow
                continue
            }

            Write-Host "  [upgrade] $label" -ForegroundColor Green
            winget @upgradeArgs
            switch ($LASTEXITCODE) {
                0                       { if ($pkg.reboot) { $rebootFor += $label } }
                $WINGET_REBOOT_REQUIRED { $rebootFor += $label }
                $WINGET_NO_UPDATE       { Write-Host "            ja esta na versao mais recente" -ForegroundColor DarkGray }
                default {
                    Write-Warning "Falha ao atualizar $label (codigo $LASTEXITCODE)"
                    $failed += $label
                }
            }
            continue
        }

        $installArgs = @('install', '--id', $pkg.id) + $commonArgs
        if ($pkg.args) { $installArgs += $pkg.args }

        if ($WhatIf) {
            Write-Host "  [whatif]  winget $($installArgs -join ' ')" -ForegroundColor Yellow
            continue
        }

        Write-Host "  [install] $label" -ForegroundColor Green
        winget @installArgs
        switch ($LASTEXITCODE) {
            0                       { if ($pkg.reboot) { $rebootFor += $label } }
            $WINGET_REBOOT_REQUIRED { $rebootFor += $label }
            default {
                Write-Warning "Falha ao instalar $label (codigo $LASTEXITCODE)"
                $failed += $label
            }
        }
    }
}

if ($rebootFor) {
    $rebootFor = $rebootFor | Select-Object -Unique
    Write-Host ''
    Write-Host '==================================================================' -ForegroundColor Yellow
    Write-Host ' REINICIE O COMPUTADOR antes de usar:' -ForegroundColor Yellow
    Write-Host "   $($rebootFor -join ', ')" -ForegroundColor Yellow
    Write-Host ''
    Write-Host ' Depois do reboot, confira:' -ForegroundColor Yellow
    Write-Host '   wsl --version              # deve responder na hora' -ForegroundColor Yellow
    Write-Host '   docker run hello-world     # com o Docker Desktop aberto' -ForegroundColor Yellow
    Write-Host '==================================================================' -ForegroundColor Yellow
}

if ($failed) {
    Write-Host "`nFalharam: $($failed -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host "`nConcluido." -ForegroundColor Cyan
