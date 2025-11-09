---
name: mcp-workspace
description: Create bash scripts to interact with MCP servers via MCPO (MCP-to-OpenAPI Proxy). Use this skill when users mention MCP servers, MCPO, or need to create workspace scripts that call MCP tools using the code-execution-first pattern with curl and jq.
---

# MCP Workspace

## Overview

This skill guides the creation of bash scripts that interact with MCP (Model Context Protocol) servers through MCPO (MCP-to-OpenAPI Proxy). Instead of direct MCP protocol calls, scripts use simple HTTP requests with curl and jq to call MCP tools, enabling the **code-execution-first pattern**: fetch data via HTTP, process locally in bash, return minimal results.

## When to Use This Skill

Activate this skill when:
- User mentions MCP servers, MCPO, or Model Context Protocol
- User needs to create a script to call an MCP tool
- User wants to discover available MCP tools and their parameters
- User is working with the code-execution-first MCP workflow

## Quick Start

The typical workflow involves:

1. **Ensure MCPO is running** (in a separate terminal):
   ```bash
   ./scripts/run_mcpo.sh
   ```

2. **Download OpenAPI specs** (if not already downloaded):
   ```bash
   ./scripts/download_openapi.sh
   ```

3. **Create workspace script** (see detailed instructions below)

## Creating a Workspace Script

To create a script that calls an MCP tool:

### 1. Identify the Tool

First, determine which MCP server and tool to use. Use the helper script to list available tools:

```bash
.claude/skills/mcp-workspace/scripts/list_tools.sh <server-name>
```

Or manually explore the OpenAPI spec:
```bash
cat servers/<server-name>-openapi.json | jq '.paths | keys[]'
```

### 2. Check Tool Parameters

Use the helper script to see required parameters:

```bash
.claude/skills/mcp-workspace/scripts/show_tool_schema.sh <server-name> <tool-name>
```

Or manually:
```bash
cat servers/<server-name>-openapi.json | jq '.components.schemas.<tool-name>_form_model'
```

### 3. Copy the Template

The template is available in the skill's assets:

```bash
cp .claude/skills/mcp-workspace/assets/TEMPLATE.sh workspace/<script-name>.sh
```

Or from the repository:
```bash
cp scripts/TEMPLATE.sh workspace/<script-name>.sh
```

### 4. Modify the Script

Update these key sections in the copied template:

**Configuration:**
```bash
SERVER_NAME="git"           # e.g., "git", "fetch", "context7"
TOOL_NAME="git_status"      # e.g., "git_status", "fetch", "resolve_library_id"
```

**Argument Parsing:**
```bash
# Parse arguments based on tool requirements
REPO_PATH="${1:-$(pwd)}"
PARAM2="${2:-default_value}"
```

**Request Body:**
```bash
# Build JSON using jq
REQUEST_BODY=$(jq -n \
  --arg repo_path "$REPO_PATH" \
  --arg param2 "$PARAM2" \
  '{
    repo_path: $repo_path,
    param2: $param2
  }'
)
```

**Response Processing:**
```bash
# Apply code-execution-first pattern:
# Process data locally, return minimal results

# Simple: just print response
echo "$RESPONSE" | jq -r '.'

# Better: process locally
echo "$RESPONSE" | jq -r '.items | length'
echo "Total items: $(echo "$RESPONSE" | jq -r '.items | length')"
```

### 5. Make Executable and Run

```bash
chmod +x workspace/<script-name>.sh
./workspace/<script-name>.sh [arguments]
```

## Convention-Based Configuration

The MCPO workflow follows strict conventions:

### Endpoint Pattern
- **Base URL**: `http://localhost:8000` (configurable via `MCPO_BASE_URL`)
- **Endpoint**: `POST {base_url}/{server_name}/{tool_name}`
- **Example**: `POST http://localhost:8000/git/git_status`

### OpenAPI Spec Locations
- **Pattern**: `servers/{server-name}-openapi.json`
- **Examples**: `servers/git-openapi.json`, `servers/fetch-openapi.json`

### Request/Response Format
- **Request**: JSON body via curl's `-d` flag
- **Content-Type**: `application/json`
- **Response**: JSON (process with jq)

## Code-Execution-First Pattern

