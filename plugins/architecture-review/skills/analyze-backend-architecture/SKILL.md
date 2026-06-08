---
name: analyze-backend-architecture
argument-hint: <path-to-repository>
disable-model-invocation: true
user-invocable: true
description: Analyze backend architecture for layering quality, data flow clarity, separation of concerns, and Single Level of Abstraction violations across routes, services, and data access.
---

# Analyze Backend Architecture

You are performing an architecture review of a backend project (REST API, GraphQL, gRPC, or background-worker service). Your goal is to produce a clear, actionable report that helps the developer improve their layering, separation of concerns, data flow, and code organization.

This skill is framework- and language-agnostic. It applies to Express/NestJS/Fastify (Node), FastAPI/Django/Flask (Python), Spring Boot (Java/Kotlin), Go (net/http, Gin, Echo), Rails, Laravel, and similar. Translate the terminology to the project's stack: "controller" ≈ route handler ≈ resolver; "service" ≈ use case ≈ interactor; "repository" ≈ DAO ≈ data mapper.

## Philosophy

This review is grounded in five principles that reinforce each other:

1. **Single Level of Abstraction (SLA)**: Every unit — route handlers, services, and repositories alike — should operate at one consistent abstraction level. A route handler orchestrates high-level service calls; a service composes domain operations; a repository composes data-access primitives. None of them should mix levels. A `createOrder` controller shouldn't mix `orderService.create(...)` with a raw SQL string and a Stripe SDK call inline. Equally, an `OrderService` shouldn't mix `paymentGateway.charge(...)` with hand-rolled `JSON.parse` of an HTTP response and bcrypt hashing. SLA is recursive: if you clean up the controller but leave the service full of mixed-level plumbing, the architecture hasn't actually improved. When you see a unit mixing abstraction levels at any depth, that's the most important signal something needs restructuring.

2. **Proper Layering**: The architecture should follow clear, one-directional layers: **Routes/Controllers** (parse the request, call a service, shape the response) → **Services/Use Cases** (own business logic and orchestration) → **Repositories/Data Access** (own all communication with the database, cache, queue, or external API). Each layer depends only on the layer below it. The most common and most damaging violation is **business logic in the controller** — validation rules, calculations, multi-step orchestration, or transaction handling living inside a route handler instead of a service. The second most common is **data access in the service** — a service calling the ORM, raw SQL, `fetch`, or an SDK directly instead of going through a repository.

3. **Clear Data Flow with Boundary Abstraction**: Data should flow predictably through explicit boundaries. The HTTP/transport layer should be the only place that knows about `req`/`res`, headers, status codes, and route params — these must never leak downward into services or repositories. There should be an **adapter in front of every external dependency** (database, third-party API, message broker, cache, filesystem). Services should never call Stripe, S3, Firebase, `fetch`, or raw SQL directly; instead a **repository or gateway adapter** owns that communication. The adapter must make dependencies explicit (connection pool, base URL, auth token, HTTP client, timeout) and must be replaceable in tests. In OO stacks this is often a class with constructor injection; in Go it may be a struct satisfying an interface; in Rails, Django, or functional Python it may be a module object or callable object with injected collaborators. The invariant is explicit dependency ownership, not a mandatory class shape. This layering means the underlying store can be swapped (Postgres → DynamoDB, Stripe → Braintree) without touching any service or controller.

4. **Minimal Duplication**: Similar logic repeated across handlers or services signals a missing abstraction. But extract only when the duplication is structural (same orchestration shape, same query pattern, same validation rule), not merely superficial. When multiple services duplicate the same external call, the fix is NOT to merge them into one mega-service — it's to extract the shared logic into a repository or gateway that both services consume. Cross-cutting concerns (auth, logging, validation, error handling, rate limiting) that are copy-pasted into many handlers should move into middleware, decorators, or interceptors.

