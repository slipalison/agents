---
name: code-design-ddd
description: Domain-Driven Design code design. LOCKED once selected. Covers bounded contexts, aggregates, entities, value objects, domain events, repositories.
---

# Code Design: Domain-Driven Design (DDD)

> **LOCKED.** Once selected, follow every rule. No mixing. No switching.

## Building blocks

| Block | Responsibility | Rules |
|---|---|---|
| **Entity** | Identity + lifecycle + behavior | Equals by ID, encapsulates invariants |
| **Value Object** | Describes, no identity | Immutable, equals by value, `record` preferred |
| **Aggregate** | Consistency boundary | One Root, external refs by ID only |
| **Domain Event** | Past-tense fact | Immutable, carries IDs + relevant data |
| **Repository** | Persistence abstraction | One per Aggregate Root, interface in Domain |
| **Domain Service** | Cross-entity logic | Stateless |
| **Application Service** | Orchestrates use cases | No business logic |

## Project structure

```
src/
├── MyApp.Domain/              # ZERO infra dependencies
│   ├── Orders/
│   │   ├── Order.cs           # Aggregate Root
│   │   ├── OrderLine.cs       # Entity (part of aggregate)
│   │   ├── Money.cs           # Value Object
│   │   ├── OrderPlacedEvent.cs
│   │   └── IOrderRepository.cs
│   └── SharedKernel/
│       ├── Entity.cs
│       ├── ValueObject.cs
│       └── AggregateRoot.cs
├── MyApp.Application/         # Use case orchestration
│   ├── Orders/
│   │   ├── PlaceOrderCommand.cs
│   │   ├── PlaceOrderHandler.cs
│   │   └── DTOs/OrderDto.cs
│   └── Common/IUnitOfWork.cs
├── MyApp.Infrastructure/      # Implements domain interfaces
│   └── Persistence/
│       ├── OrderRepository.cs
│       └── OrderConfiguration.cs
└── MyApp.Api/
    └── Controllers/
```

## Dependency direction (STRICT)

```
Api → Application → Domain ← Infrastructure
```

- **Domain** references NOTHING
- **Application** references only Domain
- **Infrastructure** implements Domain interfaces
- **Api** wires DI

## Aggregate rules

1. One Aggregate Root per aggregate — all access through root
2. Reference other aggregates by **ID only**
3. One aggregate per transaction
4. Keep aggregates small
5. Eventual consistency between aggregates via Domain Events

```csharp
public class Order : AggregateRoot
{
    public Guid CustomerId { get; private set; }  // ID ref, not object
    private readonly List<OrderLine> _lines = [];

    public void AddLine(ProductId productId, int qty, Money unitPrice)
    {
        if (qty <= 0) throw new DomainException("Quantity must be positive");
        _lines.Add(new OrderLine(productId, qty, unitPrice));
        AddDomainEvent(new OrderLineAddedEvent(Id, productId, qty));
    }
}
```

## Value Object rules

- Use `record` — immutable, equals by value
- Validate in constructor — invalid VOs must not exist
- No setters — new instances via methods

## Repository rules

- One per Aggregate Root, not per entity
- Interface in Domain, impl in Infrastructure
- No `IQueryable` leaking — return materialized results

## Prohibited

- Business logic in Application Services
- Anemic domain model (data bags with logic elsewhere)
- Direct DB access bypassing repository
- Domain referencing Infrastructure
- Sharing entities across bounded contexts
- Mutable Value Objects
- Multiple aggregates in one transaction
