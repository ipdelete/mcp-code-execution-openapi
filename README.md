# Code Execution with MCP - Bash-First Workflow

This repository demonstrates the **code-execution-first workflow** for AI agents using MCP servers. Instead of exposing tools through direct protocol calls, agents interact with MCP servers via simple bash scripts using curl, reducing complexity and enabling transparent API interactions.

## Quick Start

### 1. Run MCPO Server

Start the MCP-to-OpenAPI proxy server that exposes all MCP servers as HTTP endpoints:

```bash
./scripts/run_mcpo.sh
```

Access the API:
- Swagger UI: http://localhost:8000/docs
- OpenAPI specs: http://localhost:8000/{server}/openapi.json

### 2. Download OpenAPI Specs

While MCPO is running, download the OpenAPI specifications:

```bash
./scripts/download_openapi.sh
```

This downloads JSON specs to `servers/` for all configured MCP servers (git, fetch, context7).

### 3. Write Bash Scripts Using curl

Create scripts in `workspace/` that use curl to interact with MCP servers via MCPO:

```bash
#!/usr/bin/env bash
# workspace/git_status.sh

MCPO_BASE_URL="${MCPO_BASE_URL:-http://localhost:8000}"
REPO_PATH="${1:-$(pwd)}"

REQUEST_BODY=$(jq -n --arg repo_path "$REPO_PATH" '{
  repo_path: $repo_path
}')

curl -s -X POST \
  "${MCPO_BASE_URL}/git/git_status" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_BODY" \
  | jq -r '.'
```

## Directory Structure

```
.
├── scripts/              # System scripts (infrastructure)
│   ├── run_mcpo.sh      # Start MCPO server
│   ├── download_openapi.sh  # Download OpenAPI specs
│   └── TEMPLATE.sh      # Template for workspace scripts
├── workspace/            # Your bash scripts using curl
│   ├── git_status.sh    # Example: Git status
│   └── git_diff.sh      # Example: Git diff
├── servers/              # Downloaded OpenAPI specs (JSON)
│   ├── git-openapi.json
│   ├── fetch-openapi.json
│   └── context7-openapi.json
├── mcp_config.json      # MCP server configurations
└── docs/                # Documentation
```

## System Scripts

Located in `scripts/`:

- **`run_mcpo.sh`** - Start the MCPO server
- **`download_openapi.sh`** - Download OpenAPI specs from MCPO

## Workspace

The `workspace/` directory is for your bash scripts that call MCP tools via curl. This is where you write code-execution-first scripts that interact with MCP servers through HTTP.

**Creating a new script:**

1. Copy the template: `cp scripts/TEMPLATE.sh workspace/my_script.sh`
2. Check the OpenAPI spec for your tool: `cat servers/git-openapi.json | jq '.paths'`
3. Modify the script to call the correct endpoint with correct parameters
4. Make executable: `chmod +x workspace/my_script.sh`
5. Run: `./workspace/my_script.sh`

## Convention-Based Configuration

- **OpenAPI specs**: `servers/{server-name}-openapi.json`
- **MCPO base URL**: `http://localhost:8000` (via `MCPO_BASE_URL` env var)
- **Endpoint pattern**: `POST {base_url}/{server_name}/{tool_name}`
- **Request format**: JSON body (use jq to construct)
- **Response format**: JSON (use jq to parse)

## Why Bash Instead of Python Clients?

- **Faster**: No code generation, just download JSON specs
- **Simpler**: No dependencies beyond curl and jq (standard on most systems)
- **Transparent**: Easy to see exactly what's being sent/received
- **Flexible**: Scripts created on-demand as needed
- **Portable**: Works anywhere curl and jq are available

## Documentation

- **Repository guidelines:** `CLAUDE.md`
- **Pattern explanation:** `docs/code-execution-with-mcp.md`
- **Quick start:** `QUICKSTART.md`

## Requirements

- **bash**, **curl**, **jq** (standard on most Linux systems)
- **uvx** (from uv package manager, for running mcpo)
