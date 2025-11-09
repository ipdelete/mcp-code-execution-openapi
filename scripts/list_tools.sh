#!/usr/bin/env bash
#
# list_tools.sh - Query the MCP tools registry
#
# This script provides a user-friendly interface to query the registry.json
# file for discovering available MCP tools across all servers.
#
# Usage:
#   ./scripts/list_tools.sh                    # List all servers
#   ./scripts/list_tools.sh --server github    # List tools for a server
#   ./scripts/list_tools.sh --tool get_me      # Find tools by name
#   ./scripts/list_tools.sh --search "user"    # Search tool descriptions
#   ./scripts/list_tools.sh --detail github get_authenticated_user  # Full details
#

set -euo pipefail

#############################################################################
# CONFIGURATION
#############################################################################

REGISTRY_FILE="${REGISTRY_FILE:-registry/registry.json}"

#############################################################################
# HELPER FUNCTIONS
#############################################################################

usage() {
  cat << EOF
Usage: $0 [OPTIONS]

Query the MCP tools registry for tool discovery.

Options:
  (no args)                      List all servers with tool counts
  --server SERVER                List all tools for a specific server
  --tool TOOL_NAME              Find tools matching name across all servers
  --search KEYWORD              Search tool names and descriptions
  --detail SERVER TOOL          Show full details for a specific tool
  --stats                       Show registry statistics
  --help                        Show this help message

Examples:
  $0                                    # List all servers
  $0 --server github                    # List GitHub tools
  $0 --tool get_me                      # Find "get_me" tool
  $0 --search "repository"              # Search for repository-related tools
  $0 --detail github get_authenticated_user  # Full tool details

EOF
  exit 0
}

error() {
  echo "Error: $*" >&2
  exit 1
}

#############################################################################
# VALIDATE PREREQUISITES
#############################################################################

if ! command -v jq &> /dev/null; then
  error "jq is required but not installed"
fi

if [[ ! -f "$REGISTRY_FILE" ]]; then
  error "Registry not found: $REGISTRY_FILE"
  echo ""
  echo "Generate it first:"
  echo "  ./scripts/download_openapi.sh"
  echo "  ./scripts/generate_registry.sh"
  exit 1
fi

#############################################################################
# COMMAND HANDLERS
#############################################################################

list_servers() {
  echo "Available MCP Servers:"
  echo ""

  jq -r '
    .servers | to_entries | sort_by(.key) | .[] |
    "  \(.key) (\(.value.tool_count) tools, \(.value.spec_size))"
  ' "$REGISTRY_FILE"

  echo ""
  echo "Use --server <name> to see tools for a specific server"
}

list_tools_for_server() {
  local server="$1"

  # Check if server exists
  if ! jq -e ".servers.\"$server\"" "$REGISTRY_FILE" > /dev/null 2>&1; then
    error "Server not found: $server"
  fi

  echo "Tools for '$server' server:"
  echo ""

  jq -r --arg server "$server" '
    .servers[$server].tools | to_entries | sort_by(.key) | .[] |
    "  \(.key)\n    \(.value.summary)"
  ' "$REGISTRY_FILE"

  echo ""
  echo "Use --detail $server <tool> for full tool details"
}

