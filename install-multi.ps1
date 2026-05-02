# agents_for_cli — Multi-Target Installer (Windows PowerShell / pwsh)
# Targets: OpenCode | Claude Code | GitHub Copilot | Antigravity
#
# Usage:
#   .\install-multi.ps1
#   .\install-multi.ps1 -Targets 1,2       # skip menu, install OpenCode + Claude Code
#   .\install-multi.ps1 -Targets all

param(
    [string]$Targets = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ── Menu ───────────────────────────────────────────────────────────────────────

function Show-Menu {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║      agents_for_cli — Multi-Target Installer   ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1) OpenCode       ($env:USERPROFILE\.config\opencode\)"
    Write-Host "  2) Claude Code    ($env:USERPROFILE\.claude\agents\ + skills\)"
    Write-Host "  3) Copilot        (.github\copilot-instructions.md + .vscode\)"
    Write-Host "  4) Antigravity    ($env:USERPROFILE\.config\antigravity\)"
    Write-Host "  5) Opencode CLI   (igual ao 1)"
    Write-Host ""
    Write-Host "  Selecione separando por vírgula ou digite 'all'"
    Write-Host -NoNewline "  → "
    return Read-Host
}

function Get-Selection([string]$raw) {
    if ($raw.Trim() -eq "all") { return @(1, 2, 3, 4) }
    $selected = [System.Collections.Generic.HashSet[int]]::new()
    $raw.Split(',') | ForEach-Object {
        $n = $_.Trim()
        if ($n -match '^[1-5]$') {
            $num = [int]$n
            if ($num -eq 5) { $num = 1 }  # alias
            [void]$selected.Add($num)
        }
    }
    return @($selected | Sort-Object)
}

# ── Frontmatter helpers ────────────────────────────────────────────────────────

function Get-FrontmatterField([string]$FilePath, [string]$Field) {
    $lines    = Get-Content $FilePath -Encoding UTF8
    $dashCount = 0
    foreach ($line in $lines) {
        if ($line -eq "---") {
            $dashCount++
            if ($dashCount -ge 2) { break }
            continue
        }
        if ($dashCount -eq 1 -and $line -match "^$([regex]::Escape($Field))\s*:\s*(.+)$") {
            return $Matches[1].Trim().Trim('"')
        }
    }
    return ""
}

function Test-ToolEnabled([string]$FilePath, [string]$Tool) {
    $lines     = Get-Content $FilePath -Encoding UTF8
    $dashCount = 0
    $inTools   = $false
    foreach ($line in $lines) {
        if ($line -eq "---") {
            $dashCount++
            if ($dashCount -ge 2) { break }
            continue
        }
        if ($dashCount -eq 1) {
            if ($line -match "^tools\s*:") { $inTools = $true; continue }
            if ($inTools -and $line -match "^[^\s]") { $inTools = $false }
            if ($inTools -and $line -match "^\s+$([regex]::Escape($Tool))\s*:\s*true") { return $true }
        }
    }
    return $false
}

function Get-AgentBody([string]$FilePath) {
    $lines     = Get-Content $FilePath -Encoding UTF8
    $dashCount = 0
    $body      = [System.Collections.Generic.List[string]]::new()
    $capturing = $false
    foreach ($line in $lines) {
        if ($line -eq "---") {
            $dashCount++
            if ($dashCount -eq 2) { $capturing = $true; continue }
        }
        if ($capturing) { $body.Add($line) }
    }
    # Trim leading blank line if present
    while ($body.Count -gt 0 -and $body[0] -eq "") { $body.RemoveAt(0) }
    return $body -join "`n"
}

# ── ADAPTER: OpenCode ──────────────────────────────────────────────────────────

