# GitHub Projects Adapter

> **Status: Planned** — Community contributions welcome!

Free alternative to the Asana adapter. Uses GitHub Projects (v2) as the Kanban board.

## Why This Matters

GitHub Projects is free for all GitHub users, making AgentFlow accessible without any paid PM tool subscription. This is the highest-priority adapter for the community.

## Planned Mapping

| AgentFlow Concept | GitHub Projects Feature |
|-------------------|------------------------|
| Pipeline project | GitHub Project (v2) |
| Pipeline stages | Project columns/status field |
| Tasks | Project items (linked to Issues) |
| Agent comments | Issue comments |
| Dependencies | Issue references / task lists |
| Status dashboard | Pinned issue |
| Metadata | Issue body header (same regex format) |

## Contributing

If you'd like to build this adapter:

1. Implement the adapter interface (see `adapters/asana/README.md` for reference)
2. Use GitHub's GraphQL API or the `gh` CLI for project operations
3. Map all comment tags to issue comments
4. Handle the column/status field transitions
5. Submit a PR

Key challenges:
- GitHub Projects v2 uses GraphQL (not REST) for most operations
- Status field updates require knowing the field ID and option IDs
- Dependencies are less native than Asana — may need a convention (e.g., task list checkboxes)
