---
name: service-taxonomy-mer
description: Manager-Engine-ResourceAccess service taxonomy from Juval Löwy's Method. Apply when designing service interactions, reviewing call graphs, or detecting layer violations in .NET microservices.
---

# Service Taxonomy — Manager / Engine / ResourceAccess

A taxonomia define a **estrutura interna** de cada serviço. Combinada com Volatility-Based Decomposition (que define quais serviços existem), forma a base do "The Method".

## Camadas (de cima pra baixo)

### Manager

- **Orquestra casos de uso** (use cases / aplicação)
- Sequencia chamadas a Engines e ResourceAccess
- **NUNCA contém regra de negócio** propriamente dita
- Pode conter regras de orquestração (ordem, condicional cross-engine)
- Exemplo: `OrderManager.PlaceOrderAsync`

```csharp
public class OrderManager
{
    private readonly IPricingEngine _pricing;
    private readonly IFraudEngine _fraud;
    private readonly IOrderResourceAccess _orders;

    public async Task<OrderResult> PlaceOrderAsync(OrderRequest req, CancellationToken ct)
    {
        var price = await _pricing.CalculateAsync(req, ct);
        var fraudCheck = await _fraud.EvaluateAsync(req, ct);
        if (!fraudCheck.IsApproved) return OrderResult.Rejected(fraudCheck.Reason);

        return await _orders.CreateAsync(req.WithPrice(price), ct);
    }
}
```

### Engine

- Encapsula **uma atividade** (regra de negócio / algoritmo)
- Stateless ou state encapsulado
- **NUNCA chama outro Engine** (acoplamento horizontal proibido)
- **Idealmente não chama ResourceAccess** (Manager faz a injeção de dados)
- Pode chamar ResourceAccess se a atividade for naturalmente data-bound (tolerável)
- Exemplo: `PricingEngine`, `FraudDetectionEngine`, `TaxEngine`

```csharp
public class PricingEngine : IPricingEngine
{
    public Task<Money> CalculateAsync(OrderRequest req, CancellationToken ct)
    {
        // pura regra de pricing — sem DB, sem HTTP
        var subtotal = req.Items.Sum(i => i.UnitPrice * i.Quantity);
        var discount = ApplyTierDiscount(subtotal, req.CustomerTier);
        return Task.FromResult(subtotal - discount);
    }
}
```

### ResourceAccess

- Encapsula **um recurso** (DB, cache, fila, API externa)
- **Expõe API de domínio**, não CRUD genérico
- **NUNCA chama outros ResourceAccess** (proibido)
- **NUNCA chama Engine** (inversão proibida)
- Exemplo: `OrderResourceAccess` (não `OrderRepository`)

```csharp
public class OrderResourceAccess : IOrderResourceAccess
{
    private readonly OrderDbContext _db;

    public async Task<OrderResult> CreateAsync(OrderRequest req, CancellationToken ct)
    {
        var entity = OrderEntity.From(req);
        _db.Orders.Add(entity);
        await _db.SaveChangesAsync(ct);
        return OrderResult.Created(entity.Id);
    }

    // ✗ NÃO exponha .GetAll(), .Update(entity), .Delete(id) genéricos
    // ✓ Exponha métodos específicos do domínio
}
```

## Regras de chamada

| De | Para | Permitido? |
|---|---|---|
| Manager | Engine | ✓ |
| Manager | ResourceAccess | ✓ |
| Manager | Manager (outro serviço, via contrato) | ✓ (via queue/HTTP, não direto) |
| Engine | ResourceAccess | ⚠ tolerável se atividade é data-bound |
| Engine | Engine | ✗ proibido |
| Engine | Manager | ✗ inversão proibida |
| ResourceAccess | ResourceAccess | ✗ proibido |
| ResourceAccess | Engine | ✗ inversão proibida |
| ResourceAccess | Manager | ✗ inversão proibida |

**Pular camadas** (Manager → SQL direto, ou controller → ResourceAccess) é proibido.

## Code smell detector

Sinais de violação de taxonomia:

- Nome termina em `Service` → ambíguo, classifique como Manager / Engine / ResourceAccess
- Engine com `DbContext` injetado → provavelmente violação (mover dado pro Manager)
- Manager com `if/else` de regra de negócio → mover regra pra Engine
- Repository genérico `Repository<T>` → vaza abstração, faça ResourceAccess específico
- Engine que chama `HttpClient` → encapsule em ResourceAccess
- ResourceAccess com `.GetAll()` exposto → API genérica, transforme em método de domínio

## Diagrama mental

```
┌─────────────────────────────────────────┐
│            Controller / API             │  ← entry
└─────────────────┬───────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│              Manager                    │  ← orquestra
│         (sem regra de negócio)          │
└──────┬──────────────────────┬───────────┘
       ↓                      ↓
┌──────────────┐      ┌──────────────────┐
│   Engine     │      │  ResourceAccess  │
│  (regras)    │      │   (recursos)     │
└──────────────┘      └──────────────────┘
       │                      │
   stateless              DB / HTTP / Queue
```

## Checklist de review

- [ ] Toda classe nova tem sufixo Manager / Engine / ResourceAccess?
- [ ] Manager está livre de regra de negócio?
- [ ] Engine está livre de chamadas a outros Engines?
- [ ] ResourceAccess expõe domínio, não CRUD?
- [ ] Não há skip de camadas?
- [ ] Não há inversão (Engine → Manager, RA → Engine)?
