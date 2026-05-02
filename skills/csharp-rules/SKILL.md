---
name: csharp-rules
description: C# engineering standards with strict priority chain — Security → Performance → Best Practices. Auto-apply when editing .cs files. Expert-level rules — no basics, only what matters.
---

# C# Engineering Standards

> **Priority chain: Security → Performance → Best Practices.** Every decision follows this order.

## 1. Security (top priority)

### Input & boundaries

- Validate ALL external input (API params, headers, query strings, message payloads, file uploads)
- Use FluentValidation or Data Annotations — never manual `if` chains for validation
- Sanitize before logging — strip PII, tokens, secrets, credit cards
- Parameterized queries ALWAYS — zero string concatenation in SQL/EF raw queries

### Authentication & authorization

- Authorize at controller/endpoint level (attribute-based) + business rule level (service layer)
- Least privilege: scoped permissions, never blanket `[AllowAnonymous]` on controllers
- Token validation: check `iss`, `aud`, `exp`, `nbf` — don't just check signature

### Secrets management

- NEVER in code, appsettings.json, or version control
- Use: User Secrets (dev), Azure Key Vault / AWS Secrets Manager (prod), env vars (containers)
- Rotate secrets — design for rotation from day one

### HTTP security

- CORS: explicit origins, never `AllowAnyOrigin` in production
- HTTPS only — `UseHsts()` + `UseHttpsRedirection()`
- Rate limiting on public endpoints (`System.Threading.RateLimiting`)
- Anti-forgery tokens for form submissions
- Security headers: `X-Content-Type-Options`, `X-Frame-Options`, `Strict-Transport-Security`

## 2. Performance (second priority)

### Memory & allocations

- `Span<T>` / `ReadOnlySpan<T>` for parsing, slicing, string manipulation
- `Memory<T>` / `ReadOnlyMemory<T>` when async context needed
- `ArrayPool<T>.Shared` / `MemoryPool<T>` for temporary buffers
- `stackalloc` for small fixed-size buffers (< 512 bytes)
- String: use `string.Create()`, `StringBuilder` for building, `SearchValues<T>` for scanning
- Avoid closures in hot paths — they allocate

### Algorithms & data structures

- **Think Big O first**, then implement
- Document complexity in XML doc comment when non-obvious: `/// <remarks>O(log n) lookup</remarks>`

| Need | Use | Not |
|---|---|---|
| Uniqueness check | `HashSet<T>` | `List<T>.Contains()` |
| Key-value lookup | `Dictionary<K,V>` | `List<T>.Find()` |
| Immutable hot-path lookup | `FrozenSet<T>` / `FrozenDictionary<K,V>` | `ImmutableDictionary` |
| Sorted data + range queries | `SortedSet<T>` | Sort after insert |
| FIFO producer/consumer | `Channel<T>` | `ConcurrentQueue` + polling |
| Priority scheduling | `PriorityQueue<T,P>` | Sorted list |
| Large data streaming | `IAsyncEnumerable<T>` | `List<T>` (materialize all) |

### Async & I/O

- `CancellationToken` on EVERY I/O method — propagate, never ignore, never swallow
- `ConfigureAwait(false)` in libraries only (not in ASP.NET Core controllers)
- `ValueTask<T>` in hot paths proven by benchmark — not by default
- Never `.Result` / `.Wait()` / `.GetAwaiter().GetResult()` — deadlock risk
- `IAsyncEnumerable<T>` for streaming large datasets
- Prefer `HttpClientFactory` — never `new HttpClient()`

### EF Core

- `AsNoTracking()` on ALL read queries
- `AsSplitQuery()` for multi-collection includes
- No cascade `Include` deeper than 2 levels
- `IQueryable` stays in data layer — materialize before returning to business
- Compiled queries for hot paths: `EF.CompileAsyncQuery<TContext, TResult>(...)`
- Bulk operations via `ExecuteUpdateAsync` / `ExecuteDeleteAsync` (EF Core 7+)

## 3. Best Practices (third priority)

### Principles (in order)

1. **DRY** — but duplication > wrong abstraction. Extract only after 3rd occurrence
2. **KISS** — simplest solution that satisfies security + performance
3. **YAGNI** — don't build what wasn't asked
4. **SOLID** — especially ISP (small interfaces) and DIP (depend on abstractions)
5. **Clean Code** — readable = maintainable

