# agents_for_cli

Stack de agentes para desenvolvimento full-stack .NET 10 + React 19, instalável em múltiplos CLIs e IDEs:

| Agente | Papel |
|---|---|
| **tech-lead** | Orquestra workflow GSD, despacha subagents (primary) |
| **csharp-developer** | Implementa backend .NET 10 / C# |
| **frontend-developer** | Implementa React 19 + TypeScript |
| **code-validator** | Gate de qualidade — Security → Performance → Best Practices |

## Destinos suportados

| # | Destino | Onde instala |
|---|---|---|
| 1 | **OpenCode** | `~/.config/opencode/` |
| 2 | **Claude Code** | `~/.claude/agents/` + `~/.claude/skills/` |
| 3 | **GitHub Copilot** | `.github/copilot-instructions.md` + `.vscode/settings.json` |
| 4 | **Antigravity** | `~/.config/antigravity/` |

Pode instalar um ou vários ao mesmo tempo.

## Pré-requisitos por destino

### OpenCode
```bash
npm i -g opencode-ai@latest
opencode auth login
npx get-shit-done-cc --opencode --global --minimal
npx skills add JuliusBrussee/caveman -a opencode
```

### Claude Code
```bash
npm i -g @anthropic-ai/claude-code
# ou via desktop app: https://claude.ai/download
```

### GitHub Copilot
- VS Code com extensão GitHub Copilot instalada
- Copilot CLI: `gh extension install github/gh-copilot`

### Antigravity
- Siga a instalação oficial do Antigravity

## Instalação

### Linux / macOS

```bash
# Clone ou extraia o repo
cd agents_for_cli

# Tornar executável
chmod +x install-multi.sh

# Rodar o installer interativo
./install-multi.sh
```

Menu interativo:
```
→ 1         # só OpenCode
→ 2         # só Claude Code
→ 1,2       # OpenCode + Claude Code
→ all       # todos os destinos
```

### Windows (PowerShell)

```powershell
cd agents_for_cli

# Installer interativo
.\install-multi.ps1

# Ou direto, sem menu:
.\install-multi.ps1 -Targets "1,2"
.\install-multi.ps1 -Targets all
```

### Variáveis de ambiente (override de path)

| Variável | Destino | Padrão |
|---|---|---|
| `OPENCODE_CONFIG_DIR` | OpenCode | `~/.config/opencode` |
| `CLAUDE_CONFIG_DIR` | Claude Code | `~/.claude` |
| `ANTIGRAVITY_CONFIG_DIR` | Antigravity | `~/.config/antigravity` |

## O que cada adapter faz

### OpenCode
Copia `agent/*.md`, `skills/`, `AGENTS.md` e `opencode.json` para o diretório de config.

### Claude Code
- **Converte** o frontmatter opencode → formato Claude Code (`name`, `model`, `tools` como lista)
- **Instala** agentes em `~/.claude/agents/`
- **Copia** skills (mesmo formato) em `~/.claude/skills/`
- **Appenda** `AGENTS.md` no `~/.claude/CLAUDE.md` como contexto global

### GitHub Copilot
- Gera `.github/copilot-instructions.md` com `AGENTS.md` + instruções de todos os agentes combinadas
- Cria `.vscode/settings.json` com `useInstructionFiles: true`
- **Nota**: Copilot CLI (`gh copilot`) não suporta agentes customizados — apenas VS Code

### Antigravity
- Gera `agents.yaml` como manifesto de agentes
- Copia corpos dos agentes (sem frontmatter opencode) em `agents/<name>.md`
- **Nota**: formato inferido — verifique a doc oficial e ajuste `agents.yaml` se necessário

## Validação pós-instalação

```bash
# OpenCode
opencode agent list

# Claude Code
ls ~/.claude/agents/
# tech-lead.md  csharp-developer.md  frontend-developer.md  code-validator.md

# Copilot (verificar arquivo gerado)
cat .github/copilot-instructions.md | head -5
```

## Uso

### OpenCode
```bash
cd ~/projetos/sua-feature
opencode
# Tab até agente primário = tech-lead
```

### Claude Code
```bash
cd ~/projetos/sua-feature
claude
# Use @tech-lead para orquestrar
```

### Copilot (VS Code)
Reinicie o VS Code. Copilot Chat agora aplica as instruções dos agentes automaticamente no projeto onde instalou.

### Workflow padrão

```
você → tech-lead
        │
        ├─→ /gsd-new-project        (spec inicial)
        ├─→ /gsd-plan-phase 1       (plano atômico)
        │
        ├─→ @csharp-developer       (executa task backend)
        │   └─→ @code-validator     (gate)
        │       ├─ PASS → próxima task
        │       └─ FAIL → volta pro dev
        │
        └─→ @frontend-developer     (executa task frontend)
            └─→ @code-validator     (gate)
```

## Estrutura do repo

```
agents_for_cli/
├── install-multi.sh          # installer interativo (Linux/macOS)
├── install-multi.ps1         # installer interativo (Windows / pwsh)
├── install.sh                # installer legado OpenCode-only (Linux/macOS)
├── install.ps1               # installer legado OpenCode-only (Windows)
├── AGENTS.md                 # regras globais de engenharia
├── opencode.json             # mapeamento modelo↔agente (OpenCode)
├── agent/
│   ├── tech-lead.md          # primary — orquestra
│   ├── csharp-developer.md   # subagent — backend .NET
│   ├── frontend-developer.md # subagent — frontend React
│   └── code-validator.md     # subagent — gate de qualidade
└── skills/
    ├── csharp-rules/         # C# engineering standards
    ├── frontend-rules/       # Frontend standards
    ├── validation-checklist/ # Code validator reference
    ├── code-design-ddd/
    ├── code-design-vertical-slice/
    ├── code-design-the-method/
    ├── code-design-clean-architecture/
    ├── code-design-hexagonal/
    ├── volatility-decomposition/
    └── service-taxonomy-mer/
```

## Customização rápida

- **Trocar modelo**: edite `opencode.json` (OpenCode) ou o campo `model:` nos `.md` gerados (Claude Code)
- **Mudar nível do Caveman**: edite seção "Communication mode" no `AGENTS.md`
- **Adicionar skill**: novo `SKILL.md` em `skills/<nome>/` — é copiado para todos os destinos
- **Personalizar validador**: ajuste o checklist em `agent/code-validator.md`
- **Novo agente**: crie `agent/<nome>.md` com frontmatter opencode — o installer converte automaticamente

## Notas conhecidas

- **Antigravity**: formato de `agents.yaml` é inferido. Ajuste o schema conforme a doc oficial.
- **Copilot CLI** (`gh copilot`): não suporta agentes customizados. Apenas VS Code se beneficia da instalação.
- **Claude Code + skills**: skills no formato `skills/<nome>/SKILL.md` são copiadas diretamente pois o formato é compatível.
- **MCP em subagent (OpenCode)**: bug aberto faz subagents não terem permissão pra MCP tools — invoque pelo tech-lead.
- **GSD --minimal**: sempre atualize com `--minimal` para economizar tokens:
  ```bash
  npx get-shit-done-cc@latest --opencode --global --minimal
  ```
