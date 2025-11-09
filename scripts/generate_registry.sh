#!/usr/bin/env bash
#
# generate_registry.sh - Create a token-efficient registry of MCP tools
#
# This script extracts metadata from all OpenAPI specs in servers/ and
# generates a compact registry.json file for quick tool discovery.
#
# Benefits:
#   - ~90% token reduction vs loading full OpenAPI specs
#   - Quick tool discovery across all servers
#   - Progressive disclosure pattern (load full spec only when needed)
#
# Usage:
#   ./scripts/generate_registry.sh
#   ./scripts/generate_registry.sh registry/custom-registry.json
#

set -euo pipefail

#############################################################################
# CONFIGURATION
#############################################################################

SERVERS_DIR="${SERVERS_DIR:-servers}"
REGISTRY_DIR="${REGISTRY_DIR:-registry}"
OUTPUT_FILE="${1:-${REGISTRY_DIR}/registry.json}"

#############################################################################
# HELPER FUNCTIONS
#############################################################################

log() {
  echo "[registry] $*" >&2
}

error() {
  echo "[registry] ERROR: $*" >&2
  exit 1
}

#############################################################################
# VALIDATE PREREQUISITES
#############################################################################

# Check required tools
if ! command -v jq &> /dev/null; then
  error "jq is required but not installed"
fi

# Check if servers directory exists
if [[ ! -d "$SERVERS_DIR" ]]; then
  error "Servers directory not found: $SERVERS_DIR"
fi

# Count OpenAPI specs
SPEC_COUNT=$(find "$SERVERS_DIR" -name "*-openapi.json" -type f | wc -l | tr -d ' ')

if [[ "$SPEC_COUNT" -eq 0 ]]; then
  log "No OpenAPI specs found in $SERVERS_DIR"
  log "Run ./scripts/download_openapi.sh first"
  error "No specs to process"
fi

log "Found $SPEC_COUNT OpenAPI spec(s) to process"

#############################################################################
# GENERATE REGISTRY
#############################################################################

# Start building the registry JSON
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Initialize registry with metadata
REGISTRY=$(jq -n \
  --arg timestamp "$TIMESTAMP" \
  --arg servers_dir "$SERVERS_DIR" \
  '{
    _comment: "DO NOT READ THIS FILE DIRECTLY. Use ./scripts/list_tools.sh as the interface.",
    _usage: "Run: ./scripts/list_tools.sh --help",
    generated_at: $timestamp,
    servers_dir: $servers_dir,
    servers: {}
  }')

