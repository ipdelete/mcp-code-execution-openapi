# Quick Start Guide

## Overview

This repository demonstrates the **code-execution-first workflow** for AI agents using MCP servers. Instead of exposing tools through direct protocol calls, agents interact with MCP servers via simple bash scripts using curl, reducing complexity and enabling transparent API interactions.

## Current Setup

**MCP Servers Configured** (in `mcp_config.json`):
1. `git` - Git repository operations
2. `fetch` - Web fetching capabilities
3. `context7` - Documentation lookup service

**OpenAPI Specs:**
- `servers/{server-name}-openapi.json` - Downloaded JSON specifications

## Workflow

### 1. Run MCPO Server

Start the MCP-to-OpenAPI proxy server:

```bash
# Terminal 1
./scripts/run_mcpo.sh
```

This exposes all MCP servers as HTTP endpoints at:
- Swagger UI: http://localhost:8000/docs
- OpenAPI specs: http://localhost:8000/{server}/openapi.json

### 2. Download OpenAPI Specs

While MCPO is running, download the specifications:

```bash
# Terminal 2
./scripts/download_openapi.sh
```

This **automatically**:
1. Reads server names from `mcp_config.json` (git, fetch, context7)
2. Downloads OpenAPI specs to `servers/git-openapi.json`, `servers/fetch-openapi.json`, `servers/context7-openapi.json`
3. Validates JSON format

**That's it!** You're ready to write scripts.

### 3. Write Bash Scripts Using curl

Create scripts in `workspace/` directory. Use the template as a starting point:

```bash
cp scripts/TEMPLATE.sh workspace/my_script.sh
```

**Example - Git Status:**

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

Make executable and run:

```bash
chmod +x workspace/my_script.sh
./workspace/my_script.sh
```

## Creating Scripts: Step-by-Step

### 1. Find Available Tools

List all tools for a server:

```bash
cat servers/git-openapi.json | jq '.paths | keys[]'
```

Output:
```
/git_status
/git_diff_unstaged
/git_diff_staged
/git_commit
/git_add
...
```

### 2. Check Tool Parameters

See what parameters a tool needs:

```bash
cat servers/git-openapi.json | jq '.components.schemas.git_status_form_model'
```

Output:
```json
{
  "properties": {
    "repo_path": {
      "type": "string",
      "title": "Repo Path",
      "description": ""
    }
  },
  "type": "object",
  "required": ["repo_path"],
  "title": "git_status_form_model"
}
```

### 3. Build the Request

Use jq to construct the JSON request body:

```bash
REQUEST_BODY=$(jq -n \
  --arg repo_path "/path/to/repo" \
  '{
    repo_path: $repo_path
  }'
)
```

### 4. Call the API

Make the POST request:

```bash
curl -s -X POST \
  "http://localhost:8000/git/git_status" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_BODY" \
  | jq -r '.'
```

## Exploring the OpenAPI Spec

**Useful jq queries:**

```bash
# List all tools
jq '.paths | keys' servers/git-openapi.json

# Get tool description
jq '.paths."/git_status".post.description' servers/git-openapi.json

# Get all required parameters
jq '.components.schemas.git_status_form_model.required' servers/git-openapi.json

# Get parameter details
jq '.components.schemas.git_status_form_model.properties' servers/git-openapi.json
```

## Key Benefits

| Feature | Benefit |
|---------|---------|
| **Progressive Disclosure** | Only load OpenAPI specs when needed |
| **Context Efficiency** | Process data locally in bash, return filtered results |
| **Code Control Flow** | Use bash loops/conditionals instead of model evaluations |
| **Transparency** | Direct curl calls are easy to understand and debug |
| **Speed** | No code generation, just download JSON specs |

**Result:** Up to 98.7% reduction in token consumption vs. direct tool calls

## Project Structure

```
.
├── mcp_config.json              # MCP server configurations
├── scripts/
│   ├── run_mcpo.sh              # Start MCPO server
│   ├── download_openapi.sh      # Download OpenAPI specs
│   └── TEMPLATE.sh              # Template for workspace scripts
├── workspace/                    # Your bash scripts
│   ├── git_status.sh            # Example: Git status
│   └── git_diff.sh              # Example: Git diff
├── servers/                      # Downloaded OpenAPI specs
│   ├── git-openapi.json
│   ├── fetch-openapi.json
│   └── context7-openapi.json
└── docs/
    └── code-execution-with-mcp.md  # Design rationale
```

## Convention-Based Configuration

- **OpenAPI specs**: `servers/{server-name}-openapi.json`
- **MCPO base URL**: `http://localhost:8000` (override with `MCPO_BASE_URL` env var)
- **Endpoint pattern**: `POST {base_url}/{server_name}/{tool_name}`
- **Request format**: JSON body (use jq to construct)
- **Response format**: JSON (use jq to parse)

## Next Steps

1. **Explore the API** - Visit http://localhost:8000/docs while MCPO is running
2. **Try the examples** - Run `./workspace/git_status.sh` or `./workspace/git_diff.sh`
3. **Write your own scripts** - Copy `scripts/TEMPLATE.sh` to workspace and modify for your needs
4. **Add more MCP servers** - Edit `mcp_config.json` and re-run `download_openapi.sh`

## Documentation

- **Full pattern explanation:** `docs/code-execution-with-mcp.md`
- **Repository guidelines:** `CLAUDE.md`
- **Main README:** `README.md`

## Requirements

- **bash**, **curl**, **jq** (standard on most Linux systems)
- **uvx** (from uv package manager, for running mcpo)
