## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- When graphify-out/graph.json exists, run `graphify query "<question>"` before your first grep, search or source-file read for a codebase question, and put this rule in every subagent prompt that explores code. Read raw files only for lines the graph or an earlier read already located. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
- A committed graphify-out/graph.json is rewritten whole on every build, so a large diff to it in a pull request is expected. Do not flag it as churn or suggest skipping the graph rebuild or its hooks.

## Project conventions
- CLI-only macOS app (Swift Package). No UI. Read docs/ARCHITECTURE.md for layers and extension points.
- Object-oriented, protocol-first. One engine per concern; new gesture/action/command = add a type and register it, never edit existing engines.
- Layers depend downward only (see Package.swift). GestureCore stays Foundation-only. Private Apple APIs only in MultitouchTouchSource.swift.
- Use the local Graphify CLI (`graphify query|path|explain`), not any hosted Graphify connector. Run `graphify update .` after code changes.
- Build: `swift build`. Tests need full Xcode (XCTest is absent with Command Line Tools only).
