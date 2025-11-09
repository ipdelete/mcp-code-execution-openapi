#!/usr/bin/env bash
#
# Run the mcpo (MCP-to-OpenAPI) server.
#
# This script starts the mcpo server which exposes MCP servers as HTTP endpoints
# with automatically generated OpenAPI specifications.
#
# The mcpo server acts as a proxy, converting MCP protocol calls into REST API
# endpoints that can be called from any HTTP client.
#
# Usage:
#   ./scripts/run_mcpo.sh
#   ./scripts/run_mcpo.sh --config custom_config.json
#   ./scripts/run_mcpo.sh --port 8080
#   ./scripts/run_mcpo.sh --host 127.0.0.1

set -euo pipefail

# Default configuration
CONFIG_PATH="${CONFIG_PATH:-mcp_config.json}"
PORT="${PORT:-8000}"
HOST="${HOST:-0.0.0.0}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --config)
      CONFIG_PATH="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --host)
      HOST="$2"
      shift 2
      ;;
    --help|-h)
      cat << EOF
Run the mcpo (MCP-to-OpenAPI) server

Usage:
  $0 [options]

Options:
  --config PATH    Path to MCP configuration file (default: mcp_config.json)
  --port PORT      Port to run the server on (default: 8000)
  --host HOST      Host to bind to (default: 0.0.0.0)
  --help, -h       Show this help message

Examples:
  # Run with default settings
  $0

  # Run on a different port
  $0 --port 8080

  # Use a custom config file
  $0 --config my_mcp_config.json

  # Bind to specific host
  $0 --host 127.0.0.1
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Check if config file exists
if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "❌ Error: Configuration file not found: $CONFIG_PATH" >&2
  echo "   Please create $CONFIG_PATH or use --config to specify a different file" >&2
  exit 1
fi

# Check if jq is installed (for parsing config)
if ! command -v jq &> /dev/null; then
  echo "⚠️  Warning: jq not installed, skipping config validation" >&2
  echo "   Install with: sudo pacman -S jq" >&2
  echo "" >&2
else
  # Parse and display server info
  SERVERS=$(jq -r '.mcpServers | keys | join(", ")' "$CONFIG_PATH" 2>/dev/null || echo "unknown")
  SERVER_COUNT=$(jq -r '.mcpServers | keys | length' "$CONFIG_PATH" 2>/dev/null || echo "?")
fi

# Display startup information
echo "=========================================================="
echo "🚀 Starting MCPO Server"
echo "=========================================================="
echo ""
echo "📋 Configuration:"
echo "   Config file: $CONFIG_PATH"
if [[ -n "${SERVERS:-}" ]]; then
  echo "   MCP Servers: $SERVERS ($SERVER_COUNT total)"
fi
echo ""
echo "🌐 Server settings:"
echo "   Host: $HOST"
echo "   Port: $PORT"
if [[ "$HOST" == "0.0.0.0" ]]; then
  echo "   URL: http://localhost:$PORT"
else
  echo "   URL: http://$HOST:$PORT"
fi
echo ""
echo "📖 Available endpoints:"
if [[ "$HOST" == "0.0.0.0" ]]; then
  echo "   Swagger UI:  http://localhost:$PORT/docs"
  echo "   ReDoc:       http://localhost:$PORT/redoc"
  echo "   OpenAPI:     http://localhost:$PORT/openapi.json"
else
  echo "   Swagger UI:  http://$HOST:$PORT/docs"
  echo "   ReDoc:       http://$HOST:$PORT/redoc"
  echo "   OpenAPI:     http://$HOST:$PORT/openapi.json"
fi
echo ""
echo "=========================================================="
echo ""
echo "💡 Tip: Use Ctrl+C to stop the server"
echo ""

# Build command
CMD="uvx mcpo --config $CONFIG_PATH --port $PORT"
if [[ "$HOST" != "0.0.0.0" ]]; then
  CMD="$CMD --host $HOST"
fi

echo "🔧 Command: $CMD"
echo ""
echo "=========================================================="
echo ""

# Run mcpo server (foreground)
# shellcheck disable=SC2086
exec $CMD
