---
name: code-design-clean-architecture
description: "Clean Architecture (Uncle Bob) code design. LOCKED once selected. Dependency Rule inward, Use Cases at center, Entities innermost. Frameworks at outermost ring."
---

# Code Design: Clean Architecture (Uncle Bob)

> **LOCKED.** Once selected, follow every rule. No mixing. No switching.
> Reference: "Clean Architecture" by Robert C. Martin

## Core principle

**The Dependency Rule**: source code dependencies can only point **inward**. Nothing in an inner ring can know about something in an outer ring.

```
┌─────────────────────────────────────┐
│  Frameworks & Drivers (outermost)   │
│  ┌─────────────────────────────┐    │
│  │  Interface Adapters          │    │
│  │  ┌─────────────────────┐    │    │
│  │  │  Use Cases           │    │    │
│  │  │  ┌─────────────┐    │    │    │
│  │  │  │  Entities    │    │    │    │
│  │  │  │  (innermost) │    │    │    │
│  │  │  └─────────────┘    │    │    │
│  │  └─────────────────────┘    │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

## Rings

### 1. Entities (innermost)

- Enterprise-wide business rules
- Plain objects with methods — no framework dependencies
- Can be used by any application in the enterprise

### 2. Use Cases

- Application-specific business rules
- Orchestrate data flow to/from Entities
- Define Input/Output ports (interfaces)
- One Use Case = one application action

### 3. Interface Adapters

- Convert data between Use Cases and external format
- Controllers, Presenters, Gateways
- Repository implementations
- DTO mapping

### 4. Frameworks & Drivers (outermost)

- ASP.NET Core, EF Core, Serilog, HTTP clients
- Minimal code — glue only
- All framework details stay here

## Project structure

```
src/
├── MyApp.Domain/                    # Ring 1: Entities
│   ├── Entities/
│   │   ├── Order.cs
│   │   └── Customer.cs
│   ├── ValueObjects/
│   │   └── Money.cs
│   └── Exceptions/
│       └── DomainException.cs
├── MyApp.Application/               # Ring 2: Use Cases
│   ├── UseCases/
│   │   ├── Orders/
│   │   │   ├── PlaceOrder/
│   │   │   │   ├── PlaceOrderCommand.cs    # Input port
│   │   │   │   ├── PlaceOrderHandler.cs    # Use case impl
│   │   │   │   └── PlaceOrderResponse.cs   # Output
│   │   │   └── GetOrder/
│   │   │       ├── GetOrderQuery.cs
│   │   │       └── GetOrderHandler.cs
│   │   └── Products/
│   ├── Ports/                       # Interfaces (output ports)
│   │   ├── IOrderRepository.cs
│   │   └── IPaymentGateway.cs
│   └── Common/
│       └── IUnitOfWork.cs
├── MyApp.Infrastructure/            # Ring 3-4: Adapters + Frameworks
│   ├── Persistence/
│   │   ├── AppDbContext.cs
│   │   ├── OrderRepository.cs      # Implements IOrderRepository
│   │   └── Configurations/
│   ├── ExternalServices/
│   │   └── StripePaymentGateway.cs  # Implements IPaymentGateway
│   └── DependencyInjection.cs
└── MyApp.Api/                       # Ring 4: Framework
    ├── Controllers/
    │   └── OrdersController.cs
    ├── Middleware/
    └── Program.cs
```

## Dependency Rule enforcement

```
Api → Infrastructure → Application → Domain
                       Application defines ports (interfaces)
                       Infrastructure implements them
```

- **Domain** references NOTHING
- **Application** references only Domain. Defines port interfaces.
- **Infrastructure** references Application (to implement ports) and Domain
- **Api** references all (for DI wiring only)

## Use Case rules

```csharp
// Input port (command/query)
public sealed record PlaceOrderCommand(
    Guid CustomerId,
    List<OrderLineDto> Lines) : IRequest<PlaceOrderResponse>;

// Use Case handler
internal sealed class PlaceOrderHandler(
    IOrderRepository orderRepo,    // Output port — interface
    IPaymentGateway payments,      // Output port — interface
    IUnitOfWork uow) : IRequestHandler<PlaceOrderCommand, PlaceOrderResponse>
{
    public async Task<PlaceOrderResponse> Handle(
        PlaceOrderCommand cmd, CancellationToken ct)
    {
        // Entity contains business rules
        var order = Order.Create(cmd.CustomerId);
        foreach (var line in cmd.Lines)
            order.AddLine(line.ProductId, line.Quantity, line.UnitPrice);

        await orderRepo.AddAsync(order, ct);
        await uow.CommitAsync(ct);

        return new PlaceOrderResponse(order.Id);
    }
}
```

- One Use Case per handler
- Use Case orchestrates Entities + calls ports
- No framework classes in Use Case layer
- Input/Output via DTOs, never raw Entities

## Testing strategy

- **Entities**: unit tests (pure logic)
- **Use Cases**: unit tests with mocked ports
- **Infrastructure**: integration tests with real dependencies
- **Api**: E2E tests with `WebApplicationFactory`

## Prohibited

- Inner ring referencing outer ring
- Framework classes in Domain or Application
- Business logic in Controllers or Infrastructure
- Use Case returning Entity directly (use DTOs)
- Infrastructure classes without port interface
- Calling DB directly from Use Case (use port)
- Circular dependencies between rings