5. **Explicit Dependencies & Testability**: Dependencies should be injected, not reached for via globals, singletons, or module-level side effects. A service that imports a concrete database connection at module scope is hard to test and tightly coupled. A service that receives its repository through its constructor (or DI container) can be tested in isolation and reconfigured per environment. Watch for hidden dependencies: direct `process.env` reads scattered through business logic, global mutable state, `new`-ing concrete classes deep inside business logic instead of receiving them.

## Analysis Workflow

### Step 1: Map the project structure

Use Glob and Read to understand the project layout:
- Find all source files for the stack (`**/*.ts`, `**/*.js`, `**/*.py`, `**/*.go`, `**/*.java`, etc.)
- Identify the **transport/entry layer**: route definitions, controllers, resolvers, handlers (often in `routes/`, `controllers/`, `api/`, `handlers/`, `resolvers/`, or files with "Controller"/"Router"/"Handler" in the name)
- Identify the **business layer**: services, use cases, interactors, domain logic (often in `services/`, `usecases/`, `domain/`, `core/`)
- Identify the **data layer**: repositories, DAOs, models, gateways, clients (often in `repositories/`, `models/`, `dao/`, `gateways/`, `clients/`, `infrastructure/`)
- Identify cross-cutting concerns: middleware, interceptors, guards, decorators, filters
- Note the entry point, how dependencies are wired (manual injection, DI container, globals), and how config/secrets are loaded

Build a mental map: routes → services → repositories → external systems, plus the middleware that wraps requests.

### Step 2a: Analyze controllers/route handlers for SLA and layering

For each controller or route handler, check:
- Does it stay at the transport level — parse/validate input, call one service, shape the response — or does it contain business logic?
- Does it touch the database, ORM, or external SDKs directly (a layering violation)?
- Does it handle multi-step orchestration (e.g., charge payment → create order → send email) inline instead of delegating to a service?
- Does it contain validation/calculation/transformation logic that belongs in the domain layer?
- Does `req`/`res` (or framework request objects) get passed *downward* into services? They shouldn't — extract the needed values and pass plain data.

**Examples of controller-level violations:**
- A route handler that builds a raw SQL query and runs it directly
- A handler that calls `stripe.charges.create(...)` then `db.orders.insert(...)` then `mailer.send(...)` all inline
- A handler with 30 lines of business validation and price calculation before any service call
- A handler that passes the entire `req` object into a service function

### Step 2b: Analyze services/use cases for SLA and layering (do not skip this step)

After finishing the transport layer, open and read every non-trivial service/use-case file. For each, apply the same SLA and layering checks. This is a separate pass, not an afterthought.

Concretely: Read the source of each unit in `services/`, `usecases/`, `domain/`, `core/`, or similar. For each, ask:
- Does this service operate at one consistent abstraction level, composing domain operations and repository calls?
- Or does it drop into low-level plumbing — raw SQL, direct `fetch`/HTTP, SDK calls, manual JSON parsing, crypto/hashing primitives — mixed with high-level orchestration?
- Does it reach for external systems directly instead of through an injected repository/gateway?
- Does it know about HTTP concepts (status codes, headers, `req`/`res`)? It shouldn't.
- Is it a "god service" doing the work of three bounded contexts at once?

**Examples of service-level violations:**
- An `OrderService.create()` that calls `paymentGateway.charge()` (good) but then runs raw `db.query('INSERT ...')` (bad — should go through `OrdersRepository`)
- A `UserService` that imports the Postgres pool at module scope and queries it directly
- A service that returns a `res.status(404)` instead of throwing a domain error the controller maps to a status
- A 400-line `AccountService` handling auth, billing, notifications, and reporting

If a service is clean (one consistent abstraction level, all external access through injected dependencies), note it briefly in the report as well-structured. The goal is to show that every layer was examined, not just controllers.

