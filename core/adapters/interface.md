# AgentFlow Adapter Interface

Every PM tool adapter must implement these operations. The core skills and prompts
reference these operations generically — never a specific PM tool.

## Required Operations

| Operation | Description | Returns |
|---|---|---|
| `create_project(name, sections[])` | Create a new project with named sections | project_id |
| `create_task(project_id, section, name, description)` | Create a task in a section | task_id |
| `move_task(task_id, section)` | Move a task to a different section | void |
| `add_comment(task_id, body)` | Add a comment to a task | comment_id |
| `get_comments(task_id, limit?)` | Get comments on a task (newest first) | comment[] |
| `search_tasks(query)` | Search tasks by text | task[] |
| `update_task_description(task_id, description)` | Update task description | void |
| `get_sections(project_id)` | Get all sections in a project | section[] |
| `get_tasks(section_id)` | Get all tasks in a section | task[] |
| `complete_task(task_id)` | Mark a task as complete | void |

## Adapter Mapping

### Asana (via Asana MCP)
- `create_project` -> `create_project_preview` + `create_project_confirm`
- `create_task` -> `create_task_preview` + `create_task_confirm`
- `move_task` -> `update_tasks` (move to section)
- `add_comment` -> `add_comment`
- `get_comments` -> `get_task` (includes comments)
- `search_tasks` -> `search_tasks_preview`
- `update_task_description` -> `update_tasks`
- `get_sections` -> `get_project` (includes sections)
- `get_tasks` -> `get_tasks`
- `complete_task` -> `update_tasks` (mark complete)

### GitHub Projects (planned)
- Uses `gh` CLI commands
- Projects as project boards
- Issues as tasks
- Labels as sections/stages
- Issue comments as comments

### Linear (planned)
- Uses Linear MCP or API
- Projects as projects
- Issues as tasks
- Status as sections/stages
- Issue comments as comments
