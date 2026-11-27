# computer.preparation

Lista de programas para instalar em um Windows recém-formatado, usando o [winget](https://learn.microsoft.com/windows/package-manager/winget/).

## Estrutura

```
computer.preparation/
├── install.ps1          # script que lê os JSON e instala via winget
├── packages/            # um arquivo por categoria
│   ├── dev-tools.json   # Git, ...
│   ├── editors.json     # Notepad++, VS Code, ...
│   └── utilities.json   # 7-Zip, ...
└── ssh/
    ├── ssh-keys.7z      # chaves SSH criptografadas (AES-256)
    ├── backup-ssh.ps1   # gera o .7z a partir de uma pasta de chaves
    └── restore-ssh.ps1  # extrai o .7z para ~/.ssh
```

## Chaves SSH

O repositório é **público**: as chaves só entram criptografadas, dentro de `ssh/ssh-keys.7z`.
O `.gitignore` bloqueia `id_rsa`, `known_hosts` etc. em texto aberto.

Restaurar na máquina nova (depois de instalar o 7-Zip):

```powershell
.\install.ps1 -Category utilities
.\ssh\restore-ssh.ps1        # pede a senha
ssh -T git@github.com
```

Atualizar o backup:

```powershell
.\ssh\backup-ssh.ps1 -Source "D:\caminho\das\chaves"   # pede a senha duas vezes
```

## Como usar

Abra o PowerShell **como administrador** na pasta do repositório:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force

.\install.ps1                          # instala tudo
.\install.ps1 -Category editors        # só uma categoria
.\install.ps1 -Category editors, dev-tools -WhatIf   # só mostra o que faria
```

Pacotes que já estão instalados são pulados.

## Adicionar um programa

1. Encontre o ID: `winget search <nome>`
2. Adicione no JSON da categoria (ou crie um novo arquivo em `packages/`):

```json
{ "id": "Git.Git", "name": "Git" }
```

Campo opcional `args` para parâmetros extras do winget:

```json
{ "id": "Python.Python.3.12", "name": "Python 3.12", "args": ["--scope", "machine"] }
```

Todos os pacotes são instalados com `-e --silent --accept-package-agreements --accept-source-agreements`.
