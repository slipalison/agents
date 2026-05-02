# OpenCode Stack

Stack completa de OpenCode + GSD + Caveman para o workflow:
- **tech-lead** orquestra (primary)
- **csharp-developer** implementa backend .NET 10
- **frontend-developer** implementa React/TypeScript
- **code-validator** valida tudo antes do commit

## Pré-requisitos

```bash
# OpenCode
curl -fsSL https://opencode.ai/install | bash
# ou
npm i -g opencode-ai@latest

# Login no provider
opencode auth login

# GSD (modo minimal recomendado)
npx get-shit-done-cc --opencode --global --minimal

# Caveman
npx skills add JuliusBrussee/caveman -a opencode
```

## Instalação da stack

### Linux / macOS

```bash
unzip opencode-stack.zip
cd opencode-stack

# Backup do que já existe (se existir)
cp -r ~/.config/opencode ~/.config/opencode.backup.$(date +%Y%m%d) 2>/dev/null || true

# Copia os arquivos pro local correto
mkdir -p ~/.config/opencode/agent
mkdir -p ~/.config/opencode/skills

cp AGENTS.md ~/.config/opencode/AGENTS.md
cp opencode.json ~/.config/opencode/opencode.json
cp -r agent/* ~/.config/opencode/agent/
cp -r skills/* ~/.config/opencode/skills/
```

### Windows (PowerShell)

```powershell
Expand-Archive opencode-stack.zip -DestinationPath .
cd opencode-stack

$dest = "$env:USERPROFILE\.config\opencode"
New-Item -ItemType Directory -Force -Path "$dest\agent","$dest\skills"

Copy-Item AGENTS.md "$dest\AGENTS.md"
Copy-Item opencode.json "$dest\opencode.json"
Copy-Item agent\* "$dest\agent\" -Recurse -Force
Copy-Item skills\* "$dest\skills\" -Recurse -Force
```

## Validação

```bash
opencode agent list
# Deve listar: tech-lead, csharp-developer, frontend-developer, code-validator
```

## Uso

```bash
cd ~/projetos/sua-feature
opencode
```

Use `Tab` até o agente primário ser **tech-lead**.

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

## Estrutura

```
~/.config/opencode/
├── AGENTS.md                              # regras globais
├── opencode.json                          # modelos por agente
├── agent/
│   ├── tech-lead.md                       # primary
│   ├── csharp-developer.md
│   ├── frontend-developer.md
│   └── code-validator.md
└── skills/
    ├── csharp-rules/SKILL.md              # C# engineering standards
    ├── frontend-rules/SKILL.md            # Frontend standards
    ├── validation-checklist/SKILL.md      # Code validator reference
    ├── code-design-ddd/SKILL.md           # Domain-Driven Design
    ├── code-design-vertical-slice/SKILL.md # Vertical Slice
    ├── code-design-the-method/SKILL.md    # The Method (Juval Löwy)
    ├── code-design-clean-architecture/SKILL.md # Clean Architecture
    ├── code-design-hexagonal/SKILL.md     # Hexagonal (Ports & Adapters)
    ├── volatility-decomposition/SKILL.md  # VBD reference (The Method)
    └── service-taxonomy-mer/SKILL.md      # MER taxonomy (The Method)
```

## Customização rápida

- **Trocar modelo de algum agente**: edite `opencode.json`
- **Mudar nível do Caveman**: edite seção "Communication mode" no `AGENTS.md`
- **Adicionar regras**: novo `SKILL.md` em `skills/<nome>/`
- **Personalizar validador**: ajuste o checklist em `agent/code-validator.md`

## Notas conhecidas

- **MCP em subagent**: bug aberto no OpenCode faz subagents não terem permissão pra MCP tools. Se algum agente precisar de MCP, invoque pelo tech-lead.
- **GSD --minimal**: para manter a economia de ~12k tokens, sempre atualize com `--minimal`:
  ```bash
  npx get-shit-done-cc@latest --opencode --global --minimal
  ```
- **Caveman + Validator**: o validator usa caveman no texto conversacional, mas o bloco YAML de output permanece estruturado e não comprimido.
