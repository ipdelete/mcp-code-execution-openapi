# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository demonstrates the **code-execution-first workflow** for AI agents using MCP (Model Context Protocol) servers. Instead of exposing MCP tools through direct protocol calls, agents interact with MCP servers via simple bash scripts using curl, reducing complexity and enabling transparent API interactions.

**Key Reference:** `docs/code-execution-with-mcp.md` explains the design rationale.

## Architecture Overview

### Core Concept: MCPO (MCP-to-OpenAPI Proxy)

The workflow uses `mcpo` to expose MCP servers as HTTP REST APIs with auto-generated OpenAPI specifications:

1. **MCP Servers** (defined in `mcp_config.json`) →
2. **MCPO Server** (HTTP proxy at http://localhost:8000) →
3. **OpenAPI Specs** (in `servers/`) →
4. **Bash Scripts** (in `workspace/`)

This architecture enables:
- **Progressive disclosure**: Only load OpenAPI specs when needed
- **Local processing**: Filter/aggregate data in bash before returning to model context
- **Code control flow**: Use bash loops/conditionals instead of model evaluations
- **Transparency**: Direct curl calls are easy to understand and debug

### Directory Structure

```
.
├── mcp_config.json       # MCP server configurations (git, fetch, context7)
├── scripts/              # System scripts (infrastructure only)
│   ├── run_mcpo.sh      # Start MCPO server
│   ├── download_openapi.sh  # Download OpenAPI specs from MCPO
│   ├── generate_registry.sh  # Generate token-efficient registry
│   ├── list_tools.sh    # Interactive tool browser
│   └── TEMPLATE.sh      # Template for creating workspace scripts
├── workspace/            # User scripts using MCP via curl (PUT YOUR SCRIPTS HERE)
│   ├── git_status.sh    # Example: Get git repository status
│   └── git_diff.sh      # Example: Get git diff (unstaged changes)
├── servers/              # Downloaded OpenAPI specs (DO NOT EDIT)
│   ├── git-openapi.json
│   ├── fetch-openapi.json
│   └── context7-openapi.json
├── registry/             # Token-efficient tool registry (auto-generated)
│   └── registry.json    # Compact index of all MCP tools
└── docs/                 # Design documentation
```

**Critical**:
- System/infrastructure scripts → `scripts/`
- User bash scripts that call MCP tools → `workspace/`
- OpenAPI specs are downloaded, not generated
- Registry is auto-generated from OpenAPI specs
- Scripts are created on-demand when needed

## Development Commands

### Setup and Dependencies

```bash
# No Python dependencies needed!

# Required tools (standard on most Linux systems):
# - bash
# - curl
# - jq
# - uvx (from uv package manager, for running mcpo)

# Install uv if not already installed:
# curl -LsSf https://astral.sh/uv/install.sh | sh
```

### MCPO Workflow (Two-Terminal Process)

**Terminal 1: Run MCPO Server**
```bash
# Start MCPO (exposes MCP servers as HTTP endpoints)
./scripts/run_mcpo.sh

# Custom port
./scripts/run_mcpo.sh --port 8080

# Custom config
./scripts/run_mcpo.sh --config my_mcp_config.json
```

Once running:
- Swagger UI: http://localhost:8000/docs
- OpenAPI spec: http://localhost:8000/{server_name}/openapi.json

**Terminal 2: Download OpenAPI Specs**
```bash
# Download OpenAPI specs for ALL MCP servers in mcp_config.json
# This fetches JSON specs from MCPO and saves to servers/
./scripts/download_openapi.sh

# Custom config
./scripts/download_openapi.sh --config my_mcp_config.json

# Custom port
./scripts/download_openapi.sh --port 8080
```

The script automatically:
- Reads server names from `mcp_config.json` (git, fetch, context7)
- Downloads specs: `servers/git-openapi.json`, `servers/fetch-openapi.json`, `servers/context7-openapi.json`
- Validates JSON format

### Writing Workspace Scripts

**On-Demand Script Creation Pattern:**

Scripts in `workspace/` are created on-demand when you need to call an MCP tool. Follow this workflow:

1. **Find the tool** you need in the OpenAPI spec:
   ```bash
   cat servers/git-openapi.json | jq '.paths | keys'
   ```

2. **Check parameters** required by the tool:
   ```bash
   cat servers/git-openapi.json | jq '.components.schemas.git_status_form_model'
   ```

3. **Copy the template**:
   ```bash
   cp scripts/TEMPLATE.sh workspace/my_script.sh
   ```

4. **Modify** the script:
   - Set `SERVER_NAME` (e.g., "git")
   - Set `TOOL_NAME` (e.g., "git_status")
   - Update argument parsing
   - Build `REQUEST_BODY` with correct parameters
   - Process response as needed

5. **Run**:
   ```bash
   chmod +x workspace/my_script.sh
   ./workspace/my_script.sh [arguments]
   ```

**Example Script Pattern:**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Configuration
MCPO_BASE_URL="${MCPO_BASE_URL:-http://localhost:8000}"
REPO_PATH="${1:-$(pwd)}"

# Build request body
REQUEST_BODY=$(jq -n --arg repo_path "$REPO_PATH" '{
  repo_path: $repo_path
}')

# Make API call
curl -s -X POST \
  "${MCPO_BASE_URL}/git/git_status" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_BODY" \
  | jq -r '.'
```

## Convention-Based Configuration

This project follows strict conventions to make script creation predictable:

### 1. OpenAPI Spec Locations
- **Pattern**: `servers/{server-name}-openapi.json`
- **Examples**:
  - `servers/git-openapi.json`
  - `servers/fetch-openapi.json`
  - `servers/context7-openapi.json`

### 2. MCPO Endpoint Pattern
- **Base URL**: `http://localhost:8000` (override with `MCPO_BASE_URL`)
- **Tool Endpoint**: `POST {base_url}/{server_name}/{tool_name}`
- **Examples**:
  - `POST http://localhost:8000/git/git_status`
  - `POST http://localhost:8000/fetch/fetch`
  - `POST http://localhost:8000/context7/resolve_library_id`

### 3. Request/Response Format
- **Request**: JSON body via `-d` flag
- **Content-Type**: `application/json`
- **Response**: JSON (usually plain string or object)
- **Tool**: Use `jq` for JSON construction and parsing

### 4. Script Naming
- **Location**: `workspace/`
- **Format**: Descriptive, action-based names
- **Examples**: `git_status.sh`, `git_diff.sh`, `fetch_url.sh`
- **Template**: `scripts/TEMPLATE.sh` (copy this!)

### 5. Discovering Tools and Parameters

**PRIMARY METHOD: Use `list_tools.sh` interface** (token-efficient, see `docs/using-registry.md`):

```bash
# IMPORTANT: Always use list_tools.sh - DO NOT read registry.json directly
./scripts/list_tools.sh                        # List all servers
./scripts/list_tools.sh --server github        # List tools for a server
./scripts/list_tools.sh --search "branch"      # Search tools
./scripts/list_tools.sh --detail git git_status  # Full tool details
./scripts/list_tools.sh --stats                # Show statistics
```

**Alternative: Query OpenAPI specs directly** (when you need full parameter descriptions):

```bash
# List all tools for a server
cat servers/git-openapi.json | jq '.paths | keys[]'

# Get tool description
cat servers/git-openapi.json | jq '.paths."/git_status".post.description'

# Get full parameter schema with descriptions
cat servers/git-openapi.json | jq '.components.schemas.git_status_form_model'
```

**Note:** Do NOT read `registry/registry.json` directly. Always use `./scripts/list_tools.sh` as the interface.

## Key Patterns

### Code-Execution-First Pattern

When writing scripts in `workspace/`:

1. **Fetch data** using curl to call MCP tool via MCPO
2. **Process locally** in bash (filter, aggregate, transform)
3. **Return minimal results** (not raw data)

Example:
```bash
# ❌ BAD: Return all 10,000 log entries to model context
curl -s POST "$MCPO_BASE_URL/git/git_log" -d '{"repo_path": ".", "max_count": 10000}'

# ✅ GOOD: Process locally, return summary
LOGS=$(curl -s -X POST "$MCPO_BASE_URL/git/git_log" \
  -H "Content-Type: application/json" \
  -d '{"repo_path": ".", "max_count": 10000}')

# Count commits by author locally
echo "$LOGS" | jq -r '.commits[] | .author' | sort | uniq -c | sort -rn
```

### MCP Configuration

Edit `mcp_config.json` to add/modify MCP servers:

```json
{
  "mcpServers": {
    "server-name": {
      "command": "uvx",
      "args": ["mcp-server-package", "--option", "value"]
    }
  }
}
```

After changes: restart MCPO and re-download OpenAPI specs.

## Architecture Notes

### Why Separate scripts/ and workspace/?

- **`scripts/`**: Infrastructure management (run MCPO, download specs)
  - Maintained by repository
  - Don't add user scripts here

- **`workspace/`**: User scripts using curl to call MCP tools
  - Where agents/users write code-execution-first scripts
  - Uses OpenAPI specs from `servers/`
  - Created on-demand as needed

### Why Download OpenAPI Specs?

The `servers/` directory contains OpenAPI JSON specs downloaded from MCPO:
- Provide documentation for available tools and parameters
- No code generation needed
- Must be re-downloaded when MCP servers change
- Used as reference when writing bash scripts

Never edit these files manually—they're downloaded from MCPO.

### Why Bash Instead of Python Clients?

Advantages of bash + curl approach:
- **Faster**: No code generation, just download JSON specs
- **Simpler**: No dependencies beyond curl and jq
- **Transparent**: Easy to see exactly what's being sent/received
- **Flexible**: Scripts created on-demand as needed
- **Portable**: Works anywhere curl and jq are available

### LLM Guidance: Creating Scripts

When an LLM needs to call an MCP tool:

1. **Identify the tool** from context or by exploring specs
2. **Read the OpenAPI spec** to understand parameters
3. **Copy `scripts/TEMPLATE.sh`** as starting point
4. **Modify** for specific tool:
   - Update SERVER_NAME and TOOL_NAME
   - Parse appropriate arguments
   - Build correct REQUEST_BODY
   - Process response appropriately
5. **Make executable** and run

**Quick jq patterns:**

```bash
# List all paths (tools)
jq '.paths | keys' servers/git-openapi.json

# Get schema for specific tool
jq '.components.schemas.git_status_form_model' servers/git-openapi.json

# Extract required parameters
jq '.components.schemas.git_status_form_model.required' servers/git-openapi.json

# Get parameter types
jq '.components.schemas.git_status_form_model.properties' servers/git-openapi.json
```

## Environment

- **Bash**: Standard bash shell
- **curl**: HTTP client (standard on most systems)
- **jq**: JSON processor (standard on most systems)
- **uvx**: Command from `uv` package manager (for running mcpo)
- **Target Platform**: Linux (Arch Linux)

## Common Gotchas

1. **MCPO must be running** before downloading specs—`download_openapi.sh` fetches from the live server
2. **OpenAPI specs are in `.gitignore`**—they're downloaded from MCPO, so commit `mcp_config.json` instead (or `mcp_config.example.json`)
3. **Scripts are created on-demand**—don't try to pre-generate all possible scripts, create them when needed
4. **Use jq for JSON**—both building request bodies and parsing responses
5. **Check OpenAPI spec first**—before writing a script, look at the spec to understand parameters
