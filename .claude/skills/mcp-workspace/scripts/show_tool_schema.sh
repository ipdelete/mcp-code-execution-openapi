#!/usr/bin/env bash
#
# Show the parameter schema for a specific MCP tool
#
# Usage:
#   show_tool_schema.sh <server-name> <tool-name>
#   show_tool_schema.sh git git_status
#   show_tool_schema.sh fetch fetch

set -euo pipefail

# Parse arguments
SERVER_NAME="${1:-}"
TOOL_NAME="${2:-}"

if [[ -z "$SERVER_NAME" ]] || [[ -z "$TOOL_NAME" ]]; then
  echo "Usage: $0 <server-name> <tool-name>"
  echo ""
  echo "Example: $0 git git_status"
  exit 1
fi

# Find OpenAPI spec
OPENAPI_SPEC="servers/${SERVER_NAME}-openapi.json"

if [[ ! -f "$OPENAPI_SPEC" ]]; then
  echo "Error: OpenAPI spec not found: $OPENAPI_SPEC"
  echo ""
  echo "Run: ./scripts/download_openapi.sh"
  exit 1
fi

# Get tool path
TOOL_PATH="/${TOOL_NAME}"

# Check if tool exists
if ! cat "$OPENAPI_SPEC" | jq -e ".paths.\"${TOOL_PATH}\"" > /dev/null 2>&1; then
  echo "Error: Tool '${TOOL_NAME}' not found in '${SERVER_NAME}' server"
  echo ""
  echo "Available tools:"
  cat "$OPENAPI_SPEC" | jq -r '.paths | keys[]'
  exit 1
fi

# Get description
DESCRIPTION=$(cat "$OPENAPI_SPEC" | jq -r ".paths.\"${TOOL_PATH}\".post.description // \"No description\"")

# Get schema name
SCHEMA_NAME="${TOOL_NAME}_form_model"

echo "Tool: ${SERVER_NAME}/${TOOL_NAME}"
echo "Description: $DESCRIPTION"
echo ""
echo "Endpoint: POST http://localhost:8000/${SERVER_NAME}/${TOOL_NAME}"
echo ""
echo "Parameters:"
cat "$OPENAPI_SPEC" | jq ".components.schemas.${SCHEMA_NAME}"