find_tool_by_name() {
  local tool_name="$1"

  echo "Searching for tool: $tool_name"
  echo ""

  local results=$(jq -r --arg tool "$tool_name" '
    .servers | to_entries | map(
      select(.value.tools | has($tool)) |
      {
        server: .key,
        tool: $tool,
        summary: .value.tools[$tool].summary
      }
    ) | .[] |
    "  \(.server)/\(.tool)\n    \(.summary)"
  ' "$REGISTRY_FILE")

  if [[ -z "$results" ]]; then
    echo "  No tools found matching: $tool_name"
    echo ""
    echo "Try --search to search descriptions"
  else
    echo "$results"
    echo ""
    echo "Use --detail <server> $tool_name for full details"
  fi
}

search_tools() {
  local keyword="$1"

  echo "Searching for: $keyword"
  echo ""

  local results=$(jq -r --arg keyword "$keyword" '
    .servers | to_entries | map(
      .key as $server |
      .value.tools | to_entries | map(
        select(
          (.key | ascii_downcase | contains($keyword | ascii_downcase)) or
          (.value.summary | ascii_downcase | contains($keyword | ascii_downcase)) or
          (.value.description | ascii_downcase | contains($keyword | ascii_downcase))
        ) |
        {
          server: $server,
          tool: .key,
          summary: .value.summary
        }
      )
    ) | flatten | .[] |
    "  \(.server)/\(.tool)\n    \(.summary)"
  ' "$REGISTRY_FILE")

  if [[ -z "$results" ]]; then
    echo "  No tools found containing: $keyword"
  else
    echo "$results"
    echo ""
    echo "Use --detail <server> <tool> for full details"
  fi
}

show_tool_detail() {
  local server="$1"
  local tool="$2"

  # Check if server and tool exist
  if ! jq -e ".servers.\"$server\"" "$REGISTRY_FILE" > /dev/null 2>&1; then
    error "Server not found: $server"
  fi

  if ! jq -e ".servers.\"$server\".tools.\"$tool\"" "$REGISTRY_FILE" > /dev/null 2>&1; then
    error "Tool not found: $server/$tool"
  fi

  echo "Tool Details: $server/$tool"
  echo "========================================="
  echo ""

  jq -r --arg server "$server" --arg tool "$tool" '
    .servers[$server].tools[$tool] |
    "Summary: \(.summary)\n",
    "Description:\n\(.description)\n",
    "Required Parameters:",
    (if (.required_params | length) > 0 then
      (.required_params | map("  - \(.)") | join("\n"))
    else
      "  (none)"
    end),
    "\nOptional Parameters:",
    (if (.optional_params | length) > 0 then
      (.optional_params | map("  - \(.)") | join("\n"))
    else
      "  (none)"
    end),
    "\nParameter Details:"
  ' "$REGISTRY_FILE"

  jq -r --arg server "$server" --arg tool "$tool" '
    .servers[$server].tools[$tool].params | to_entries | .[] |
    "  \(.key):",
    "    Type: \(.value.type)",
    (if .value.title then "    Title: \(.value.title)" else empty end)
  ' "$REGISTRY_FILE"

  echo ""
  echo "Endpoint:"
  echo "  POST http://localhost:8000/$server/$tool"
  echo ""
  echo "To create a script:"
  echo "  cp scripts/TEMPLATE.sh workspace/${tool}.sh"
  echo "  # Edit SERVER_NAME=\"$server\" and TOOL_NAME=\"$tool\""
}

show_stats() {
  echo "Registry Statistics:"
  echo ""

  jq -r '
    "Generated: \(.generated_at)",
    "Total Servers: \(.servers | length)",
    "Total Tools: \(.servers | map(.tool_count) | add)",
    "",
    "Tools by Server:",
    (.servers | to_entries | sort_by(.key) | .[] |
     "  \(.key): \(.value.tool_count) tools")
  ' "$REGISTRY_FILE"
}

#############################################################################
# MAIN
#############################################################################

# Parse arguments
if [[ $# -eq 0 ]]; then
  list_servers
  exit 0
fi

case "$1" in
  --help|-h)
    usage
    ;;
  --server)
    if [[ $# -lt 2 ]]; then
      error "Missing server name. Usage: $0 --server <server_name>"
    fi
    list_tools_for_server "$2"
    ;;
  --tool)
    if [[ $# -lt 2 ]]; then
      error "Missing tool name. Usage: $0 --tool <tool_name>"
    fi
    find_tool_by_name "$2"
    ;;
  --search)
    if [[ $# -lt 2 ]]; then
      error "Missing search keyword. Usage: $0 --search <keyword>"
    fi
    search_tools "$2"
    ;;
  --detail)
    if [[ $# -lt 3 ]]; then
      error "Missing arguments. Usage: $0 --detail <server> <tool>"
    fi
    show_tool_detail "$2" "$3"
    ;;
  --stats)
    show_stats
    ;;
  *)
    error "Unknown option: $1. Use --help for usage information"
    ;;
esac
