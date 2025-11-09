# Example Workspace Scripts

This reference provides examples of well-written workspace scripts.

## Example 1: Simple Git Status

A minimal script that calls `git_status` and returns the output.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Configuration
MCPO_BASE_URL="${MCPO_BASE_URL:-http://localhost:8000}"
REPO_PATH="${1:-$(pwd)}"

# Build request
REQUEST_BODY=$(jq -n --arg repo_path "$REPO_PATH" '{
  repo_path: $repo_path
}')

# Make API call
echo "Fetching git status for: $REPO_PATH"
echo ""

curl -s -X POST \
  "${MCPO_BASE_URL}/git/git_status" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_BODY" \
  | jq -r '.'
```

## Example 2: Git Diff with Error Handling

Shows proper error handling when MCPO isn't running.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Configuration
MCPO_BASE_URL="${MCPO_BASE_URL:-http://localhost:8000}"
REPO_PATH="${1:-$(pwd)}"

# Build request
REQUEST_BODY=$(jq -n --arg repo_path "$REPO_PATH" '{
  repo_path: $repo_path
}')

# Make API call with error handling
RESPONSE=$(curl -sf \
  -X POST \
  "${MCPO_BASE_URL}/git/git_diff" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_BODY")

if [[ $? -ne 0 ]]; then
  echo "Error: Failed to call API"
  echo "Make sure MCPO is running: ./scripts/run_mcpo.sh"
  exit 1
fi

# Process response
echo "$RESPONSE" | jq -r '.'
```

## Example 3: Fetch URL with Multiple Parameters

Shows how to handle multiple parameters, including optional ones.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Configuration
MCPO_BASE_URL="${MCPO_BASE_URL:-http://localhost:8000}"

# Parse arguments
URL="${1:-}"
RAW="${2:-false}"

if [[ -z "$URL" ]]; then
  echo "Usage: $0 <url> [raw:true|false]"
  exit 1
fi

# Build request with optional parameter
REQUEST_BODY=$(jq -n \
  --arg url "$URL" \
  --argjson raw "$RAW" \
  '{
    url: $url,
    raw: $raw
  }'
)

# Make API call
echo "Fetching: $URL"
echo ""

curl -s -X POST \
  "${MCPO_BASE_URL}/fetch/fetch" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_BODY" \
  | jq -r '.'
```

## Example 4: Local Processing Pattern

Shows the code-execution-first pattern: fetch data, process locally, return summary.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Configuration
MCPO_BASE_URL="${MCPO_BASE_URL:-http://localhost:8000}"
REPO_PATH="${1:-$(pwd)}"

# Build request for git log
REQUEST_BODY=$(jq -n \
  --arg repo_path "$REPO_PATH" \
  --argjson max_count 1000 \
  '{
    repo_path: $repo_path,
    max_count: $max_count
  }'
)

# Fetch all commits
echo "Analyzing commit history..."
LOGS=$(curl -s -X POST \
  "${MCPO_BASE_URL}/git/git_log" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_BODY")

# Process locally: count commits by author
echo ""
echo "Commits by author:"
echo "$LOGS" | jq -r '.commits[] | .author' | sort | uniq -c | sort -rn

# Process locally: count commits by day of week
echo ""
echo "Commits by day of week:"
echo "$LOGS" | jq -r '.commits[] | .date' | \
  xargs -I {} date -d {} +%A | \
  sort | uniq -c | sort -rn
```

## Example 5: Context7 Library Resolution

Shows working with a different MCP server (context7).

```bash
#!/usr/bin/env bash
set -euo pipefail

# Configuration
MCPO_BASE_URL="${MCPO_BASE_URL:-http://localhost:8000}"

# Parse arguments
LIBRARY_NAME="${1:-}"

if [[ -z "$LIBRARY_NAME" ]]; then
  echo "Usage: $0 <library-name>"
  echo "Example: $0 react"
  exit 1
fi

# Build request
REQUEST_BODY=$(jq -n \
  --arg library "$LIBRARY_NAME" \
  '{
    library: $library
  }'
)

# Make API call
echo "Resolving library: $LIBRARY_NAME"
echo ""

curl -s -X POST \
  "${MCPO_BASE_URL}/context7/resolve_library_id" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_BODY" \
  | jq -r '.'
```

## Script Creation Workflow

1. **Find the tool** in the OpenAPI spec:
   ```bash
   cat servers/git-openapi.json | jq '.paths | keys'
   ```

2. **Check parameters**:
   ```bash
   cat servers/git-openapi.json | jq '.components.schemas.git_status_form_model'
   ```

3. **Copy template**:
   ```bash
   cp scripts/TEMPLATE.sh workspace/my_script.sh
   ```

4. **Modify**:
   - Set `SERVER_NAME`
   - Set `TOOL_NAME`
   - Update argument parsing
   - Build `REQUEST_BODY`
   - Process response

5. **Make executable and run**:
   ```bash
   chmod +x workspace/my_script.sh
   ./workspace/my_script.sh [args]
   ```
