# MCPO Conventions and Patterns

This reference documents the key conventions used in the code-execution-first MCP workflow.

## Directory Structure

```
.
├── mcp_config.json       # MCP server configurations
├── scripts/              # Infrastructure scripts (don't modify)
│   ├── run_mcpo.sh      # Start MCPO server
│   ├── download_openapi.sh  # Download OpenAPI specs
│   ├── generate_registry.sh  # Generate token-efficient registry
│   ├── list_tools.sh    # Interactive tool browser (PRIMARY INTERFACE)
│   └── TEMPLATE.sh      # Template for workspace scripts
├── workspace/            # User scripts (PUT YOUR SCRIPTS HERE)
│   └── *.sh             # Scripts calling MCP tools via curl
├── servers/              # Downloaded OpenAPI specs (auto-generated)
│   └── *-openapi.json   # OpenAPI specs from MCPO
└── registry/             # Token-efficient tool registry (auto-generated)
    └── registry.json    # Compact index (DO NOT READ DIRECTLY)
```

## Convention-Based Configuration

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

## Discovering Tools and Parameters

**IMPORTANT: Always use `./scripts/list_tools.sh` as the primary interface. Do NOT read `registry/registry.json` directly.**

### PRIMARY METHOD: Using list_tools.sh (Token-Efficient)

```bash
# List all servers with tool counts
./scripts/list_tools.sh

# List tools for a specific server
./scripts/list_tools.sh --server git

# Search tools by keyword
./scripts/list_tools.sh --search "branch"

# Get full tool details (summary, description, parameters, endpoint)
./scripts/list_tools.sh --detail git git_status

# Show registry statistics
./scripts/list_tools.sh --stats
```

### ALTERNATIVE: Direct OpenAPI Queries (When Full Descriptions Needed)

Use these only when you need detailed parameter descriptions:

```bash
# Get tool description
cat servers/git-openapi.json | jq '.paths."/git_status".post.description'

# Get complete parameter schema with full descriptions
cat servers/git-openapi.json | jq '.components.schemas.git_status_form_model'

# Get parameter types
cat servers/git-openapi.json | jq '.components.schemas.git_status_form_model.properties'

# Get required parameter list
cat servers/git-openapi.json | jq '.components.schemas.git_status_form_model.required'
```

## Code-Execution-First Pattern

The key principle: **process data locally in bash, return minimal results**.

### ❌ Bad: Return raw data
```bash
# Returns all 10,000 log entries to model context
curl -s -X POST "$MCPO_BASE_URL/git/git_log" \
  -H "Content-Type: application/json" \
  -d '{"repo_path": ".", "max_count": 10000}'
```

### ✅ Good: Process locally, return summary
```bash
# Fetch data
LOGS=$(curl -s -X POST "$MCPO_BASE_URL/git/git_log" \
  -H "Content-Type: application/json" \
  -d '{"repo_path": ".", "max_count": 10000}')

# Process locally (filter, aggregate, transform)
echo "$LOGS" | jq -r '.commits[] | .author' | sort | uniq -c | sort -rn

# Returns: Commit count by author (compact summary)
```

## Common jq Patterns

### Building request bodies

**Simple parameters:**
```bash
REQUEST_BODY=$(jq -n \
  --arg repo_path "$REPO_PATH" \
  '{
    repo_path: $repo_path
  }'
)
```

**Multiple parameters:**
```bash
REQUEST_BODY=$(jq -n \
  --arg param1 "$PARAM1" \
  --arg param2 "$PARAM2" \
  '{
    param1: $param1,
    param2: $param2
  }'
)
```

**With numeric/boolean values:**
```bash
REQUEST_BODY=$(jq -n \
  --arg url "$URL" \
  --argjson max_count "$MAX_COUNT" \
  --argjson include_deleted true \
  '{
    url: $url,
    max_count: $max_count,
    include_deleted: $include_deleted
  }'
)
```

### Parsing responses

**Extract plain text:**
```bash
echo "$RESPONSE" | jq -r '.'
```

**Extract specific field:**
```bash
echo "$RESPONSE" | jq -r '.field_name'
```

**Filter array:**
```bash
echo "$RESPONSE" | jq -r '.items[] | select(.status == "active") | .name'
```

**Count items:**
```bash
echo "$RESPONSE" | jq -r '.items | length'
```

**Transform data:**
```bash
echo "$RESPONSE" | jq -r '.commits[] | "\(.author): \(.message)"'
```
