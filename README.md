# architecture-skills

A Claude Code plugin marketplace with skills for reviewing and visualizing software architecture.

## Plugin: `architecture-review`

Two skills:

- **`analyze-backend-architecture`** — reviews a backend codebase for layering quality, separation of concerns, data-flow clarity, dependency injection, Single-Level-of-Abstraction violations, and Stepdown Rule (top-down narrative ordering) issues across routes, services, and repositories. Writes `BACKEND_ARCHITECTURE_REVIEW_RESULTS.md` plus a structured `ARCHITECTURE_FACTS.json` handoff for visualization.
- **`architecture-html-report`** — generates a single-file HTML architecture overview with Mermaid diagrams. Two-tier layout: an **App Summary** (layers, components, dependency graph, data model) and **Key Workflows** (one sequence diagram per high-value flow). The report loads Mermaid from an exact pinned CDN runtime, and every diagram's syntax is validated before it is embedded.

## Install

Two paths: **repo mode** for normal use, **dev mode** for hacking on the skills with live edits.

### Repo mode (published-style, copies into Claude Code cache)

In Claude Code:

```
/plugin marketplace add pterolex/architecture-skills
/plugin install architecture-review@architecture-skills
```

Update later with:

```
/plugin marketplace update
```

Use this when you just want the skills available across sessions. `/plugin install` copies the plugin into `~/.claude/plugins/cache/`, so edits to the source repo do **not** flow through — you'd need to re-install (or `/plugin marketplace update`) after each change.

### Dev mode (live edits, no install)

Clone the repo and launch Claude Code with `--plugin-dir` pointing at the plugin source. Edits to `SKILL.md`, `assets/template.html`, or any script take effect on the next session — no copy step.

```bash
git clone https://github.com/pterolex/architecture-skills.git
cd architecture-skills

claude --plugin-dir "$(pwd)/plugins/architecture-review"
```

For a sticky default across sessions, set the env var in your shell rc:

```bash
export CLAUDE_PLUGIN_DIRS="$HOME/path/to/architecture-skills/plugins/architecture-review"
```

You can also add a local marketplace pointed at the cloned directory:

```
/plugin marketplace add /absolute/path/to/architecture-skills
/plugin install architecture-review@architecture-skills
```

Note this still copies into the cache — `--plugin-dir` / `CLAUDE_PLUGIN_DIRS` is the cleanest path for live iteration.

### Invoke a skill

Once installed (either mode), point a skill at a repository path:

```
/analyze-backend-architecture .
/architecture-html-report .
```

## Requirements

- The `architecture-html-report` skill validates diagrams recursively with pinned Mermaid tooling (`@mermaid-js/mermaid-cli@11.15.0`, `mermaid@11.15.0`). It renders through `mmdc` when Chromium is available, then automatically falls back to a browserless `mermaid.parse()` check. Node.js and npm must be available.
- The final HTML is one file, but it is not fully offline because Mermaid is loaded from a pinned CDN URL. For offline delivery, pre-render diagrams to inline SVG instead.
- The report HTML is assembled by `scripts/build_report.mjs`; do not manually duplicate workflow HTML or replace template tokens.

## Repository layout

```
architecture-skills/
├── .claude-plugin/
│   └── marketplace.json
└── plugins/
    └── architecture-review/
        ├── .claude-plugin/
        │   └── plugin.json
        └── skills/
            ├── analyze-backend-architecture/
            │   └── SKILL.md
            └── architecture-html-report/
                ├── SKILL.md
                ├── assets/template.html
                ├── test-fixtures/
                └── scripts/
                    ├── build_report.mjs
                    ├── verify.sh
                    ├── validate_mermaid.sh
                    └── parse_check.mjs
```

Skills are auto-discovered from each plugin's `skills/` directory, so they do not need to be listed in `plugin.json`.

## Verify

Run the bundled smoke test:

```
bash plugins/architecture-review/skills/architecture-html-report/scripts/verify.sh
```

It checks recursive Mermaid discovery with nested workflow fixtures, validates the report builder syntax, builds a fixture report, confirms the pinned Mermaid runtime, and fails on unreplaced template tokens.

## License

MIT
