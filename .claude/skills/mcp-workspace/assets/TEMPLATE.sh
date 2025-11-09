#!/usr/bin/env bash
#
# TEMPLATE: Bash Script for MCPO Tool
#
# This template shows the pattern for creating workspace scripts
# that call MCP tools via the MCPO HTTP API using curl and jq.
#
# Copy this template and modify for your specific tool.
#
# Convention-Based Configuration:
#   - OpenAPI specs: servers/{server-name}-openapi.json
#   - MCPO base URL: http://localhost:8000 (via MCPO_BASE_URL env var)
#   - Endpoint pattern: POST {base_url}/{server_name}/{tool_name}
#   - Request: JSON body (use jq to construct)
#   - Response: JSON (use jq to parse)

set -euo pipefail

#############################################################################
# CONFIGURATION
#############################################################################

# MCPO server configuration
MCPO_BASE_URL="${MCPO_BASE_URL:-http://localhost:8000}"

# MCP server name (e.g., "git", "fetch", "context7")
SERVER_NAME="git"

# Tool name (e.g., "git_status", "git_diff", "git_log")
# Find available tools in servers/{server-name}-openapi.json under "paths"
TOOL_NAME="git_status"

# OpenAPI spec location (for reference/documentation)
OPENAPI_SPEC="servers/${SERVER_NAME}-openapi.json"

#############################################################################
# PARSE ARGUMENTS
#############################################################################

# Example: Parse command line arguments
# Modify this section based on the tool's required parameters
# Check the OpenAPI spec for required/optional parameters

REPO_PATH="${1:-$(pwd)}"

# You can add more parameters as needed:
# PARAM2="${2:-default_value}"
# PARAM3="${3:-}"

#############################################################################
# BUILD REQUEST BODY
#############################################################################

# Use jq to construct the JSON request body
# Check the OpenAPI spec under "components.schemas.{tool_name}_form_model"
# to see what parameters are required and their types

REQUEST_BODY=$(jq -n \
  --arg repo_path "$REPO_PATH" \
  '{
    repo_path: $repo_path
  }'
)

# For more complex request bodies:
# REQUEST_BODY=$(jq -n \
#   --arg param1 "$PARAM1" \
#   --arg param2 "$PARAM2" \
#   --argjson param3 "$PARAM3" \
#   '{
#     param1: $param1,
#     param2: $param2,
#     param3: $param3
#   }'
# )

#############################################################################
# MAKE API CALL
#############################################################################

# Construct the endpoint URL
ENDPOINT_URL="${MCPO_BASE_URL}/${SERVER_NAME}/${TOOL_NAME}"

# Make the HTTP POST request
echo "Calling ${SERVER_NAME}/${TOOL_NAME}..."
echo ""

RESPONSE=$(curl -sf \
  -X POST \
  "$ENDPOINT_URL" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_BODY")

# Check if curl succeeded
if [[ $? -ne 0 ]]; then
  echo "Error: Failed to call API at $ENDPOINT_URL"
  echo "Make sure MCPO is running: ./scripts/run_mcpo.sh"
  exit 1
fi

#############################################################################
# PROCESS RESPONSE
#############################################################################

# The response format depends on the MCP tool
# Common patterns:
#   - Plain text: Use jq -r '.'
#   - JSON object: Use jq for further processing
#   - Array: Use jq to filter/transform

# Example 1: Print raw response
echo "$RESPONSE" | jq -r '.'

# Example 2: Extract specific field
# echo "$RESPONSE" | jq -r '.field_name'

# Example 3: Process locally before returning
# This is the "code-execution-first" pattern - do processing
# in the script rather than returning raw data to the LLM
# PROCESSED=$(echo "$RESPONSE" | jq -r '.items | length')
# echo "Total items: $PROCESSED"

#############################################################################
# HOW TO USE THIS TEMPLATE
#############################################################################
#
# 1. Download OpenAPI specs:
#    ./scripts/download_openapi.sh
#
# 2. Find your tool in the spec:
#    cat servers/{server-name}-openapi.json | jq '.paths'
#
# 3. Check required parameters:
#    cat servers/{server-name}-openapi.json | jq '.components.schemas.{tool_name}_form_model'
#
# 4. Copy this template:
#    cp scripts/TEMPLATE.sh workspace/my_tool.sh
#
# 5. Modify:
#    - SERVER_NAME
#    - TOOL_NAME
#    - Argument parsing
#    - REQUEST_BODY construction
#    - Response processing
#
# 6. Make executable:
#    chmod +x workspace/my_tool.sh
#
# 7. Run:
#    ./workspace/my_tool.sh [arguments]
#
#############################################################################
