<#
.SYNOPSIS
    Cria ssh\ssh-keys.7z (AES-256, nomes de arquivo tambem criptografados)
    a partir de uma pasta com as chaves SSH. O 7-Zip pede a senha no terminal.

.EXAMPLE
    .\ssh\backup-ssh.ps1 -Source "D:\lrf\leandro\Desenvolvimento\git\ssh-Particular"
#>
param(
    [string]$Source = "$env:USERPROFILE\.ssh"
)

$ErrorActionPreference = 'Stop'

$sevenZip = "$env:ProgramFiles\7-Zip\7z.exe"
if (-not (Test-Path $sevenZip)) {
    Write-Error '7-Zip nao encontrado. Rode: .\install.ps1 -Category utilities'
}

$files = Get-ChildItem -Path $Source -File | Where-Object { $_.Name -match '^(id_|known_hosts|config$)' }
if (-not $files) { Write-Error "Nenhuma chave encontrada em $Source" }

$out = Join-Path $PSScriptRoot 'ssh-keys.7z'
if (Test-Path $out) { Remove-Item $out }

Write-Host "Arquivos: $($files.Name -join ', ')" -ForegroundColor Cyan
Write-Host 'Use uma senha forte: o arquivo vai para um repositorio publico.' -ForegroundColor Yellow

# -p sem valor: o 7-Zip pede a senha (e a confirmacao) interativamente
& $sevenZip a -t7z -mhe=on -p $out $files.FullName
if ($LASTEXITCODE -ne 0) { Write-Error "7-Zip falhou (codigo $LASTEXITCODE)" }

Write-Host "`nCriado: $out" -ForegroundColor Green
