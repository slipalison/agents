---
name: volatility-decomposition
description: Juval Löwy's Method for service decomposition by volatility axes. Apply during architecture design, service boundary definition, or when reviewing if a refactor respects the architecture method.
---

# The Method — Volatility-Based Decomposition

Baseado em "Righting Software" de Juval Löwy.

## Princípio central

**NUNCA decompor por funcionalidade. SEMPRE por eixos de volatilidade.**

Funcionalidade é o QUE o sistema faz. Volatilidade é como o sistema MUDA.
Acoplar serviços a funcionalidades ossifica o sistema; acoplar a eixos de mudança o mantém vivo.

## Eixos típicos de volatilidade

1. **Volatilidade de cliente** — mobile vs web vs API externa vs CLI
2. **Volatilidade de fluxo de negócio** — regras que mudam (pricing, promoções, compliance)
3. **Volatilidade de fonte de dados** — provedor, formato, cache strategy
4. **Volatilidade tecnológica** — frameworks, libs, protocolos
5. **Volatilidade temporal** — hoje vs daqui a 6 meses vs daqui a 5 anos
6. **Volatilidade organizacional** — quem é dono / mantém / opera

## Antipadrões comuns

| Antipadrão | Sintoma | Por que falha |
|---|---|---|
| Microsserviço por agregado DDD | `OrderService`, `UserService`, `ProductService` | Funcional disfarçado de domain — cascata de mudanças entre serviços |
| Decomposição funcional | `EmailService`, `NotificationService` | Reúso miragem; serviço vira monólito de utility functions |
| CRUD-per-table | Service por entidade | Não isola volatilidade nenhuma; só multiplica overhead |
| "Vamos criar um microservice" | Decisão pré-arquitetura | Microservice é resultado, não input |

## Checklist antes de propor serviço novo

Faça essas perguntas. Se as respostas se misturam, o boundary está errado.

1. Qual **eixo de volatilidade** este serviço encapsula?
2. O que muda quando o **cliente** muda?
3. O que muda quando a **regra de negócio** muda?
4. O que muda quando o **fornecedor de dados** muda?
5. O que muda quando o **framework** muda?
6. Qual a **frequência esperada** de mudança em cada eixo?

Boa decomposição: cada serviço responde "eu mudo quando X muda" com UMA resposta.
Má decomposição: serviço muda quando QUALQUER UMA de várias coisas muda.

## Heurística rápida

- Se você precisar mudar 3+ serviços para implementar uma feature, **decomposição funcional vazou**.
- Se um serviço nunca muda, ele provavelmente é **library, não serviço**.
- Se dois serviços sempre mudam juntos, eles são **um serviço só** com fronteira artificial.

## Relação com taxonomia MER

A volatility decomposition define **quais serviços existem**.
A taxonomia Manager-Engine-ResourceAccess define **a estrutura interna de cada serviço**.
São camadas complementares, não alternativas.
