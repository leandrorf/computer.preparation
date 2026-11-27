<#
.SYNOPSIS
    Extrai ssh\ssh-keys.7z para %USERPROFILE%\.ssh e restringe as permissoes
    das chaves privadas (o OpenSSH recusa chaves acessiveis por outros usuarios).

.EXAMPLE
    .\ssh\restore-ssh.ps1
#>
$ErrorActionPreference = 'Stop'

$sevenZip = "$env:ProgramFiles\7-Zip\7z.exe"
if (-not (Test-Path $sevenZip)) {
    Write-Error '7-Zip nao encontrado. Rode: .\install.ps1 -Category utilities'
}

$archive = Join-Path $PSScriptRoot 'ssh-keys.7z'
if (-not (Test-Path $archive)) { Write-Error "Arquivo nao encontrado: $archive" }

$dest = Join-Path $env:USERPROFILE '.ssh'
New-Item -ItemType Directory -Force -Path $dest | Out-Null

# -p sem valor: o 7-Zip pede a senha. -aoa sobrescreve arquivos existentes.
& $sevenZip x $archive "-o$dest" -p -aoa
if ($LASTEXITCODE -ne 0) { Write-Error "7-Zip falhou (codigo $LASTEXITCODE). Senha incorreta?" }

# Chaves privadas: remove heranca e deixa acesso somente ao usuario atual
Get-ChildItem $dest -File | Where-Object { $_.Name -like 'id_*' -and $_.Extension -ne '.pub' } | ForEach-Object {
    icacls $_.FullName /inheritance:r /grant:r "$($env:USERNAME):F" | Out-Null
    Write-Host "  permissoes ajustadas: $($_.Name)" -ForegroundColor DarkGray
}

Write-Host "`nChaves restauradas em $dest" -ForegroundColor Green
Write-Host 'Teste com: ssh -T git@github.com'