# Process each OpenAPI spec
for SPEC_FILE in "$SERVERS_DIR"/*-openapi.json; do
  if [[ ! -f "$SPEC_FILE" ]]; then
    continue
  fi

  FILENAME=$(basename "$SPEC_FILE")
  SERVER_NAME="${FILENAME%-openapi.json}"

  log "Processing $SERVER_NAME ($FILENAME)..."

  # Validate JSON
  if ! jq empty "$SPEC_FILE" 2>/dev/null; then
    log "  ⚠️  Skipping invalid JSON: $FILENAME"
    continue
  fi

  # Get file size
  if [[ "$(uname)" == "Darwin" ]]; then
    # macOS
    FILE_SIZE=$(stat -f%z "$SPEC_FILE")
  else
    # Linux
    FILE_SIZE=$(stat -c%s "$SPEC_FILE")
  fi

  # Convert to human readable (K/M)
  if [[ $FILE_SIZE -gt 1048576 ]]; then
    SIZE_DISPLAY="$(( FILE_SIZE / 1048576 ))M"
  elif [[ $FILE_SIZE -gt 1024 ]]; then
    SIZE_DISPLAY="$(( FILE_SIZE / 1024 ))K"
  else
    SIZE_DISPLAY="${FILE_SIZE}B"
  fi

  # Extract tool information
  TOOLS_JSON=$(jq -r '
    .paths // {} | to_entries | map({
      key: (.key | ltrimstr("/")),
      value: {
        summary: (.value.post.summary // ""),
        description: (.value.post.description // ""),
        schema_ref: (
          .value.post.requestBody.content."application/json".schema."$ref" // ""
        )
      }
    }) | from_entries
  ' "$SPEC_FILE")

  # Extract parameter information for each tool
  # NOTE: We only include param types, not descriptions, to save tokens
  # Full descriptions are available in the OpenAPI spec files
  TOOLS_WITH_PARAMS=$(echo "$TOOLS_JSON" | jq --slurpfile spec "$SPEC_FILE" '
    to_entries | map(
      .key as $tool_name |
      .value.schema_ref as $ref |
      ($ref | ltrimstr("#/components/schemas/")) as $schema_name |
      {
        key: $tool_name,
        value: (.value + {
          required_params: (
            if $schema_name != "" and $schema_name != null then
              ($spec[0].components.schemas[$schema_name].required // [])
            else
              []
            end
          ),
          optional_params: (
            if $schema_name != "" and $schema_name != null then
              ($spec[0].components.schemas[$schema_name].properties // {} |
               keys | map(select(. as $k |
                 ($spec[0].components.schemas[$schema_name].required // []) |
                 contains([$k]) | not
               ))
              )
            else
              []
            end
          ),
          params: (
            if $schema_name != "" and $schema_name != null then
              # Only include param name and type (not full description)
              ($spec[0].components.schemas[$schema_name].properties // {} |
               to_entries | map({
                 key: .key,
                 value: {
                   type: .value.type,
                   title: .value.title
                 }
               }) | from_entries
              )
            else
              {}
            end
          )
        })
      }
    ) | from_entries
  ')

  TOOL_COUNT=$(echo "$TOOLS_WITH_PARAMS" | jq 'length')

  log "  ✓ Extracted $TOOL_COUNT tools"

  # Add server to registry
  REGISTRY=$(echo "$REGISTRY" | jq \
    --arg server "$SERVER_NAME" \
    --arg spec_file "$FILENAME" \
    --arg spec_size "$SIZE_DISPLAY" \
    --argjson tool_count "$TOOL_COUNT" \
    --argjson tools "$TOOLS_WITH_PARAMS" \
    '.servers[$server] = {
      spec_file: $spec_file,
      spec_size: $spec_size,
      tool_count: $tool_count,
      tools: $tools
    }')
done

#############################################################################
# WRITE OUTPUT
#############################################################################

# Create output directory if needed
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
mkdir -p "$OUTPUT_DIR"

# Write pretty-printed JSON
echo "$REGISTRY" | jq '.' > "$OUTPUT_FILE"

# Calculate size savings
TOTAL_SPEC_SIZE=0
for SPEC_FILE in "$SERVERS_DIR"/*-openapi.json; do
  if [[ -f "$SPEC_FILE" ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
      SIZE=$(stat -f%z "$SPEC_FILE")
    else
      SIZE=$(stat -c%s "$SPEC_FILE")
    fi
    TOTAL_SPEC_SIZE=$((TOTAL_SPEC_SIZE + SIZE))
  fi
done

if [[ "$(uname)" == "Darwin" ]]; then
  REGISTRY_SIZE=$(stat -f%z "$OUTPUT_FILE")
else
  REGISTRY_SIZE=$(stat -c%s "$OUTPUT_FILE")
fi

SAVINGS_PERCENT=$(( (TOTAL_SPEC_SIZE - REGISTRY_SIZE) * 100 / TOTAL_SPEC_SIZE ))

log ""
log "✓ Registry generated successfully"
log "  Output: $OUTPUT_FILE"
log "  Total spec size: $(( TOTAL_SPEC_SIZE / 1024 ))K"
log "  Registry size: $(( REGISTRY_SIZE / 1024 ))K"
log "  Token savings: ~${SAVINGS_PERCENT}%"
log ""
log "Usage:"
log "  # Interactive browsing"
log "  ./scripts/list_tools.sh"
log ""
log "  # Direct queries"
log "  cat $OUTPUT_FILE | jq '.servers | keys'"
log "  cat $OUTPUT_FILE | jq '.servers.github.tools | keys'"