function Install-OpenCode {
    $dest = if ($env:OPENCODE_CONFIG_DIR) { $env:OPENCODE_CONFIG_DIR } `
            else { "$env:USERPROFILE\.config\opencode" }

    Write-Host ""
    Write-Host "▶ OpenCode" -ForegroundColor Blue -NoNewline
    Write-Host " → $dest"

    if (Test-Path $dest) {
        $ts  = Get-Date -Format "yyyyMMdd-HHmmss"
        $bak = "$dest.backup.$ts"
        Write-Host "  backup → $bak"
        Copy-Item -Path $dest -Destination $bak -Recurse -Force
    }

    New-Item -ItemType Directory -Force -Path "$dest\agent"  | Out-Null
    New-Item -ItemType Directory -Force -Path "$dest\skills" | Out-Null
    Copy-Item "$ScriptDir\AGENTS.md"     "$dest\AGENTS.md"     -Force
    Copy-Item "$ScriptDir\opencode.json" "$dest\opencode.json" -Force
    Copy-Item "$ScriptDir\agent\*"       "$dest\agent\"        -Recurse -Force
    Copy-Item "$ScriptDir\skills\*"      "$dest\skills\"       -Recurse -Force

    Write-Host "  ✓ done" -ForegroundColor Green
    Write-Host "  Próximo: opencode agent list"
}

# ── ADAPTER: Claude Code ───────────────────────────────────────────────────────

function Convert-AgentToClaudeCode([string]$SrcFile, [string]$DestDir, [string]$Name) {
    $desc = Get-FrontmatterField $SrcFile "description"
    $mode = Get-FrontmatterField $SrcFile "mode"

    $toolLines = [System.Collections.Generic.List[string]]::new()
    foreach ($t in @("read", "write", "edit", "grep", "glob", "bash")) {
        if (Test-ToolEnabled $SrcFile $t) { $toolLines.Add("  - $t") }
    }
    if ($mode -eq "primary") {
        $toolLines.Add("  - task")
        $toolLines.Add("  - todowrite")
    }
    $toolsYaml = "tools:`n" + ($toolLines -join "`n")

    $body = Get-AgentBody $SrcFile

    $content = @"
---
name: $Name
description: $desc
model: claude-sonnet-4-6
$toolsYaml
---

$body
"@
    [System.IO.File]::WriteAllText("$DestDir\$Name.md", $content, [System.Text.Encoding]::UTF8)
}

function Install-ClaudeCode {
    $base      = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } `
                 else { "$env:USERPROFILE\.claude" }
    $agentsDir = "$base\agents"
    $skillsDir = "$base\skills"

    Write-Host ""
    Write-Host "▶ Claude Code" -ForegroundColor Blue -NoNewline
    Write-Host " → $base"

    New-Item -ItemType Directory -Force -Path $agentsDir | Out-Null
    New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null

    Get-ChildItem "$ScriptDir\agent\*.md" | ForEach-Object {
        $name = $_.BaseName
        Convert-AgentToClaudeCode $_.FullName $agentsDir $name
        Write-Host "  agent: $name"
    }

    Copy-Item "$ScriptDir\skills\*" "$skillsDir\" -Recurse -Force
    $skillCount = (Get-ChildItem "$ScriptDir\skills\" -Directory).Count
    Write-Host "  skills: $skillCount copiadas"

    # Append global rules to CLAUDE.md (guard against duplicates)
    $claudeMd = "$base\CLAUDE.md"
    $alreadyPresent = (Test-Path $claudeMd) -and `
                      ((Get-Content $claudeMd -Raw -Encoding UTF8) -match "BEGIN: agents_for_cli")
    if ($alreadyPresent) {
        Write-Host "  CLAUDE.md: regras já presentes — ignorado"
    } else {
        $globalRules = "`n<!-- BEGIN: agents_for_cli global rules -->`n" +
                       (Get-Content "$ScriptDir\AGENTS.md" -Raw -Encoding UTF8) +
                       "`n<!-- END: agents_for_cli global rules -->`n"
        Add-Content -Path $claudeMd -Value $globalRules -Encoding UTF8
        Write-Host "  CLAUDE.md: regras globais appended"
    }

    Write-Host "  ✓ done" -ForegroundColor Green
    Write-Host "  Uso: em qualquer projeto, @tech-lead para orquestrar"
}

# ── ADAPTER: GitHub Copilot ───────────────────────────────────────────────────

function Install-Copilot {
    Write-Host ""
    Write-Host "▶ GitHub Copilot" -ForegroundColor Blue
    Write-Host -NoNewline "  Diretório do projeto [$PWD]: "
    $inputDir    = Read-Host
    $projectDir  = if ($inputDir) { $inputDir } else { $PWD.Path }

    $ghDir     = "$projectDir\.github"
    $vscodeDir = "$projectDir\.vscode"
    New-Item -ItemType Directory -Force -Path $ghDir     | Out-Null
    New-Item -ItemType Directory -Force -Path $vscodeDir | Out-Null

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Custom Instructions for GitHub Copilot")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("> Generated by agents_for_cli — $(Get-Date -Format 'yyyy-MM-dd')")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine((Get-Content "$ScriptDir\AGENTS.md" -Raw -Encoding UTF8).TrimEnd())
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Agent Roles")
    [void]$sb.AppendLine("")

    Get-ChildItem "$ScriptDir\agent\*.md" | ForEach-Object {
        $name = $_.BaseName
        $desc = Get-FrontmatterField $_.FullName "description"
        $body = Get-AgentBody $_.FullName
        [void]$sb.AppendLine("### @$name")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("> $desc")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine($body)
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("---")
        [void]$sb.AppendLine("")
    }

    $outFile = "$ghDir\copilot-instructions.md"
    [System.IO.File]::WriteAllText($outFile, $sb.ToString(), [System.Text.Encoding]::UTF8)
    $lineCount = (Get-Content $outFile).Count
    Write-Host "  .github\copilot-instructions.md: $lineCount linhas"

    $settingsFile = "$vscodeDir\settings.json"
    if (Test-Path $settingsFile) {
        Write-Host "  .vscode\settings.json: já existe — não sobrescrevi"
        Write-Host '  Adicione: "github.copilot.chat.codeGeneration.useInstructionFiles": true'
    } else {
        $settings = @'
{
  "github.copilot.chat.codeGeneration.useInstructionFiles": true,
  "github.copilot.chat.codeGeneration.instructions": [
    { "file": ".github/copilot-instructions.md" }
  ]
}
'@
        [System.IO.File]::WriteAllText($settingsFile, $settings, [System.Text.Encoding]::UTF8)
        Write-Host "  .vscode\settings.json: criado"
    }

    Write-Host "  ✓ done" -ForegroundColor Green
    Write-Host "  Reinicie o VS Code para aplicar"
    Write-Host "  ⚠  Copilot CLI (gh copilot) não suporta agentes customizados" -ForegroundColor Yellow
}

# ── ADAPTER: Antigravity ───────────────────────────────────────────────────────

function Install-Antigravity {
    $dest = if ($env:ANTIGRAVITY_CONFIG_DIR) { $env:ANTIGRAVITY_CONFIG_DIR } `
            else { "$env:USERPROFILE\.config\antigravity" }

    Write-Host ""
    Write-Host "▶ Antigravity" -ForegroundColor Blue -NoNewline
    Write-Host " → $dest"
    Write-Host "  ⚠  Formato inferido — verifique a doc oficial do Antigravity" -ForegroundColor Yellow

    New-Item -ItemType Directory -Force -Path "$dest\agents" | Out-Null
    New-Item -ItemType Directory -Force -Path "$dest\skills" | Out-Null

    # agents.yaml manifest
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# agents_for_cli — Antigravity Config")
    [void]$sb.AppendLine("# Verifique o formato em: https://docs.antigravity.ai")
    [void]$sb.AppendLine("# Gerado em: $(Get-Date -Format 'yyyy-MM-dd')")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("global_instructions: AGENTS.md")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("agents:")

    Get-ChildItem "$ScriptDir\agent\*.md" | ForEach-Object {
        $name = $_.BaseName
        $desc = Get-FrontmatterField $_.FullName "description"
        $mode = Get-FrontmatterField $_.FullName "mode"
        $body = Get-AgentBody $_.FullName

        [void]$sb.AppendLine("  - name: $name")
        [void]$sb.AppendLine("    description: `"$desc`"")
        [void]$sb.AppendLine("    role: $mode")
        [void]$sb.AppendLine("    instructions: agents/$name.md")

        [System.IO.File]::WriteAllText("$dest\agents\$name.md", $body, [System.Text.Encoding]::UTF8)
        Write-Host "  agent: $name"
    }

    [System.IO.File]::WriteAllText("$dest\agents.yaml", $sb.ToString(), [System.Text.Encoding]::UTF8)
    Copy-Item "$ScriptDir\skills\*" "$dest\skills\" -Recurse -Force
    Copy-Item "$ScriptDir\AGENTS.md" "$dest\AGENTS.md" -Force

    Write-Host "  ✓ done" -ForegroundColor Green
    Write-Host "  ⚠  Revise $dest\agents.yaml e ajuste o schema se necessário" -ForegroundColor Yellow
}

# ── Main ───────────────────────────────────────────────────────────────────────

$raw = if ($Targets) { $Targets } else { Show-Menu }
$selection = Get-Selection $raw

if ($selection.Count -eq 0) {
    Write-Host "Nenhuma seleção válida. Saindo." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Instalando para: [$($selection -join ', ')]"

foreach ($num in $selection) {
    switch ($num) {
        1 { Install-OpenCode }
        2 { Install-ClaudeCode }
        3 { Install-Copilot }
        4 { Install-Antigravity }
    }
}

Write-Host ""
Write-Host "╔════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   Instalação concluída ✓       ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════╝" -ForegroundColor Green
