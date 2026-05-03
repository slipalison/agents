# Engineering Standards (Global)

Estas regras se aplicam a TODOS os agentes em TODAS as sessões deste OpenCode.

## Stack baseline

- **Backend**: .NET 10 / C# 14 (nunca downgrade)
- **Frontend**: React 19.x + TypeScript 5.7+ strict + Vinxi + TanStack Router + Tailwind CSS 4
- **Infra**: Kubernetes em Azure/AWS, Redis, PostgreSQL, microsserviços
- **Observabilidade**: OpenTelemetry (W3C Trace Context) + Serilog (structured logging) + Datadog/Grafana
- **Frontend apps**: Client (porta 5173) e Backoffice (porta 5174)

## Communication mode (Caveman)

Use **caveman mode (full level)** para todas as respostas conversacionais.
Skill: `~/.config/opencode/skills/caveman/SKILL.md`

### Exceções (NÃO usar caveman)

1. Dentro de blocos YAML estruturados (output do `code-validator` é YAML — caveman só no texto fora do YAML)
2. Quando gerando arquivos de planejamento GSD (`.planning/*`)
3. Quando gerando código (código nunca é comprimido)
4. Quando gerando ADR, RFC ou documentação técnica formal
5. Em commit messages (use o skill `caveman-commit` específico)

## Architectural principles

Aplicar nesta ordem de prioridade:

1. **Cadeia de prioridade**: Segurança → Performance → Boas Práticas. Sempre nessa ordem.
2. **Code Design locked** — selecionado por projeto via skill `code-design-*`. Não misture, não mude.
3. **SOLID**: especialmente ISP (Interface Segregation) e DIP (Dependency Inversion).
4. **DRY, KISS, YAGNI, Clean Code** — mas nunca sacrificar clareza por elegância.
5. **80% mínimo** de cobertura de testes — gate inviolável.
6. **Nunca refatore por estética** — só por segurança, performance, ou bug.
7. **Diagramas Mermaid** embarcados em Markdown apenas (nunca PNG/SVG).

## Code Design

Cada projeto seleciona UM code design e ele é LOCKED para toda a vida do projeto:

| Skill | Design |
|---|---|
| `code-design-ddd` | Domain-Driven Design |
| `code-design-vertical-slice` | Vertical Slice Architecture |
| `code-design-the-method` | The Method (Juval Löwy) |
| `code-design-clean-architecture` | Clean Architecture (Uncle Bob) |
| `code-design-hexagonal` | Hexagonal (Ports & Adapters) |

Registre a escolha em `.planning/CODE-DESIGN.md`. Uma vez decidido, não mude.

## Frontend architecture

- **Atomic Design**: atoms → molecules → organisms → templates → pages → guards + ui (shadcn)
- **Auth**: Authorization Code Flow + PKCE — tokens 100% server-side em httpOnly cookies
- **Sem `keycloak-js`**, sem `localStorage` para tokens — decisão de segurança fundamental
- **Validação**: Zod schemas espelhando regras do backend/Keycloak

## Git rules

- **Conventional Commits** (use skill `caveman-commit` para gerar)
- **Atomic commits** por task (uma task GSD = um commit)
- `--no-verify` em commits de subagents (parallel-safe; orchestrator roda hooks após cada wave)
- Branch naming: `feat/<phase-num>-<slug>` ou `fix/<issue-id>`

## Workflow GSD

Quando dentro de um workflow GSD ativo:

- Respeite as decisões locked (`D-XX`) do plano — referencie em commits e PRs
- "Deferred Ideas" do plano NÃO devem aparecer na implementação
- Cada task deve fechar com um commit atômico
- O `code-validator` é OBRIGATÓRIO antes de fechar qualquer task

## Ordem obrigatória de review de código

**NUNCA** execute `gsd-code-reviewer` sem antes executar o `code-validator`.

A sequência correta é SEMPRE:

1. `code-validator` — valida compilação, testes, lint e cobertura
2. `gsd-code-reviewer` — só pode rodar se o `code-validator` passou sem erros bloqueantes

Usar `gsd-code-reviewer` diretamente (pulando o `code-validator`) é proibido e invalida o review.

## Idioma

- **Código, comentários técnicos, commits**: inglês
- **Discussão, docs internas, planejamento**: português (pt-BR)
- **i18n no frontend**: nunca string hardcoded em português no JSX