**The test (applies at every level)**: for any unit, can you describe what it does in a single sentence using only the names of the things it calls? If you have to say "...and also builds a SQL string, parses an HTTP response by hand, and hashes a password", those low-level pieces are SLA/layering violations.

### Step 2c: Analyze repositories/data access

For each repository, DAO, or gateway:
- Is it the *only* place that talks to its backing store/external system?
- Does it leak persistence details (ORM entities, SQL row shapes, raw API payloads) upward, or does it return clean domain objects?
- Does it contain business logic that belongs in a service? (Repositories should do data access, not decide business rules.)
- Is there an abstraction at all, or do services reach past it to the raw client?

### Step 3: Analyze module/service APIs (contracts and signatures)

For each service and repository, evaluate:
- **Signature clarity**: Are methods well-named and minimal? Do they accept domain types, not transport types (`createOrder(input: CreateOrderDto)` not `createOrder(req)`)?
- **Return shape**: Do methods return clean domain objects or raw DB rows / framework objects?
- **Error contract**: Are errors modeled as typed domain errors that the transport layer maps to status codes, or does business code throw HTTP errors / set status codes directly?
- **Parameter explosion**: Methods with 6+ positional parameters often signal a missing input object or a unit doing too much.
- **Boolean flag explosion**: Multiple boolean params (`includeArchived`, `skipCache`, `force`, `dryRun`) often signal the method should be split or accept an options object / strategy.

### Step 4: Analyze cross-cutting concerns and middleware

Look for:
- **Auth/authorization**: Is it centralized in middleware/guards, or re-implemented in each handler?
- **Validation**: Is request validation done once at the boundary (schema/DTO), or scattered and duplicated?
- **Error handling**: Is there a single error-handling middleware that maps domain errors → HTTP responses, or does every handler `try/catch` and format errors itself?
- **Logging / observability / rate limiting**: Centralized, or copy-pasted?
- **Transaction management**: Is the transaction boundary explicit and owned by the service/use-case layer, or smeared across controllers and repositories?

**Check for a consistent error-handling strategy** — this is a common and impactful missing abstraction. If every controller wraps its body in `try/catch` and manually builds error responses, recommend a single error-handling middleware plus a small hierarchy of domain error types (`NotFoundError`, `ValidationError`, `ConflictError`) that the middleware maps to status codes. Business code throws domain errors; only the boundary knows about HTTP.

### Step 5: Analyze data flow, dependency injection, and boundaries

Trace how a request flows and how dependencies are wired:
- Where is state/config owned? Are secrets and config loaded once and injected, or read via `process.env` / globals deep inside business logic?
- Are dependencies injected (constructor, DI container, function args) or reached for via singletons and module-level imports of concrete instances?
- Do transport types (`req`, `res`, headers) leak past the controller? Do persistence types (ORM entities, raw rows) leak past the repository?
- Are there circular dependencies between modules/layers? Does a lower layer import an upper layer (e.g., a repository importing a controller or a service)?

**External dependency adapters should make dependencies explicit.** Prefer the idiom of the project's stack: a class with constructor injection in TypeScript/Java/Kotlin, a struct plus interface in Go, a callable object or module-level factory in Python/Ruby. Avoid bare functions that hide a concrete client, config, or global state at module scope. The adapter should own the external dependency and be replaceable in tests.

**Example of what to recommend:**
- BAD: `orderService.ts` imports the db pool and Stripe SDK and calls `pool.query('INSERT ...')` and `stripe.charges.create(...)` directly.
- GOOD: an injected repository and gateway:
  ```ts
  class OrdersRepository {
    constructor(private deps: { db: Pool }) {}
    async insert(order: NewOrder): Promise<Order> { /* db.query INSERT */ }
    async findById(id: string): Promise<Order | null> { /* db.query SELECT */ }
    async updateStatus(id: string, status: OrderStatus): Promise<void> { /* UPDATE */ }
  }

  class PaymentGateway {
    constructor(private deps: { stripe: Stripe }) {}
    async charge(amount: Money, token: string): Promise<ChargeResult> { /* stripe.charges.create */ }
  }

  class OrderService {
    constructor(private orders: OrdersRepository, private payments: PaymentGateway) {}
    async create(input: CreateOrderInput): Promise<Order> {
      const charge = await this.payments.charge(input.total, input.paymentToken);
      return this.orders.insert({ ...input, chargeId: charge.id });
    }
  }
  ```
  The service orchestrates injected collaborators; it never touches SQL or the Stripe SDK directly. If the team migrates Postgres → DynamoDB or Stripe → Braintree, only the repository/gateway changes — not the service or controller. In tests, pass mock collaborators.

