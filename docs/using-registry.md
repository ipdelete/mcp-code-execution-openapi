# Using the MCP Tools Registry

The registry system provides a **token-efficient** way to discover and explore MCP tools without loading large OpenAPI specification files into context.

## Problem

OpenAPI specification files can be large (e.g., `github-openapi.json` is 55K). When exploring available tools, loading these full specs wastes tokens on detailed schemas and descriptions you may not need yet.

## Solution: Progressive Disclosure

The registry system implements a **progressive disclosure pattern**:

1. **Discovery Phase**: Load compact `registry/registry.json` (~57K) to browse ALL 65 tools across ALL 5 servers
2. **Implementation Phase**: Only load specific OpenAPI spec when actually creating a script

## Benefits

- **~27% smaller** than loading all OpenAPI specs individually (57K vs 79K combined)
- **Quick tool discovery** across all servers without context bloat
- **Search and filter** tools by name, description, or server
- **Structured metadata** including parameters, types, and summaries
- **Progressive loading** - only fetch full specs when needed

## Usage

### 1. Generate Registry

The registry is automatically generated when you run:

```bash
./scripts/download_openapi.sh
```

Or manually regenerate anytime:

```bash
./scripts/generate_registry.sh
```

### 2. Explore Tools (Primary Interface)

**IMPORTANT: Use `./scripts/list_tools.sh` as the main interface - don't read the registry directly.**

```bash
# List all servers with tool counts
./scripts/list_tools.sh

# List tools for specific server
./scripts/list_tools.sh --server github

# Find tool by exact name
./scripts/list_tools.sh --tool git_status

# Search tool names and descriptions
./scripts/list_tools.sh --search "repository"

# Get full details for a tool
./scripts/list_tools.sh --detail github create_branch

# Show statistics
./scripts/list_tools.sh --stats
```

### 3. Advanced: Direct Registry Queries (Not Recommended for LLMs)

For human debugging or advanced scripting only. LLMs should use `list_tools.sh` instead:

```bash
# List all servers
cat registry/registry.json | jq '.servers | keys'

# List tools for a server
cat registry/registry.json | jq '.servers.github.tools | keys'

# Get tool summary
cat registry/registry.json | jq '.servers.github.tools.create_branch.summary'
```

## Registry Structure

The registry file includes a warning at the top:

```json
{
  "_comment": "DO NOT READ THIS FILE DIRECTLY. Use ./scripts/list_tools.sh as the interface.",
  "_usage": "Run: ./scripts/list_tools.sh --help",
  "generated_at": "2025-11-09T...",
  "servers_dir": "servers",
  "servers": {
    "github": {
      "spec_file": "github-openapi.json",
      "spec_size": "55K",
      "tool_count": 40,
      "tools": {
        "create_branch": {
          "summary": "Create Branch",
          "description": "Create a new branch in a GitHub repository",
          "schema_ref": "#/components/schemas/create_branch_form_model",
          "required_params": ["branch", "owner", "repo"],
          "optional_params": ["from_branch"],
          "params": {
            "branch": { "type": "string", "title": "Branch" },
            "owner": { "type": "string", "title": "Owner" },
            "repo": { "type": "string", "title": "Repo" },
            "from_branch": { "type": "string", "title": "From Branch" }
          }
        }
      }
    }
  }
}
```

## What's Included vs Excluded

**Included in registry** (for quick discovery):
- Tool names and summaries
- Tool descriptions
- Required and optional parameter names
- Parameter types and titles
- Schema references

**Excluded from registry** (load from full spec when needed):
- Detailed parameter descriptions
- Validation rules and constraints
- Example values
- Response schemas
- Error responses

This keeps the registry compact while providing enough information for tool discovery and basic script creation.

## Workflow: Creating a Script

1. **Discover tool** using registry:
   ```bash
   ./scripts/list_tools.sh --server github
   ```

2. **Get basic details** from registry:
   ```bash
   ./scripts/list_tools.sh --detail github create_branch
   ```

3. **Load full spec** only if you need detailed parameter descriptions:
   ```bash
   cat servers/github-openapi.json | jq '.components.schemas.create_branch_form_model'
   ```

4. **Create script** using template:
   ```bash
   cp scripts/TEMPLATE.sh workspace/create_branch.sh
   chmod +x workspace/create_branch.sh
   # Edit SERVER_NAME="github" and TOOL_NAME="create_branch"
   ```

## Token Savings

### Before (loading individual specs):
- context7: 4.2K
- database: 7.1K
- fetch: 2.0K
- git: 11K
- github: 55K
- **Total: 79K**

### After (using registry):
- registry.json: 57K (~27% savings)
- Only load specific spec when implementing

### Real-world savings:
If you're exploring tools across multiple servers, you save ~27% by using the registry instead of loading each OpenAPI spec individually.

## Automatic Updates

The registry is automatically regenerated whenever you download OpenAPI specs:

```bash
./scripts/download_openapi.sh
# Downloads specs from MCPO
# Automatically runs generate_registry.sh
```

No manual regeneration needed!

## Files

- `registry/registry.json` - Token-efficient tool registry (auto-generated)
- `registry/.gitkeep` - Keeps registry/ directory in git
- `scripts/generate_registry.sh` - Registry generation script
- `scripts/list_tools.sh` - Interactive registry browser
- `servers/*-openapi.json` - Full OpenAPI specs (load when needed)
