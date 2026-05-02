---
name: code-design-hexagonal
description: "Hexagonal Architecture (Ports & Adapters - Alistair Cockburn) code design. LOCKED once selected. Application core isolated from external world via ports and adapters."
---

# Code Design: Hexagonal Architecture (Ports & Adapters)

> **LOCKED.** Once selected, follow every rule. No mixing. No switching.
> Reference: Alistair Cockburn — "Hexagonal Architecture"

## Core principle

The application core (domain + use cases) lives in the center, completely isolated. All communication with the outside world happens through **Ports** (interfaces defined by the core) and **Adapters** (implementations in the outside).

```
                  ┌──────────────────┐
   Driving        │                  │        Driven
   Adapters ─────►│   APPLICATION    │◄────── Adapters
   (input)        │      CORE        │        (output)
                  │                  │
   REST API       │  Domain Model    │        PostgreSQL
   gRPC           │  Use Cases       │        Redis
   CLI            │  Ports           │        HTTP Client
   Message Bus    │                  │        File System
                  └──────────────────┘
```

## Two types of ports

### Driving (Primary) Ports

- **Defined by** the application core
- **Implemented by** the core itself
- **Called by** driving adapters (controllers, CLI, message consumers)
- Example: `IOrderService`, `IPlaceOrderUseCase`

### Driven (Secondary) Ports

- **Defined by** the application core
- **Implemented by** driven adapters (DB, HTTP clients, caches)
- **Called by** the core when it needs external resources
- Example: `IOrderRepository`, `IPaymentGateway`, `IEmailSender`

## Project structure

```
src/
├── MyApp.Core/                          # Application Hexagon
│   ├── Domain/                          # Domain model
│   │   ├── Order.cs
│   │   ├── Money.cs                     # Value Object
│   │   └── DomainException.cs
│   ├── Ports/
│   │   ├── Driving/                     # Primary ports (input)
│   │   │   ├── IOrderService.cs
│   │   │   └── IProductService.cs
│   │   └── Driven/                      # Secondary ports (output)
│   │       ├── IOrderRepository.cs
│   │       ├── IPaymentGateway.cs
│   │       └── IEventPublisher.cs
│   └── UseCases/                        # Port implementations (driving)
│       ├── OrderService.cs              # Implements IOrderService
│       └── ProductService.cs
├── MyApp.Adapters.Api/                  # Driving adapter: REST
│   ├── Controllers/OrdersController.cs
│   └── DTOs/
├── MyApp.Adapters.Persistence/          # Driven adapter: Database
│   ├── OrderRepository.cs              # Implements IOrderRepository
│   ├── AppDbContext.cs
│   └── Configurations/
├── MyApp.Adapters.ExternalServices/     # Driven adapter: HTTP clients
│   └── StripePaymentGateway.cs         # Implements IPaymentGateway
└── MyApp.Bootstrap/                     # Composition Root
    └── Program.cs                       # Wires all adapters to ports
```

## Dependency direction

```
Driving Adapters → Core ← Driven Adapters
                   Core defines ALL port interfaces
                   Adapters implement or consume them
```

- **Core** references NOTHING external — no framework, no infra
- **Driving Adapters** reference Core (call driving ports)
- **Driven Adapters** reference Core (implement driven ports)
- **Bootstrap** references everything (composition root)

## Port examples

```csharp
// Driving port — defined + implemented by Core
public interface IOrderService
{
    Task<OrderResult> PlaceOrderAsync(PlaceOrderRequest request, CancellationToken ct);
    Task<OrderDto?> GetOrderAsync(Guid orderId, CancellationToken ct);
}

// Driven port — defined by Core, implemented by Adapter
public interface IOrderRepository
{
    Task<Order?> FindByIdAsync(Guid id, CancellationToken ct);
    Task AddAsync(Order order, CancellationToken ct);
}

// Driven port — defined by Core, implemented by Adapter
public interface IPaymentGateway
{
    Task<PaymentResult> ChargeAsync(Money amount, PaymentMethod method, CancellationToken ct);
}
```

## Core use case

```csharp
// Core implements driving port, uses driven ports
public class OrderService(
    IOrderRepository orderRepo,
    IPaymentGateway payments,
    IEventPublisher events) : IOrderService
{
    public async Task<OrderResult> PlaceOrderAsync(
        PlaceOrderRequest request, CancellationToken ct)
    {
        var order = Order.Create(request.CustomerId);
        foreach (var line in request.Lines)
            order.AddLine(line.ProductId, line.Quantity, line.UnitPrice);

        var payment = await payments.ChargeAsync(order.Total, request.Payment, ct);
        order.ConfirmPayment(payment.TransactionId);

        await orderRepo.AddAsync(order, ct);
        await events.PublishAsync(new OrderPlacedEvent(order.Id), ct);

        return new OrderResult(order.Id, payment.TransactionId);
    }
}
```

## Adapter examples

```csharp
// Driving adapter — REST controller calls driving port
[ApiController]
[Route("api/[controller]")]
public class OrdersController(IOrderService orderService) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> PlaceOrder(
        PlaceOrderApiRequest request, CancellationToken ct)
    {
        // Map API model → Core model
        var coreRequest = request.ToPlaceOrderRequest();
        var result = await orderService.PlaceOrderAsync(coreRequest, ct);
        return CreatedAtAction(nameof(GetOrder), new { id = result.OrderId }, result);
    }
}

// Driven adapter — implements driven port
public class OrderRepository(AppDbContext db) : IOrderRepository
{
    public async Task<Order?> FindByIdAsync(Guid id, CancellationToken ct)
        => await db.Orders.FirstOrDefaultAsync(o => o.Id == id, ct);

    public async Task AddAsync(Order order, CancellationToken ct)
    {
        await db.Orders.AddAsync(order, ct);
        await db.SaveChangesAsync(ct);
    }
}
```

## Testing strategy

- **Core (use cases)**: unit tests — mock driven ports, call driving ports
- **Driven adapters**: integration tests with real infra (Testcontainers)
- **Driving adapters**: thin, minimal tests (mapping + delegation)
- **Full hex**: E2E with `WebApplicationFactory`

Key advantage: swap adapters in tests (in-memory DB, fake payment gateway).

## Prohibited

- Core referencing any adapter or framework
- Business logic in adapters
- Driven adapter calling driving port
- Adapter-to-adapter direct communication (go through Core)
- Framework types leaking into Core (no `DbContext` in Core, no `HttpContext`)
- Skipping ports (controller calling DB directly)
- Mixed responsibilities in adapters (one adapter = one external system)