### Step 6: Identify code duplication

Look for:
- Handlers that are nearly identical but for small variations (candidates for a shared service method or a parameterized handler)
- Repeated query/transaction patterns that could be a repository method
- The same validation or transformation logic done in multiple services
- Copy-pasted cross-cutting logic (auth checks, logging, error formatting) that should be middleware

## Output Format

Write the prose report to `BACKEND_ARCHITECTURE_REVIEW_RESULTS.md` in the root of the analyzed project.

Also write a structured handoff to `ARCHITECTURE_FACTS.json` in the same root. This file is consumed by `architecture-html-report` and should capture the facts you verified while reviewing the code. It is not a second report; it is the machine-readable module map, dependency map, workflow list, and data model that prevent the visualization skill from re-discovering the same architecture.

Use this shape:

```json
{
  "metadata": {
    "date": "YYYY-MM-DD",
    "projectName": "name",
    "scope": "path",
    "stack": "language/framework summary"
  },
  "project": {
    "name": "name",
    "path": "absolute-or-invocation-path"
  },
  "modules": [
    {
      "id": "orders-service",
      "name": "OrdersService",
      "layer": "business",
      "path": "src/orders/orders.service.ts",
      "responsibilities": ["Creates orders", "Coordinates payment capture"],
      "interfaces": ["createOrder(input)", "cancelOrder(id)"],
      "externalDependencies": []
    }
  ],
  "dependencies": [
    {
      "from": "orders-controller",
      "to": "orders-service",
      "kind": "calls",
      "evidence": "src/orders/orders.controller.ts imports OrdersService"
    }
  ],
  "externalSystems": [
    {
      "id": "postgres",
      "name": "Postgres",
      "kind": "database",
      "adapterModuleId": "orders-repository"
    }
  ],
  "workflows": [
    {
      "id": "workflow-create-order",
      "title": "Create order",
      "entrypoint": "POST /orders",
      "steps": [
        { "actor": "Client", "action": "POST /orders", "target": "orders-controller" },
        { "actor": "orders-controller", "action": "createOrder(input)", "target": "orders-service" }
      ]
    }
  ],
  "dataModel": {
    "entities": [
      {
        "id": "order",
        "name": "Order",
        "fields": [
          { "name": "id", "type": "string", "key": "PK" },
          { "name": "status", "type": "string" }
        ]
      }
    ],
    "relationships": [
      { "from": "Customer", "to": "Order", "cardinality": "one-to-many", "label": "places" }
    ]
  },
  "issues": [
    {
      "id": "ARCH-001",
      "title": "Controller contains business orchestration",
      "severity": "High",
      "principle": "Layering Violation",
      "locations": ["src/orders/orders.controller.ts"]
    }
  ]
}
```

Keep `ARCHITECTURE_FACTS.json` factual and conservative. If you are unsure whether a dependency or workflow edge exists, verify it in source before including it.

### Report Structure

