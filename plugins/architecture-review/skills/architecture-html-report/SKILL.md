---
name: architecture-html-report
argument-hint: <path-to-repository>
disable-model-invocation: true
user-invocable: true
description: Generate a single-file HTML architecture overview with Mermaid diagrams whose syntax is validated before embedding. The report loads Mermaid from an exact pinned CDN runtime and is organized into an App Summary plus Key Workflows.
---

# Architecture HTML Report

You produce a single-file HTML report that gives a reader a fast visual understanding of how a system is **structured** (App Summary: layers, components, dependencies, data model) and how it **runs** (Key Workflows: one sequence diagram per high-value flow). Diagrams are authored in Mermaid and **every diagram's syntax is validated before it is embedded**, so the delivered report never renders a broken diagram.

The report is a single HTML file, but it is not fully offline: it loads Mermaid from an exact pinned CDN runtime. If offline delivery is required, say so and pre-render diagrams to SVG instead of using this template.

This skill pairs naturally with `analyze-backend-architecture`: run the analysis first, then visualize the resulting architecture facts. It also works standalone.

## Non-negotiable rule

**Never embed a Mermaid diagram you have not validated.** Author each diagram as a standalone `.mmd` file, run the validation script until it reports zero failures, and only then build the HTML. A report shipped with an unvalidated diagram is a defect.

## Bundled assets

This skill ships these files next to `SKILL.md`:

- `assets/template.html` - the report shell: styling, sticky table of contents, dark-mode support, exact pinned Mermaid CDN import, and a per-diagram render guard that shows a readable error instead of blanking the page. It has high-level `{{TOKEN}}` placeholders that are filled only by the builder.
- `scripts/build_report.mjs` - deterministic report builder. It reads a JSON config, loads validated `.mmd` files, generates app-summary/workflow articles, builds the table of contents, escapes HTML, rejects duplicate article ids, and fails if any template token remains.
- `scripts/validate_mermaid.sh` - validates every `*.mmd` file under a directory recursively. It pins Mermaid validation dependencies by default (`mermaid@11.15.0`, `@mermaid-js/mermaid-cli@11.15.0`) and records cache markers so stale installs are not silently reused.
- `scripts/parse_check.mjs` - parse-engine helper invoked by the validator fallback.

Resolve their paths relative to this `SKILL.md`.

## Workflow

### Step 1: Gather architecture facts

You cannot diagram what you have not understood. Gather facts for both parts of the report:

**App Summary**
- Map entry points, transport layer, business layer, data layer, cross-cutting middleware, and external systems.
- Identify real dependency edges: who imports or calls whom. Diagrams must reflect actual code, not the desired architecture.

**Key Workflows**
- Identify 2-5 flows that exercise multiple layers, cross an external boundary, or carry core business value.
- Strong candidates: signup, login/auth-refresh, primary write paths, webhook ingest, payment submission, background retry/reconciliation.
- Skip simple CRUD reads unless they are architecturally distinct.

If `ARCHITECTURE_FACTS.json`, `ARCHITECTURE_REVIEW_RESULTS.md`, or `BACKEND_ARCHITECTURE_REVIEW_RESULTS.md` exists, read it first and reuse it. Treat `BACKEND_ARCHITECTURE_REVIEW_RESULTS.md` (written by `analyze-backend-architecture`) and any `ARCHITECTURE_FACTS.json` as verified starting points; verify unclear edges in source before drawing them.

### Step 2: Choose diagrams

Use a small set of complementary diagrams:

| Diagram | Mermaid type | Answers |
|---------|--------------|---------|
| Layers | `flowchart` | What are the layers and which way do dependencies point? |
| Components | `flowchart` | What concrete modules/services wire together? |
| Dependencies | `flowchart` | What is the module dependency graph, and are there cycles? |
| Data Model | `erDiagram` | What are the core entities and relationships? |
| Workflow N | `sequenceDiagram` | How does one important runtime flow move through the system? |

Include only diagrams that add understanding. A stateless service may not need a data model. A small app may not need separate components and dependencies diagrams. Add a `stateDiagram-v2` article when the system has an important state machine.

### Step 3: Author `.mmd` files

Create a working directory such as:

```text
diagrams/
  layers.mmd
  components.mmd
  dependencies.mmd
  er.mmd
  workflows/
    workflow_signup.mmd
    workflow_create_order.mmd
    workflow_stripe_webhook.mmd
```

Each file contains only Mermaid source, with no Markdown fences. The validator searches recursively, so workflow files under `diagrams/workflows/` are included automatically.

Keep each diagram readable: group related nodes with `subgraph`, label edges with verbs, and keep a single diagram around 25-30 nodes. Split large diagrams instead of making one dense graph.

### Step 4: Validate diagrams

Run:

```bash
bash <skill-dir>/scripts/validate_mermaid.sh diagrams
```

Read every `FAIL`, fix the `.mmd`, and rerun until the script exits 0 and prints `0 failed`. The script tries the strongest engine first:

1. Render with `mmdc` from pinned `@mermaid-js/mermaid-cli@11.15.0`.
2. Fall back to `mermaid.parse()` from pinned `mermaid@11.15.0` when Chromium cannot render.

