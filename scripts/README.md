# System Scripts

This directory contains **system/infrastructure scripts** for managing MCPO.

⚠️ **Important:** This is NOT for user scripts. Put your bash scripts that call MCP tools in `workspace/` instead.

## Purpose

These scripts provide the infrastructure for the code-execution-first pattern:
- **MCPO Server Management** - Start the MCP-to-OpenAPI proxy server
- **OpenAPI Spec Download** - Download OpenAPI specifications from MCPO

---

## Available Scripts

### `run_mcpo.sh`

Start the mcpo (MCP-to-OpenAPI) server.

**Purpose:**
- Starts the mcpo proxy server that exposes MCP servers as HTTP endpoints
- Automatically generates OpenAPI specifications for all configured MCP servers
- Long-running process that should be kept alive while using MCP tools

**Usage:**
```bash
# Start with default settings
./scripts/run_mcpo.sh

# Use custom port
./scripts/run_mcpo.sh --port 8080

# Use custom config
./scripts/run_mcpo.sh --config my_mcp_config.json

# Bind to specific host
./scripts/run_mcpo.sh --host 127.0.0.1
```

**Features:**
- Reads `mcp_config.json` (or custom config)
- Exposes Swagger UI at `http://localhost:8000/docs`
- Exposes OpenAPI specs at `http://localhost:8000/{server}/openapi.json`
- Provides interactive API documentation

**Requirements:**
- `uvx` command (from uv package manager)
- `jq` (optional, for displaying server info)

### `download_openapi.sh`

Download OpenAPI specifications from running MCPO server.

**Purpose:**
- Fetches OpenAPI JSON specs from running MCPO server
- Saves specs to `servers/{server-name}-openapi.json`
- Used as reference when creating workspace bash scripts

**Prerequisites:**
- MCPO server must be running (`run_mcpo.sh`)

**Usage:**
```bash
# Download specs from local MCPO
./scripts/download_openapi.sh

# Use custom MCPO port
./scripts/download_openapi.sh --port 8080

# Use custom config file
./scripts/download_openapi.sh --config my_mcp_config.json
```

**Output:**
- OpenAPI specs saved to `servers/git-openapi.json`, `servers/fetch-openapi.json`, etc.
- One JSON file per MCP server configured in `mcp_config.json`

**Requirements:**
- `curl` (standard on most systems)
- `jq` (for JSON validation)

---

## Workflow

**Two-terminal workflow:**

```bash
# Terminal 1: Start MCPO server
./scripts/run_mcpo.sh

# Terminal 2: Download OpenAPI specs (while MCPO is running)
./scripts/download_openapi.sh
```

After downloading specs, create bash scripts in `workspace/` using curl to call MCP tools.

---

## For User Scripts

**Looking to write scripts that call MCP tools?**

👉 Put them in `workspace/` instead!

See `scripts/TEMPLATE.sh` for a copy-paste template and examples like `workspace/git_status.sh`.
