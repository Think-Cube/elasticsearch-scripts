#!/usr/bin/env bash
# Restore indices from a snapshot.
# Usage: ./restore-snapshot.sh -r REPO -s SNAPSHOT_NAME [-i INDEX_PATTERN]

set -euo pipefail

ES_URL="${ES_URL:-http://localhost:9200}"
ES_USER="${ES_USER:-elastic}"
ES_PASS="${ES_PASS:-}"

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -r  Repository name (required)
  -s  Snapshot name (required)
  -i  Index pattern to restore (default: all indices in snapshot)
  -x  Rename pattern (default: none)          e.g. "logs-(.*)"
  -n  Rename replacement (default: none)      e.g. "restored-logs-\$1"
  -w  Wait for completion (default: false)
  -e  Elasticsearch URL (default: \$ES_URL or http://localhost:9200)
  -h  Show this help

Examples:
  $0 -r s3-backup -s snapshot-2025-08-01-0000
  $0 -r s3-backup -s snapshot-2025-08-01-0000 -i "logs-app-*"
  $0 -r s3-backup -s snapshot-2025-08-01-0000 -x "logs-(.*)" -n "restored-\$1"
EOF
}

REPO_NAME=""
SNAPSHOT_NAME=""
INDEX_PATTERN=""
RENAME_PATTERN=""
RENAME_REPLACEMENT=""
WAIT=false

while getopts ":r:s:i:x:n:we:h" opt; do
  case $opt in
    r) REPO_NAME="$OPTARG" ;;
    s) SNAPSHOT_NAME="$OPTARG" ;;
    i) INDEX_PATTERN="$OPTARG" ;;
    x) RENAME_PATTERN="$OPTARG" ;;
    n) RENAME_REPLACEMENT="$OPTARG" ;;
    w) WAIT=true ;;
    e) ES_URL="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

[ -z "$REPO_NAME" ]     && { echo "Error: -r REPOSITORY is required.";     usage; exit 1; }
[ -z "$SNAPSHOT_NAME" ] && { echo "Error: -s SNAPSHOT_NAME is required."; usage; exit 1; }

AUTH=()
[ -n "$ES_PASS" ] && AUTH=(-u "${ES_USER}:${ES_PASS}")

WAIT_PARAM=""
$WAIT && WAIT_PARAM="?wait_for_completion=true"

BODY="{"
[ -n "$INDEX_PATTERN" ]     && BODY+="\"indices\": \"$INDEX_PATTERN\","
[ -n "$RENAME_PATTERN" ]     && BODY+="\"rename_pattern\": \"$RENAME_PATTERN\","
[ -n "$RENAME_REPLACEMENT" ] && BODY+="\"rename_replacement\": \"$RENAME_REPLACEMENT\","
BODY+="\"include_global_state\": false, \"ignore_unavailable\": true}"

echo "Restoring snapshot: $REPO_NAME/$SNAPSHOT_NAME"
[ -n "$INDEX_PATTERN" ] && echo "Indices: $INDEX_PATTERN"

curl -sk "${AUTH[@]}" -X POST \
  "$ES_URL/_snapshot/$REPO_NAME/$SNAPSHOT_NAME/_restore$WAIT_PARAM" \
  -H "Content-Type: application/json" \
  -d "$BODY" | jq .

echo ""
echo "Recovery status: curl ${ES_URL}/_cat/recovery?v"