Do not continue if neither engine can run. Report that diagrams could not be validated.

### Step 5: Build the HTML

Create a report config JSON. Diagram paths are resolved relative to the JSON file unless absolute.

```json
{
  "projectName": "Example API",
  "date": "2026-06-09",
  "stack": "Node.js / Express / Postgres",
  "scope": ".",
  "factsPath": "ARCHITECTURE_FACTS.json",
  "summaryParagraph": "The API is organized around transport handlers, application services, repositories, and external adapters.",
  "appSummary": [
    {
      "id": "layers",
      "title": "Layers",
      "tag": "flowchart",
      "intro": "The main request path runs from transport into application logic and then to storage adapters.",
      "diagram": "diagrams/layers.mmd",
      "caption": "Arrows show runtime calls and dependency direction."
    },
    {
      "id": "dependencies",
      "title": "Dependencies",
      "tag": "flowchart",
      "intro": "This view focuses on module imports and the seams between major packages.",
      "diagram": "diagrams/dependencies.mmd",
      "caption": "Unexpected back edges are candidates for follow-up review."
    }
  ],
  "workflowsIntro": "These workflows cover the highest-value write paths.",
  "workflows": [
    {
      "id": "workflow-signup",
      "title": "User signup",
      "tag": "sequence",
      "intro": "A new user creates an account and receives a session.",
      "diagram": "diagrams/workflows/workflow_signup.mmd",
      "caption": "Email delivery is asynchronous and does not block account creation."
    }
  ]
}
```

Build the report:

```bash
node <skill-dir>/scripts/build_report.mjs report-input.json ARCHITECTURE_OVERVIEW.html
```

The builder owns article generation, TOC generation, HTML escaping, duplicate-id checks, Mermaid runtime pinning, and leftover-token checks. Do not manually copy workflow articles or edit template placeholders by hand.

### Step 6: Final verification

Before presenting the report:

1. Re-run `validate_mermaid.sh diagrams`; expect `0 failed`.
2. Build with `build_report.mjs`; it must exit 0.
3. Confirm no `{{` tokens remain in the output HTML.
4. Confirm App Summary appears before Key Workflows.
5. Confirm the shipped report is named `ARCHITECTURE_OVERVIEW.html` unless the user requested another path.

## Mermaid syntax that survives validation

- **Quote labels with special characters.** Any label containing `()`, `:`, `/`, `,`, `&`, `-`, or a leading number must be wrapped: `A["OrderService.create()"]`.
- **`end` is reserved.** Never use `end` as a flowchart node id. Use `done`, `finish`, or a different id with a quoted label.
- **Node ids are simple identifiers.** Use `data_layer`, not `data-layer` or `data layer`.
- **Declare the type on line one.** Start every file with `flowchart TD`, `sequenceDiagram`, `erDiagram`, or `stateDiagram-v2`.
- **Sequence diagrams:** declare participants up front, use `->>` for calls and `-->>` for returns, and wrap optional branches with `alt`/`opt`/`loop ... end`.
- **ER diagrams:** use Mermaid relationship syntax exactly, such as `CUSTOMER ||--o{ ORDER : places`.
- **Comments** start with `%%` on their own line.
- **No raw HTML in labels** under `securityLevel: "strict"`. Use Mermaid-safe text.
- **Keep one statement per line** in flowcharts.

### Minimal examples

`flowchart`:

```text
flowchart TD
  subgraph Transport
    R["Routes / Controllers"]
  end
  subgraph Application
    S["Services / Use Cases"]
  end
  subgraph Data
    Repo["Repositories"]
  end
  DB[("Database")]
  R -->|calls| S
  S -->|uses| Repo
  Repo -->|SQL| DB
```

`sequenceDiagram`:

```text
sequenceDiagram
  participant C as Client
  participant Ctrl as OrderController
  participant Svc as OrderService
  participant Repo as OrdersRepository
  participant DB as Database
  C->>Ctrl: POST /orders
  Ctrl->>Svc: create(input)
  Svc->>Repo: insert(order)
  Repo->>DB: INSERT
  DB-->>Repo: row
  Repo-->>Svc: Order
  Svc-->>Ctrl: Order
  Ctrl-->>C: 201 Created
```

`erDiagram`:

```text
erDiagram
  CUSTOMER ||--o{ ORDER : places
  ORDER ||--|{ ORDER_ITEM : contains
  PRODUCT ||--o{ ORDER_ITEM : "appears in"
  CUSTOMER {
    string id PK
    string email
  }
  ORDER {
    string id PK
    string customerId FK
    string status
  }
```

## Important notes

- **Accuracy over polish.** A correct modest diagram beats a polished diagram that misrepresents the code.
- **Single-file, CDN-rendered output.** The HTML is one file, but Mermaid is loaded from an exact pinned CDN URL. Do not call it offline self-contained unless diagrams are pre-rendered to inline SVG.
- **Do not over-stuff.** Three to five focused diagrams with short captions communicate more than one oversized graph.
- **Keep prose tight.** The diagrams carry the explanation; text only orients the reader.
- **Re-validate after edits.** If any diagram changes after initial validation, validate again before building.
