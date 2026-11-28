# computer.preparation

Lista de programas para instalar em um Windows recém-formatado, usando o [winget](https://learn.microsoft.com/windows/package-manager/winget/).

## Estrutura

```
computer.preparation/
├── install.ps1          # script que lê os JSON e instala via winget
├── packages/            # um arquivo por categoria
│   ├── containers.json  # WSL 2, Docker Desktop
│   ├── databases.json   # Redis Insight, DBeaver, ...
│   ├── dev-tools.json   # Git, Visual Studio 2026, ...
│   ├── editors.json     # Notepad++, VS Code, ...
│   ├── productivity.json # OneNote, Teams, ...
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

Pacotes que já estão instalados são pulados (exceto os marcados com `"upgrade": true`,
que são atualizados).

> [!IMPORTANT]
> **Docker Desktop: reinicie o PC depois da categoria `containers`.**
> O script ativa os recursos do Windows *Plataforma de Máquina Virtual* e
> *Subsistema do Windows para Linux*, que só passam a valer após reiniciar,
> e mostra um aviso no final quando o reboot é necessário.
> Não abra o Docker Desktop antes de reiniciar. Se abrir, ele falha com
> `DockerDesktop/Wsl/CommandTimedOut`.
> Depois do reboot:
>
> ```powershell
> wsl --version                 # deve responder na hora
> docker run hello-world        # com o Docker Desktop aberto
> ```
>
> Se `wsl --version` travar mesmo após reiniciar, rode `.\install.ps1 -Category containers`
> de novo (ele atualiza o WSL) e reinicie outra vez.
>
> Requer virtualização habilitada na BIOS/UEFI (Intel VT-x / AMD-V).

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

Outros campos opcionais:

| Campo             | Efeito                                                                 |
|-------------------|------------------------------------------------------------------------|
| `windowsFeatures` | recursos do Windows ativados antes de instalar (`Enable-WindowsOptionalFeature`) |
| `upgrade`         | `true`: se já estiver instalado, roda `winget upgrade` em vez de pular |
| `reboot`          | `true`: mostra o aviso de reinício no final quando o pacote é instalado/atualizado |

Todos os pacotes são instalados com `-e --silent --accept-package-agreements --accept-source-agreements`.
