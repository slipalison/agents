# OpenCode Stack - Setup Script (Windows PowerShell)

$ErrorActionPreference = "Stop"

$Dest = if ($env:OPENCODE_CONFIG_DIR) { $env:OPENCODE_CONFIG_DIR } else { "$env:USERPROFILE\.config\opencode" }
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "==> Instalando OpenCode Stack em: $Dest"

# Backup se já existir
if (Test-Path $Dest) {
    $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $Backup = "$Dest.backup.$Timestamp"
    Write-Host "==> Diretório existente encontrado. Criando backup em: $Backup"
    Copy-Item -Path $Dest -Destination $Backup -Recurse
}

# Cria estrutura
New-Item -ItemType Directory -Force -Path "$Dest\agent" | Out-Null
New-Item -ItemType Directory -Force -Path "$Dest\skills" | Out-Null

# Copia config files
Copy-Item -Path "$ScriptDir\AGENTS.md" -Destination "$Dest\AGENTS.md" -Force
Copy-Item -Path "$ScriptDir\opencode.json" -Destination "$Dest\opencode.json" -Force

# Copia agentes
Copy-Item -Path "$ScriptDir\agent\*" -Destination "$Dest\agent\" -Recurse -Force

# Copia skills
Copy-Item -Path "$ScriptDir\skills\*" -Destination "$Dest\skills\" -Recurse -Force

Write-Host ""
Write-Host "==> Instalação concluída!"
Write-Host ""
Write-Host "Próximos passos:"
Write-Host "  1. Verifique os agentes:    opencode agent list"
Write-Host "  2. Inicie uma sessão:       cd C:\seu-projeto; opencode"
Write-Host "  3. Use Tab até o agente primário ser 'tech-lead'"
Write-Host ""

# Detecta se GSD e Caveman já estão instalados
$GsdInstalled     = (Test-Path "$Dest\skills") -and (Get-ChildItem "$Dest\skills" -Directory | Where-Object { $_.Name -like "gsd*" } | Select-Object -First 1)
$CavemanInstalled = Test-Path "$Dest\skills\caveman"

if ($GsdInstalled -and $CavemanInstalled) {
    Write-Host "==> GSD e Caveman já instalados — pulando."
} elseif (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Write-Host "⚠  npx não encontrado — instale Node.js e rode manualmente:"
    if (-not $GsdInstalled)     { Write-Host "  npx get-shit-done-cc@latest" }
    if (-not $CavemanInstalled) { Write-Host "  npx skills add JuliusBrussee/caveman" }
} else {
    $parts = @()
    if (-not $GsdInstalled)     { $parts += "GSD" }
    if (-not $CavemanInstalled) { $parts += "Caveman" }
    Write-Host -NoNewline "Instalar $($parts -join ' + ') agora? [Y/n]: "
    $answer = Read-Host
    if ($answer -notmatch '^[Nn]') {
        if (-not $GsdInstalled) {
            Write-Host ""
            Write-Host "==> GSD (Get Shit Done)"
            try { & npx get-shit-done-cc@latest }
            catch { Write-Host "⚠  GSD falhou — rode manualmente: npx get-shit-done-cc@latest" }
        }
        if (-not $CavemanInstalled) {
            Write-Host ""
            Write-Host "==> Caveman"
            try { & npx skills add JuliusBrussee/caveman }
            catch { Write-Host "⚠  Caveman falhou — rode manualmente: npx skills add JuliusBrussee/caveman" }
        }
    }
}
