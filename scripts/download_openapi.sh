#!/usr/bin/env bash
#
# Download OpenAPI Specifications from MCPO
#
# This script downloads OpenAPI JSON specs from a running MCPO server
# for each MCP server defined in mcp_config.json. The specs are saved
# to servers/{server-name}-openapi.json for use in workspace scripts.
#
# Usage:
#   ./scripts/download_openapi.sh [--config CONFIG] [--port PORT]
#
# Options:
#   --config CONFIG   Path to MCP config file (default: mcp_config.json)
#   --port PORT       MCPO server port (default: 8000)
#

set -euo pipefail

# Default configuration
CONFIG_FILE="${CONFIG_FILE:-mcp_config.json}"
MCPO_PORT="${MCPO_PORT:-8000}"
MCPO_BASE_URL="http://localhost:${MCPO_PORT}"
SERVERS_DIR="servers"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --port)
      MCPO_PORT="$2"
      MCPO_BASE_URL="http://localhost:${MCPO_PORT}"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--config CONFIG] [--port PORT]"
      exit 1
      ;;
  esac
done

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Config file not found: $CONFIG_FILE"
  echo "Please create $CONFIG_FILE or specify a different config with --config"
  exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed"
  echo "Install with: sudo pacman -S jq"
  exit 1
fi

# Check if curl is installed
if ! command -v curl &> /dev/null; then
  echo "Error: curl is required but not installed"
  echo "Install with: sudo pacman -S curl"
  exit 1
fi

# Create servers directory if it doesn't exist
mkdir -p "$SERVERS_DIR"

# Extract server names from config
echo "Reading MCP server names from $CONFIG_FILE..."
SERVER_NAMES=$(jq -r '.mcpServers | keys[]' "$CONFIG_FILE")

if [[ -z "$SERVER_NAMES" ]]; then
  echo "Error: No MCP servers found in $CONFIG_FILE"
  exit 1
fi

echo "Found servers: $(echo $SERVER_NAMES | tr '\n' ' ')"
echo ""

# Download OpenAPI spec for each server
SUCCESS_COUNT=0
FAIL_COUNT=0

for SERVER in $SERVER_NAMES; do
  echo "Downloading OpenAPI spec for '$SERVER'..."

  OPENAPI_URL="${MCPO_BASE_URL}/${SERVER}/openapi.json"
  OUTPUT_FILE="${SERVERS_DIR}/${SERVER}-openapi.json"

  # Try to download the spec
  if curl -sf "$OPENAPI_URL" -o "$OUTPUT_FILE"; then
    # Validate it's valid JSON
    if jq empty "$OUTPUT_FILE" 2>/dev/null; then
      echo "  ✓ Saved to $OUTPUT_FILE"
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
      echo "  ✗ Downloaded file is not valid JSON"
      rm -f "$OUTPUT_FILE"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  else
    echo "  ✗ Failed to download from $OPENAPI_URL"
    echo "    Make sure MCPO is running: ./scripts/run_mcpo.sh"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  echo ""
done

# Summary
echo "========================================="
echo "Download complete!"
echo "  Success: $SUCCESS_COUNT"
echo "  Failed:  $FAIL_COUNT"
echo "========================================="

if [[ $FAIL_COUNT -gt 0 ]]; then
  exit 1
fi

# Generate registry from downloaded specs
if [[ $SUCCESS_COUNT -gt 0 ]]; then
  echo ""
  echo "Generating token-efficient registry..."

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -x "${SCRIPT_DIR}/generate_registry.sh" ]]; then
    "${SCRIPT_DIR}/generate_registry.sh"
  else
    echo "⚠️  Warning: generate_registry.sh not found or not executable"
    echo "   Registry not generated"
  fi
fi
