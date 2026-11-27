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
$failed = @()

foreach ($file in $files) {
    $data = Get-Content $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "`n=== $($data.category) ($($file.BaseName)) ===" -ForegroundColor Cyan

    foreach ($pkg in $data.packages) {
        $label = if ($pkg.name) { $pkg.name } else { $pkg.id }

        winget list --id $pkg.id -e --accept-source-agreements *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [ok]      $label (ja instalado)" -ForegroundColor DarkGray
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
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Falha ao instalar $label (codigo $LASTEXITCODE)"
            $failed += $label
        }
    }
}

if ($failed) {
    Write-Host "`nFalharam: $($failed -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host "`nConcluido." -ForegroundColor Cyan
