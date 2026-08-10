---
name: opencode-marketplace
description: Reference guide for the opencode-marketplace CLI tool. Use this skill when users want to install, uninstall, update, list, or scan OpenCode plugins; manage plugin components (commands, agents, skills); work with plugin scopes (user/project); handle GitHub-based plugins; or need guidance on plugin structure and conventions.
---

# OpenCode Marketplace CLI Skill

Use this skill to manage OpenCode plugins through the opencode-marketplace CLI tool.

## Overview

The OpenCode Marketplace CLI provides a convention-based plugin system for OpenCode. Plugins are simply directories containing commands, agents, and skills that get auto-discovered and installed to standard OpenCode locations.

**Key Capabilities:**
- Install plugins from local directories
- List installed plugins with metadata
- Scan plugins before installing (dry-run)
- Uninstall plugins cleanly
- Support for user-global and project-local scopes
- Content-hash based change detection (no versions needed)

## Quick Reference

| Command | Syntax | Purpose |
|---------|--------|---------|
| **install** | `install <path> [options]` | Install plugin from local path or GitHub URL |
| **uninstall** | `uninstall <name> [options]` | Remove installed plugin |
| **list** | `list [options]` | Show installed plugins |
| **scan** | `scan <path>` | Preview plugin contents (dry-run) |
| **update** | `update <name> [options]` | Update remote plugin to latest |

**Common Options:**
- `--scope <user|project>` - Target scope (default: user)
- `--force` - Force overwrite conflicts (install only)
- `--verbose` - Detailed output

**Path Types:**
- **Local**: `/path/to/plugin` or `./relative/path`
- **GitHub**: `https://github.com/owner/repo[/tree/ref][/subfolder]`

## Installation

The CLI can be run without installation using bunx:

```bash
bunx opencode-marketplace <command>
```

Or install globally for faster access:

```bash
bun install -g opencode-marketplace
```

## Commands

### 1. Install a Plugin

```bash
bunx opencode-marketplace install <path> [options]
```

**Options:**
- `--scope <user|project>` - Installation scope (default: user)
- `--force` - Overwrite existing untracked files
- `--verbose` - Show detailed installation progress

### 2. List Installed Plugins

```bash
bunx opencode-marketplace list [options]
```

### 3. Scan a Plugin (Dry-Run)

```bash
bunx opencode-marketplace scan <path> [options]
```

### 4. Uninstall a Plugin

```bash
bunx opencode-marketplace uninstall <name> [options]
```

### 5. Update a Plugin

```bash
bunx opencode-marketplace update <name> [options]
```

## Plugin Structure

```
my-plugin/
├── command/           # Commands (*.md files)
├── agent/            # Agents (*.md files)
└── skill/            # Skills (directories with SKILL.md)
```

### Discovery Priority

| Component | Priority 1 | Priority 2 | Priority 3 | Priority 4 |
|-----------|------------|------------|------------|------------|
| Commands | `.opencode/command/` | `.claude/commands/` | `./command/` | `./commands/` |
| Agents | `.opencode/agent/` | `.claude/agents/` | `./agent/` | `./agents/` |
| Skills | `.opencode/skill/` | `.claude/skills/` | `./skill/` | `./skills/` |