### The golden rule

> **Never refactor for aesthetics.** Every change must be justified by security fix, performance gain, or actual bug. "Looks cleaner" is not a reason.

### Error handling

- Custom exceptions inherit from domain base exception
- Result pattern for expected failures — exceptions for unexpected
- Don't mix both in the same layer — pick one per bounded context
- Structured logging: `Log.Error(ex, "Failed to {Action} for {EntityId}", action, id)`
- Never empty catch — always log or propagate

### Dependency Injection

- Constructor injection only — no property injection, no service locator
- Lifetimes: Scoped (default), Singleton (thread-safe + stateless), Transient (lightweight)
- Register via extension methods: `services.AddOrderServices()`
- Never capture `IServiceProvider` in fields

### Testing (MANDATORY — zero negotiation)

- **xUnit** + **FluentAssertions** + **NSubstitute**
- **Todo arquivo novo/modificado DEVE ter teste correspondente** — sem exceção
- **Cobertura mínima 80% SEMPRE** — gate inviolável no CI e no workflow
  - Rodar: `dotnet test --collect:"XPlat Code Coverage"`
  - Se < 80%: task NÃO é entregue. Escreva mais testes.
  - Reportar número exato de cobertura
- Naming: `Method_Scenario_ExpectedResult`
- AAA structure (Arrange / Act / Assert)
- One logical assert per test
- Mock only at boundaries (DB, HTTP, message bus)
- Integration tests com Testcontainers para data access

> **Código sem teste = código que não existe. Cobertura < 80% = task não entregue.**

## 4. Observability (W3C standards)

### Traces (W3C Trace Context)

```csharp
// One ActivitySource per bounded context
static readonly ActivitySource Activity = new("MyApp.Orders");

// Create spans with semantic attributes
using var activity = Activity.StartActivity("PlaceOrder");
activity?.SetTag("order.id", orderId);
activity?.SetTag("order.total", total);
```

- Propagate `traceparent` / `tracestate` headers (automatic with OpenTelemetry SDK)
- Use OpenTelemetry Semantic Conventions for attribute naming
- Set `ActivityStatusCode.Error` on failures

### Metrics (OpenTelemetry)

```csharp
// Use IMeterFactory from DI
var meter = meterFactory.Create("MyApp.Orders");
var orderCounter = meter.CreateCounter<long>("orders.placed");
var latencyHistogram = meter.CreateHistogram<double>("orders.processing_duration_ms");
```

- Naming: `<namespace>.<metric>` (lowercase, dot-separated)
- Counters for throughput, Histograms for latency, Gauges for current state

### Logs (Serilog)

- **Zero string interpolation** in message templates
- Correlation automatic via `Activity.Current.TraceId` (with `Serilog.Enrichers.Span`)
- Enrichers: `WithMachineName`, `WithEnvironmentName`, `WithSpan`
- Levels: `Verbose` < `Debug` < `Information` < `Warning` < `Error` < `Fatal`
- **Never log**: passwords, tokens, PII, credit card numbers, connection strings

## Anti-patterns (instant FAIL in code review)

| Pattern | Why bad | Fix |
|---|---|---|
| `async void` (non-event) | Lost exceptions | `async Task` |
| `.Result` / `.Wait()` | Deadlock | `await` |
| `catch (Exception) { }` | Silent failure | Log + rethrow or Result |
| `Console.WriteLine` | Not structured | Serilog |
| `string` concat in SQL | SQL injection | Parameterized query |
| Log PII / secrets | Compliance violation | Sanitize before log |
| `new HttpClient()` | Socket exhaustion | `IHttpClientFactory` |
| `List.Contains()` in loop | O(n²) | `HashSet<T>` |
| Magic strings/numbers | Unmaintainable | `const` or config |
| Refactor "for beauty" | Wasted effort | Only if security/perf/bug |
| Ignore `CancellationToken` | Unresponsive system | Always propagate |
| `IServiceProvider` in field | Service locator | Constructor injection |
| Generic `Repository<T>` | Leaky abstraction | Specific data access |
