---
name: code-design-vertical-slice
description: Vertical Slice Architecture code design. LOCKED once selected. Each feature is a self-contained slice with handler, model, and persistence. No shared layers.
---

# Code Design: Vertical Slice Architecture

> **LOCKED.** Once selected, follow every rule. No mixing. No switching.

## Core principle

Organize by **feature**, not by layer. Each slice owns everything it needs — from request to response.

## What is a slice

A slice = one user action, end-to-end. Contains:
- Request/Command/Query model
- Handler (all logic for that action)
- Validation
- Persistence access (inline, no repository abstraction)
- Response model

## Project structure

```
src/
├── MyApp/
│   ├── Features/
│   │   ├── Orders/
│   │   │   ├── PlaceOrder.cs          # Request + Handler + Response in one file
│   │   │   ├── GetOrderById.cs
│   │   │   ├── CancelOrder.cs
│   │   │   └── ListOrders.cs
│   │   ├── Products/
│   │   │   ├── CreateProduct.cs
│   │   │   └── SearchProducts.cs
│   │   └── _Shared/                   # Cross-cutting for this domain area only
│   │       └── OrderNotFoundException.cs
│   ├── Common/                        # Truly shared infra (DbContext, middleware)
│   │   ├── AppDbContext.cs
│   │   ├── Behaviors/                 # MediatR pipeline behaviors
│   │   │   ├── ValidationBehavior.cs
│   │   │   └── LoggingBehavior.cs
│   │   └── BaseHandler.cs            # Optional minimal base
│   └── Program.cs
```

## Slice anatomy

```csharp
// One file per feature — PlaceOrder.cs
public static class PlaceOrder
{
    public sealed record Command(string CustomerId, List<LineItem> Lines) : IRequest<Result>;
    public sealed record LineItem(string ProductId, int Quantity, decimal UnitPrice);
    public sealed record Result(Guid OrderId, DateTime PlacedAt);

    public sealed class Validator : AbstractValidator<Command>
    {
        public Validator()
        {
            RuleFor(x => x.CustomerId).NotEmpty();
            RuleFor(x => x.Lines).NotEmpty();
            RuleForEach(x => x.Lines).ChildRules(line =>
            {
                line.RuleFor(l => l.Quantity).GreaterThan(0);
            });
        }
    }

    internal sealed class Handler(AppDbContext db) : IRequestHandler<Command, Result>
    {
        public async Task<Result> Handle(Command req, CancellationToken ct)
        {
            var order = new Order(req.CustomerId);
            foreach (var line in req.Lines)
                order.AddLine(line.ProductId, line.Quantity, line.UnitPrice);

            db.Orders.Add(order);
            await db.SaveChangesAsync(ct);

            return new Result(order.Id, order.PlacedAt);
        }
    }
}
```

## Rules

### Feature isolation

- Each slice is **self-contained** — no cross-slice dependencies
- Slices don't call other slices — if coordination needed, use domain events or a saga
- Shared code goes in `Common/` — but keep it minimal
- No generic repositories — each handler accesses `DbContext` directly
- Duplicated code between slices is FINE — coupling is worse than duplication

### MediatR pipeline

- Use `IRequest<T>` / `IRequestHandler<T, R>` for all slices
- Cross-cutting via pipeline behaviors: validation, logging, transaction
- One handler per request — no handler reuse

### Endpoints

- Each slice maps to one endpoint
- Use Minimal APIs or thin controllers that only dispatch to MediatR
- No logic in endpoints — just `mediator.Send(command)`

```csharp
app.MapPost("/api/orders", async (PlaceOrder.Command cmd, IMediator mediator, CancellationToken ct) =>
{
    var result = await mediator.Send(cmd, ct);
    return Results.Created($"/api/orders/{result.OrderId}", result);
});
```

### When to share

Only share:
- `DbContext` and EF configurations
- Pipeline behaviors (validation, logging, transactions)
- Base exceptions
- Extension methods for common patterns

Never share:
- Handlers
- Request/response models between features
- "Service" classes used by multiple slices

## Testing

- Test each slice in isolation
- Integration tests preferred over unit tests (test real DB via Testcontainers)
- One test class per slice: `PlaceOrderTests.cs`

## Prohibited

- Layered architecture (no Services/Repositories/Controllers separation)
- Generic `Repository<T>` pattern
- Slice calling another slice's handler directly
- Shared DTOs between features
- "Service" classes used across multiple slices
- Handlers with multiple responsibilities
