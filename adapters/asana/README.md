# Asana Adapter

The default adapter for AgentFlow. Uses Asana's MCP (Model Context Protocol) integration to read and write pipeline state.

## Requirements

- Asana account (free tier works for small projects)
- Asana MCP server configured in Claude Code

## Setup

1. Install the Asana MCP server in your Claude Code configuration
2. Authenticate with your Asana workspace
3. Run `/spec-to-asana` to create your first pipeline board

## How It Maps

| AgentFlow Concept | Asana Feature |
|-------------------|---------------|
| Pipeline project | Asana Project |
| Pipeline stages | Asana Sections (columns in Board view) |
| Tasks | Asana Tasks |
| Agent comments | Asana Task Comments |
| Dependencies | Asana Task Dependencies |
| Status dashboard | Pinned Task in "Needs Human" section |
| Cost/retry metadata | Task description header (regex-parsed) |

## API Operations Used

| Operation | Asana MCP Tool |
|-----------|---------------|
| Create project | `create_project_preview` |
| Create task | Included in `create_project_preview` |
| Move task | `update_tasks` (change section) |
| Add comment | `add_comment` |
| Get comments | `get_task` (includes comments) |
| Search tasks | `search_tasks_preview` |
| Update description | `update_tasks` |
| Set dependencies | `update_tasks` (add_dependencies) |
| Get sections | `get_project` (include_sections) |
| Mark complete | `update_tasks` (completed: true) |

## Limitations

- Asana free tier limits: 15 team members, no portfolios
- Custom fields not used (metadata lives in description headers)
- Rate limits: ~150 requests per minute per user
- Max 1-2 levels of subtask depth recommended
