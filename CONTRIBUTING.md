# Contributing to AgentFlow

Thank you for your interest in contributing to AgentFlow! This guide will help you get started.

## High-Impact Contribution Areas

### 1. PM Tool Adapters (Highest Priority)

AgentFlow currently works with Asana via MCP. The biggest unlock for the community is adapter support for additional tools:

- **GitHub Projects** (highest priority — makes AgentFlow free to use)
- **Linear** — popular with dev teams
- **Jira** — enterprise support
- **Notion** — for Notion-native teams

See `adapters/` for the adapter interface and the existing Asana adapter as reference.

### 2. Stage Prompt Improvements

The prompts in `prompts/` drive agent behavior at each pipeline stage. Improvements here directly improve pipeline quality:

- Better adversarial review prompts
- More thorough test stage prompts
- Smarter research trigger heuristics
- Improved decomposition quality

### 3. Documentation

- Tutorials for specific project types (Next.js, Python, Flutter, etc.)
- Video walkthroughs
- Translations
- Case studies

### 4. Conventions & Gap Registry

- New gap discoveries (submit as issues first)
- Improved gap fixes
- Additional convention patterns for different tech stacks

## How to Contribute

### Reporting Issues

1. Check existing issues first
2. Include: what you expected, what happened, relevant config
3. For gap discoveries: describe the failure mode, when it occurs, and proposed fix

### Submitting Changes

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Test with a real pipeline run if possible
5. Submit a PR with:
   - Clear description of the change
   - Which gap(s) it addresses (if applicable)
   - How you tested it

### Writing Adapters

An adapter must implement these operations:

```
create_project(name, sections) → project_id
create_task(project_id, section, description) → task_id
move_task(task_id, section)
add_comment(task_id, body)
get_comments(task_id) → comments[]
search_tasks(query) → tasks[]
update_task_description(task_id, description)
get_sections(project_id) → sections[]
mark_complete(task_id)
```

Place your adapter in `adapters/<tool-name>/` with:
- `README.md` — setup instructions
- Implementation files
- Example configuration

### Writing Prompts

Prompts follow a consistent structure:
- Role description (who the agent is)
- Input (what information they receive)
- Process (step-by-step instructions)
- Output (structured comments with machine-readable tags)
- Rules (hard constraints)

All tags must be listed in `conventions.md`.

## Code of Conduct

Be respectful, constructive, and focused on making AgentFlow better for everyone.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
