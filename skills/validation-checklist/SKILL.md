---
name: validation-checklist
description: Comprehensive checklist used by code-validator agent. Reference for PASS/FAIL/CONDITIONAL verdicts and the fix proposal format. Every blocking issue MUST include a clear, actionable fix with code.
---

# Validation Checklist (Quality Gate)

Este checklist é a referência canônica do `code-validator`. Toda task passa por aqui antes do commit.

## Verdict definitions

| Verdict | Condição |
|---|---|
| **FAIL** | Build falha, testes falham, cobertura < 80%, blocking issue, segurança comprometida, decisão D-XX faltando |
| **CONDITIONAL** | Apenas warnings, ambiguidade que requer decisão humana |
| **PASS** | Zero blockers, coverage ≥ 80%, build verde, design OK, decisões implementadas |

## Ordem de execução

1. **Build** — se falha, FAIL imediato (não continue)
2. **Testes** — se falham, FAIL imediato (não continue)
3. **Cobertura** — se < 80%, FAIL (listar arquivos sem cobertura)
4. **Segurança** — SQL injection, secrets, PII em logs, auth
5. **Performance** — CancellationToken, estruturas de dados, complexidade
6. **Code Design** — conforme design locked do projeto
7. **Decisões GSD** — rastreabilidade D-XX
8. **Boas Práticas** — naming, DI, error handling
9. **Frontend** — se aplicável

## Blocking items (FAIL se ✗)

### Build & Testes (fail-fast)

- [ ] `dotnet build` sem warnings (`TreatWarningsAsErrors=true`)
- [ ] `dotnet test` todos verdes
- [ ] `npm test` todos verdes (se frontend)
- [ ] `npm run lint` zero erros (se frontend)
- [ ] `npm run typecheck` zero erros (se frontend)

### Cobertura (INVIOLÁVEL)

- [ ] Cobertura ≥ 80% — número EXATO reportado
- [ ] Cada arquivo novo/modificado tem teste correspondente
- [ ] Se < 80%: listar arquivos com menor cobertura e cenários faltando

### Segurança (CRÍTICO)

- [ ] Inputs validados em toda boundary (API, message bus, file I/O)
- [ ] SQL parametrizado — zero string concatenation
- [ ] Secrets fora do código e config versionado
- [ ] Logs não expõem PII, tokens, senhas, connection strings
- [ ] Auth/authz em endpoints novos
- [ ] CORS restrito (não `AllowAny` em produção)

### Performance

- [ ] `CancellationToken` propagado em todo método I/O
- [ ] Estruturas de dados corretas para complexidade esperada
- [ ] `AsNoTracking` em queries de leitura EF Core
- [ ] Sem N+1 queries (nested loops com DB access)

### Code Design (conforme LOCKED)

- [ ] Carregar skill `code-design-*` ativa do projeto
- [ ] Dependências entre camadas respeitam design selecionado
- [ ] Zero violações de direção de dependência
- [ ] Responsabilidades corretas em cada camada/componente

### Decisões (GSD)

- [ ] Toda D-XX do plano tem código correspondente
- [ ] Zero "Deferred Ideas" implementados
- [ ] Nenhum arquivo fora do escopo da task foi modificado

### Qualidade C#

- [ ] Naming conventions OK
- [ ] Zero `async void` (exceto event handlers)
- [ ] DI por construtor apenas
- [ ] Zero `Console.WriteLine` (Serilog)
- [ ] Zero magic strings/numbers
- [ ] Refatoração justificada (segurança, performance, bug — não estética)

### Qualidade Frontend (se aplicável)

- [ ] Zero `any` explícito ou implícito
- [ ] Componentes < 150 linhas
- [ ] Estados Loading / Error / Empty / Success
- [ ] Strings via `t()` (zero hardcoded)
- [ ] Sem `fetch` direto em componente (usar hook dedicado / API layer)
- [ ] A11y: semantic HTML, labels, foco visível, contraste WCAG AA

## Warning items (CONDITIONAL se múltiplos ⚠)

- Componente entre 100-150 linhas
- Cobertura entre 80-85%
- TODO/FIXME novos
- Complexidade ciclomática > 10
- Arquivo > 400 linhas
- Função > 50 linhas
- Mais de 3 parâmetros sem agrupamento

## Regras de correção (OBRIGATÓRIO para o validator)

Todo blocking issue DEVE ter correção clara com estas partes:

1. **`current_code`** — o código problemático exato (copiar do diff)
2. **`issue`** — o problema em uma frase (sem enrolação)
3. **`fix`** — o código corrigido, pronto para copiar e colar

### Formato de fix por categoria

| Categoria | Fix deve conter |
|---|---|
| **security** | Código corrigido com parametrização, validação, ou sanitização |
| **performance** | Código com estrutura de dados correta ou padrão async correto |
| **code-design** | Código refatorado respeitando o design locked |
| **testing** | Nome do arquivo de teste + cenários mínimos com `[Fact]` signatures |
| **coverage** | Lista de arquivos abaixo de 80% + cenários sugeridos para cada |

### Exemplos

```yaml
# Segurança — SQL injection
- file: Data/UserAccess.cs
  line: 23
  category: security
  rule: "SQL injection risk"
  current_code: |
    var sql = $"SELECT * FROM Users WHERE Email = '{email}'";
  fix: |
    ```csharp
    var user = await db.Users
        .FirstOrDefaultAsync(u => u.Email == email, ct);
    ```

# Cobertura — arquivo sem teste
- file: Services/OrderService.cs
  line: 1
  category: testing
  rule: "Missing tests"
  issue: "New file has no test file"
  fix: |
    Create `Tests/Services/OrderServiceTests.cs`:
    ```csharp
    [Fact]
    public async Task PlaceOrder_ValidInput_PersistsAndReturnsId()
    [Fact]
    public async Task PlaceOrder_EmptyLines_ThrowsDomainException()
    [Fact]
    public async Task PlaceOrder_CancellationRequested_ThrowsOperationCanceled()
    ```
```

## Princípios

1. **Cite arquivo + linha** em todo issue
2. **Proponha fix com código** — nunca apenas descreva o problema
3. **Rode builds/testes de verdade** — nunca assuma
4. **Cobertura é número exato** — "84.2%" não "adequada"
5. **Não sugira refactor fora do escopo** — gold-plating não é o trabalho
6. **Não bloqueie por estética** — só por riscos reais
7. **Priorize por severidade**: security > performance > design > testing > practices
