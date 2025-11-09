#!/usr/bin/env bash
#
# List all available tools for an MCP server from its OpenAPI spec
#
# Usage:
#   list_tools.sh <server-name>
#   list_tools.sh git
#   list_tools.sh fetch

set -euo pipefail

# Parse arguments
SERVER_NAME="${1:-}"

if [[ -z "$SERVER_NAME" ]]; then
  echo "Usage: $0 <server-name>"
  echo ""
  echo "Available servers:"
  cat mcp_config.json | jq -r '.mcpServers | keys[]'
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

# List all tools (paths)
echo "Tools available in '${SERVER_NAME}' server:"
echo ""

cat "$OPENAPI_SPEC" | jq -r '.paths | keys[]' | while read -r path; do
  # Get description
  DESCRIPTION=$(cat "$OPENAPI_SPEC" | jq -r ".paths.\"${path}\".post.description // \"No description\"")

  # Remove leading slash from path to get tool name
  TOOL_NAME="${path#/}"

  echo "  $TOOL_NAME"
  echo "    Description: $DESCRIPTION"
  echo ""
done