```markdown
# Backend Architecture Review Results

> Analyzed on: [date]
> Project: [name/path]
> Stack: [language/framework]
> Units analyzed: [N controllers, N services, N repositories]
> Issues found: [N]

## Summary

[2-3 sentence overview of the project's architecture health. Lead with the most impactful finding.]

## Issues

### [ISSUE-ID]: [Short descriptive title]

**Severity**: High | Medium | Low
**Principle**: SLA Violation | Layering Violation | Leaky Boundary | Missing Data Abstraction | Hidden Dependency | Cross-Cutting Duplication | Poor Module API
**Location**: `path/to/file.ext`

[1-2 sentence explanation of WHY this is a problem — what breaks, what becomes harder to maintain or test, what couples the code.]

#### Current (Bad)

` ` `ts
// Shortened version of the actual code showing the problem
` ` `

#### Recommended (Good)

` ` `ts
// How it should look after fixing
` ` `

**Why this is better**: [1 sentence explaining the improvement]

---

[Repeat for each issue]

## Recommendations Summary

| Priority | Issue | Effort | Impact |
|----------|-------|--------|--------|
| 1 | [title] | Low/Med/High | Low/Med/High |
| 2 | ... | ... | ... |

## Architecture Health Score

| Criterion | Score (1-5) | Notes |
|-----------|-------------|-------|
| Single Level of Abstraction | | |
| Layer Separation (routes/services/repos) | | |
| Boundary Discipline (no leaks up/down) | | |
| Data/External Access Abstraction | | |
| Dependency Injection & Testability | | |
| Cross-Cutting Concerns (auth/errors/validation) | | |
| Code Duplication | | |
| **Overall** | | |
```

### Writing the Issue Examples

The CURRENT (Bad) and Recommended (Good) examples are the most important part of the report. Follow these rules:

- **Keep examples short** — 5-15 lines each. Show the essence of the problem, not the entire file. Use `// ...` to skip irrelevant parts.
- **Show real code from the project** — do not invent generic examples. The developer should recognize their own code.
- **The Good example must be realistic** — it should respect the project's existing stack and patterns. Do not introduce a new framework, ORM, or DI container the project doesn't already use.
- **Name things well in the Good example** — service and repository names in the fix should communicate intent, so the orchestration reads like a sentence.
- **One issue per example** — do not fix multiple problems in a single Good example. If a controller has both a layering violation and a leaky boundary, create separate issue entries.

### Severity Guidelines

- **High**: Affects multiple units or makes the codebase actively harder to work with or test. Business logic in controllers, services talking to the database directly, transport types leaking into the domain, no error-handling strategy.
- **Medium**: Localized problem that affects readability, testability, or maintainability of a specific area. Oversized service APIs, inconsistent error handling, duplicated queries.
- **Low**: Organization preference that would improve clarity. Minor naming issues, a slightly misplaced helper, an options object that would read better.

### Tone

Be direct and constructive. The report should read like advice from a senior colleague — specific, grounded in the actual code, and focused on the "why" behind each recommendation. Avoid vague statements like "consider improving" — say what to do and why.

## Important Notes

- Analyze ALL controllers/route handlers, not just a sample. The transport layer is where layering problems are most visible. Then follow the call tree downward — SLA and layering violations in services and repositories are just as important as violations in controllers.
- Do not comment on code formatting, linting, or naming conventions beyond what affects architecture — this review is about layering, separation of concerns, and data flow.
- Do not suggest adding libraries, changing the database, or switching frameworks unless the existing patterns are fundamentally broken.
- Respect the project's scale. A small service does not need the same ceremony as a large one — flag missing abstraction only where the code is actually paying for its absence (duplicated logic, direct external calls, hard-to-test units). Do not recommend layering for its own sake.
- Prioritize issues by impact — lead with the findings that would make the biggest difference if fixed.
- If the project is well-architected, say so! Not every review needs to find problems. A short report that says "this is solid, here are two minor suggestions" is perfectly valid.
- When recommending a data/external abstraction, always show it as an explicit adapter with injected dependencies, using the idiom of the project stack. Never recommend services reaching for raw clients, globals, or module-level singletons — explicit injection keeps units testable and the store swappable.
