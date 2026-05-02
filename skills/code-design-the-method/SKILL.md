---
name: code-design-the-method
description: "The Method (Righting Software - Juval Löwy) code design. LOCKED once selected. Volatility-Based Decomposition, Manager-Engine-ResourceAccess taxonomy, strict service layering."
---

# Code Design: The Method (Juval Löwy)

> **LOCKED.** Once selected, follow every rule. No mixing. No switching.
> Reference: "Righting Software" by Juval Löwy

## Core principle

**Volatility-Based Decomposition** — decompose by axes of change, NOT by functionality. Each service encapsulates ONE axis of volatility. When that axis changes, only that service changes.

## Volatility axes (examples)

| Axis | What changes | Example |
|---|---|---|
| Business rules | Policies, pricing, validation rules | `PricingEngine` |
| Data source | DB vendor, schema, external API | `OrderAccess` |
| Client | UI channel, API consumer | `OrderController` |
| Technology | Framework, protocol, serialization | `MessageBusAccess` |
| Platform | OS, cloud provider | `StorageAccess` |

## Service taxonomy (Manager → Engine → ResourceAccess)

Three types of services. NEVER skip a layer. NEVER violate call direction.

### Manager

- **Orchestrates** Engines and other Managers
- Contains NO business logic
- Contains NO data access
- Handles workflow, sequencing, error coordination
- Can call: Engines, other Managers, ResourceAccess (for cross-cutting only)

### Engine

- **Encapsulates business logic** for one volatility axis
- Stateless — all state via parameters
- Pure computation — no I/O, no DB, no HTTP
- Can call: ResourceAccess (for data it needs)
- **NEVER calls another Engine** — if two Engines need to coordinate, a Manager does it

### ResourceAccess

- **Encapsulates data access** for one volatility axis
- Wraps DB, file system, HTTP clients, message bus, cache
- Returns domain objects, not raw data
- **NEVER calls another ResourceAccess**
- **NEVER calls an Engine**

## Call direction (STRICT)

```
Manager → Engine → ResourceAccess
Manager → ResourceAccess (cross-cutting only)
Manager → Manager (composition)
```

### FORBIDDEN calls

| From | To | Why |
|---|---|---|
| Engine | Engine | Coupling two volatility axes |
| ResourceAccess | ResourceAccess | Coupling two data sources |
| ResourceAccess | Engine | Inverted dependency |
| Engine | Manager | Inverted dependency |
| Any layer | Skip layer | Breaks encapsulation |

## Project structure

```
src/
├── MyApp.Managers/
│   ├── OrderManager.cs                # Orchestrates OrderEngine + PricingEngine
│   ├── IOrderManager.cs
│   └── ShippingManager.cs
├── MyApp.Engines/
│   ├── OrderEngine.cs                 # Business rules for orders
│   ├── IOrderEngine.cs
│   ├── PricingEngine.cs               # Pricing logic (pure computation)
│   └── IPricingEngine.cs
├── MyApp.ResourceAccess/
│   ├── OrderAccess.cs                 # DB operations for orders
│   ├── IOrderAccess.cs
│   ├── ProductAccess.cs
│   └── ExternalPaymentAccess.cs       # HTTP client for payment gateway
├── MyApp.Contracts/                   # Shared interfaces + DTOs
│   ├── IOrderManager.cs
│   ├── IOrderEngine.cs
│   ├── IOrderAccess.cs
│   └── DTOs/
│       ├── OrderDto.cs
│       └── PricingRequest.cs
└── MyApp.Api/
    ├── Controllers/OrderController.cs
    └── Program.cs
```

## Example

```csharp
// Manager — orchestration only, zero business logic
public class OrderManager(
    IOrderEngine orderEngine,
    IPricingEngine pricingEngine,
    IOrderAccess orderAccess,
    IInventoryAccess inventoryAccess) : IOrderManager
{
    public async Task<OrderResult> PlaceOrderAsync(
        PlaceOrderRequest request, CancellationToken ct)
    {
        // 1. Engine computes pricing (pure logic)
        var pricing = pricingEngine.CalculateTotal(request.Lines);

        // 2. Engine validates order rules (pure logic)
        orderEngine.ValidateOrder(request, pricing);

        // 3. ResourceAccess checks inventory (I/O)
        var available = await inventoryAccess
            .CheckAvailabilityAsync(request.Lines, ct);

        // 4. Engine evaluates availability (pure logic)
        orderEngine.EnsureAllAvailable(request.Lines, available);

        // 5. ResourceAccess persists (I/O)
        var order = orderEngine.CreateOrder(request, pricing);
        await orderAccess.SaveAsync(order, ct);

        return new OrderResult(order.Id, pricing.Total);
    }
}

// Engine — pure business logic, NO I/O
public class PricingEngine : IPricingEngine
{
    public PricingResult CalculateTotal(IReadOnlyList<OrderLine> lines)
    {
        // Pure computation — no DB, no HTTP, no side effects
        var subtotal = lines.Sum(l => l.Quantity * l.UnitPrice);
        var discount = subtotal > 1000 ? subtotal * 0.1m : 0;
        return new PricingResult(subtotal, discount, subtotal - discount);
    }
}

// ResourceAccess — data I/O only, zero logic
public class OrderAccess(AppDbContext db) : IOrderAccess
{
    public async Task SaveAsync(Order order, CancellationToken ct)
    {
        db.Orders.Add(order);
        await db.SaveChangesAsync(ct);
    }
}
```

## Testing strategy

- **Engines**: unit tests — pure input/output, no mocks needed
- **Managers**: unit tests with mocked Engines + ResourceAccess
- **ResourceAccess**: integration tests with real DB (Testcontainers)

## Prohibited

- Business logic in Managers (move to Engine)
- I/O in Engines (move to ResourceAccess)
- Engine calling Engine
- ResourceAccess calling ResourceAccess
- ResourceAccess calling Engine
- Skipping layers (Manager direct to DB)
- "Utility" or "Helper" classes (decompose properly)
- God Manager that does everything
