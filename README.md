# Code Execution with MCP - Bash-First Workflow

This repository demonstrates the **code-execution-first workflow** for AI agents using MCP (Model Context Protocol) servers. Instead of exposing MCP tools through direct protocol calls, agents interact with MCP servers via simple bash scripts using curl and jq, reducing complexity and enabling transparent API interactions.

**Key Innovation:** Use MCPO (MCP-to-OpenAPI Proxy) to expose MCP servers as HTTP REST APIs, then write bash scripts that call these APIs. This enables AI agents to fetch data via HTTP, process it locally in bash, and return minimal results—dramatically reducing token usage and improving performance.

## Prerequisites

Standard tools (available on most systems):

- **bash** - Shell scripting
- **curl** - HTTP client
- **jq** - JSON processor

Additional requirement:

- **uvx** (from [uv package manager](https://github.com/astral-sh/uv)) - For running MCPO

Install uv if needed:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## Setup

### 1. Configure MCP Servers

Copy the example configuration:

```bash
cp mcp_config.example.json mcp_config.json
```

Edit `mcp_config.json` to configure your MCP servers (git, GitHub, fetch, etc.).

### 2. Start MCPO Server

In a dedicated terminal, start the MCP-to-OpenAPI proxy server:

```bash
./scripts/run_mcpo.sh
```

This exposes all configured MCP servers as HTTP endpoints at `http://localhost:8000`.

Access the API:

- **Swagger UI**: <http://localhost:8000/docs>
- **OpenAPI specs**: <http://localhost:8000/{server}/openapi.json>

Leave this terminal running while you work.

### 3. Download OpenAPI Specs

In a second terminal, download the OpenAPI specifications:

```bash
./scripts/download_openapi.sh
```

This downloads JSON specs to `servers/` for all configured MCP servers (e.g., `servers/git-openapi.json`, `servers/github-openapi.json`).

You're now ready to create workspace scripts!

## Example Walkthrough: Fetching Random GitHub Repos

Let's walk through creating a script that fetches 5 random repositories from a GitHub organization—demonstrating the complete workflow.

### Step 1: Discover Available Tools

Use the token-efficient registry interface to find relevant tools:

```bash
./scripts/list_tools.sh --search "repo"
```

This shows `github/search_repositories` is available.

### Step 2: Check Tool Parameters

Get details about the tool:

```bash
./scripts/list_tools.sh --detail github search_repositories
```

Output shows:

- **Required**: `query`
- **Optional**: `perPage`, `minimal_output`, `sort`, `order`, `page`
- **Endpoint**: `POST http://localhost:8000/github/search_repositories`

### Step 3: Create the Script

Copy the template and create a new workspace script:

```bash
cp scripts/TEMPLATE.sh workspace/github_random_repos.sh
```

Edit `workspace/github_random_repos.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Configuration
MCPO_BASE_URL="${MCPO_BASE_URL:-http://localhost:8000}"
SERVER_NAME="github"
TOOL_NAME="search_repositories"
ENDPOINT_URL="${MCPO_BASE_URL}/${SERVER_NAME}/${TOOL_NAME}"

# Parse arguments
ORG_NAME="${1:-}"
COUNT="${2:-5}"

# Validate arguments
if [[ -z "$ORG_NAME" ]]; then
  echo "Usage: $0 <org-name> [count]"
  echo "Example: $0 ipdelete 5"
  exit 1
fi

# Build request body - search for repos in the org
REQUEST_BODY=$(jq -n \
  --arg query "org:${ORG_NAME}" \
  --argjson perPage 100 \
  '{
    query: $query,
    perPage: $perPage,
    minimal_output: false
  }'
)

# Make API call
RESPONSE=$(curl -sf -X POST "$ENDPOINT_URL" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_BODY" 2>/dev/null)

if [[ $? -ne 0 ]]; then
  echo "Error: Failed to call API at $ENDPOINT_URL"
  echo "Make sure MCPO is running: ./scripts/run_mcpo.sh"
  exit 1
fi

# Process response: extract repo names and randomly select COUNT repos
# Code-execution-first: process data locally, return minimal results
echo "$RESPONSE" | jq -r '.items[]? | .full_name' | sort -R | head -n "$COUNT"
```

### Step 4: Run the Script

Make it executable and run:

```bash
chmod +x workspace/github_random_repos.sh
./workspace/github_random_repos.sh ipdelete 5
```

**Output:**

```text
ipdelete/az-nextcloud
ipdelete/psychic_rag_doe
ipdelete/prompt_injection
ipdelete/demigod
ipdelete/csharp-df-counter
```

### Why This Works Well

This approach demonstrates the **code-execution-first pattern**:

1. **Fetch data** - Curl retrieves up to 100 repos from GitHub via MCPO
2. **Process locally** - Bash extracts repo names, randomizes order, limits to 5
3. **Return minimal results** - Only 5 repo names returned (not 100 full repo objects)

**Token savings:** Instead of returning ~50KB of JSON data to the AI model, we return ~200 bytes of text. This is a ~250x reduction in tokens!

## Directory Structure

```text
.
├── scripts/                    # System scripts (infrastructure)
│   ├── run_mcpo.sh            # Start MCPO server
│   ├── download_openapi.sh    # Download OpenAPI specs
│   ├── generate_registry.sh   # Generate token-efficient registry
│   ├── list_tools.sh          # Interactive tool browser
│   └── TEMPLATE.sh            # Template for workspace scripts
├── workspace/                  # Your bash scripts using curl (PUT YOUR SCRIPTS HERE)
│   ├── git_status.sh          # Example: Git status
│   ├── git_diff.sh            # Example: Git diff
│   └── github_random_repos.sh # Example: Fetch random repos
├── servers/                    # Downloaded OpenAPI specs (DO NOT EDIT)
│   ├── git-openapi.json
│   ├── github-openapi.json
│   └── fetch-openapi.json
├── registry/                   # Token-efficient tool registry (auto-generated)
│   └── registry.json          # Compact index of all MCP tools
├── mcp_config.json            # MCP server configurations
└── docs/                      # Design documentation
    ├── code-execution-with-mcp.md
    └── using-registry.md
```

## Discovering Available Tools

**Always use `./scripts/list_tools.sh`** as the primary interface for tool discovery:

```bash
# List all servers and tool counts
./scripts/list_tools.sh

# List tools for a specific server
./scripts/list_tools.sh --server github

# Search tools by keyword
./scripts/list_tools.sh --search "branch"

# Get detailed tool information with parameters
./scripts/list_tools.sh --detail github search_repositories

# Show registry statistics
./scripts/list_tools.sh --stats
```

This interface provides ~27% token savings compared to reading OpenAPI specs directly.

## Creating Workspace Scripts

The `workspace/` directory is where you write bash scripts that call MCP tools. Scripts are created **on-demand** when needed.

**Quick workflow:**

1. **Find the tool**: `./scripts/list_tools.sh --search "keyword"`
2. **Check parameters**: `./scripts/list_tools.sh --detail <server> <tool>`
3. **Copy template**: `cp scripts/TEMPLATE.sh workspace/my_script.sh`
4. **Modify** the script (set SERVER_NAME, TOOL_NAME, build REQUEST_BODY)
5. **Run**: `chmod +x workspace/my_script.sh && ./workspace/my_script.sh`

## Convention-Based Configuration

All scripts follow these conventions:

- **OpenAPI specs**: `servers/{server-name}-openapi.json`
- **MCPO base URL**: `http://localhost:8000` (override with `MCPO_BASE_URL` env var)
- **Endpoint pattern**: `POST {base_url}/{server_name}/{tool_name}`
- **Request format**: JSON body constructed with `jq`
- **Response format**: JSON parsed with `jq`

## Why Bash Instead of Python Clients?

The bash + curl approach offers significant advantages:

- **Faster**: No code generation required—just download JSON specs
- **Simpler**: No dependencies beyond standard tools (curl, jq)
- **Transparent**: Direct HTTP calls are easy to understand and debug
- **Flexible**: Create scripts on-demand as needed
- **Portable**: Works anywhere curl and jq are available
- **Token-efficient**: Process data locally before returning to AI model

## Key Resources

- **Tool Discovery**: `./scripts/list_tools.sh` (always use this interface)
- **Script Template**: `scripts/TEMPLATE.sh` (copy this to create new scripts)
- **Registry Documentation**: `docs/using-registry.md`
- **Pattern Explanation**: `docs/code-execution-with-mcp.md`
- **Repository Guidelines**: `CLAUDE.md`

## Advanced: Working with the Registry

The registry system provides a token-efficient index of all MCP tools:

- **Auto-generated** from OpenAPI specs via `./scripts/generate_registry.sh`
- **~27% smaller** than individual OpenAPI specs
- **Never read directly**—always use `./scripts/list_tools.sh` interface
- Automatically regenerated when OpenAPI specs are downloaded

See `docs/using-registry.md` for complete documentation.