The key principle: **fetch data via HTTP, process locally in bash, return minimal results**.

### ❌ Anti-Pattern: Return Raw Data
```bash
# Returns all 10,000 log entries to model context
curl -s -X POST "$MCPO_BASE_URL/git/git_log" \
  -d '{"repo_path": ".", "max_count": 10000}'
```

### ✅ Best Practice: Process Locally
```bash
# Fetch data
LOGS=$(curl -s -X POST "$MCPO_BASE_URL/git/git_log" \
  -H "Content-Type: application/json" \
  -d '{"repo_path": ".", "max_count": 10000}')

# Process locally: count commits by author
echo "$LOGS" | jq -r '.commits[] | .author' | sort | uniq -c | sort -rn

# Result: Compact summary instead of 10,000 log entries
```

## Discovering Available Tools

### List All Servers
```bash
cat mcp_config.json | jq '.mcpServers | keys[]'
```

### List Tools for a Server
```bash
cat servers/git-openapi.json | jq '.paths | keys[]'
```

### Get Tool Description
```bash
cat servers/git-openapi.json | jq '.paths."/git_status".post.description'
```

### Get Tool Parameters
```bash
cat servers/git-openapi.json | jq '.components.schemas.git_status_form_model.properties'
```

### Get Required Parameters
```bash
cat servers/git-openapi.json | jq '.components.schemas.git_status_form_model.required'
```

## Resources

This skill includes bundled resources to support workspace script creation:

### scripts/

Helper scripts for discovering tools and parameters:

- **`list_tools.sh`**: List all available tools for an MCP server
  ```bash
  .claude/skills/mcp-workspace/scripts/list_tools.sh git
  ```

- **`show_tool_schema.sh`**: Show parameter schema for a specific tool
  ```bash
  .claude/skills/mcp-workspace/scripts/show_tool_schema.sh git git_status
  ```

### references/

Detailed reference documentation loaded as needed:

- **`conventions.md`**: Complete guide to MCPO conventions, patterns, and common jq usage
- **`examples.md`**: Comprehensive examples of well-written workspace scripts

Load these when:
- Need detailed jq patterns for complex JSON manipulation
- Want to see multiple complete script examples
- Need reference for error handling or advanced patterns

### assets/

Template file for creating new scripts:

- **`TEMPLATE.sh`**: Copy this to create new workspace scripts with proper structure, error handling, and documentation

## Common Patterns

### Simple Tool Call
```bash
#!/usr/bin/env bash
set -euo pipefail

MCPO_BASE_URL="${MCPO_BASE_URL:-http://localhost:8000}"
REPO_PATH="${1:-$(pwd)}"

REQUEST_BODY=$(jq -n --arg repo_path "$REPO_PATH" '{repo_path: $repo_path}')

curl -s -X POST "${MCPO_BASE_URL}/git/git_status" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_BODY" | jq -r '.'
```

### Error Handling
```bash
RESPONSE=$(curl -sf -X POST "$ENDPOINT_URL" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_BODY")

if [[ $? -ne 0 ]]; then
  echo "Error: Failed to call API at $ENDPOINT_URL"
  echo "Make sure MCPO is running: ./scripts/run_mcpo.sh"
  exit 1
fi
```

### Multiple Parameters
```bash
REQUEST_BODY=$(jq -n \
  --arg param1 "$PARAM1" \
  --arg param2 "$PARAM2" \
  --argjson numeric_param "$NUM" \
  --argjson bool_param true \
  '{
    param1: $param1,
    param2: $param2,
    numeric_param: $numeric_param,
    bool_param: $bool_param
  }'
)
```

### Local Data Processing
```bash
# Fetch data
DATA=$(curl -s -X POST "$ENDPOINT" -H "Content-Type: application/json" -d "$REQUEST_BODY")

# Process locally: filter, aggregate, transform
echo "$DATA" | jq -r '.items[] | select(.status == "active") | .name' | sort

# Process locally: count and summarize
TOTAL=$(echo "$DATA" | jq -r '.items | length')
ACTIVE=$(echo "$DATA" | jq -r '.items[] | select(.status == "active") | .name' | wc -l)
echo "Total: $TOTAL, Active: $ACTIVE"
```
