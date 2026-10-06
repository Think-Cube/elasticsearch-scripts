#!/usr/bin/env bash
# Create a snapshot of all indices or a specific index pattern.
# Usage: ./create-snapshot.sh -r REPO -s SNAPSHOT_NAME [-i INDEX_PATTERN]

set -euo pipefail

ES_URL="${ES_URL:-http://localhost:9200}"
ES_USER="${ES_USER:-elastic}"
ES_PASS="${ES_PASS:-}"

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -r  Repository name (required)
  -s  Snapshot name (default: snapshot-YYYY-MM-DD-HHmm)
  -i  Index pattern to snapshot (default: all indices)
  -w  Wait for completion (default: false — runs async)
  -e  Elasticsearch URL (default: \$ES_URL or http://localhost:9200)
  -h  Show this help

Examples:
  $0 -r s3-backup
  $0 -r s3-backup -i "logs-*"
  $0 -r s3-backup -s nightly-$(date +%F) -w
EOF
}

REPO_NAME=""
SNAPSHOT_NAME="snapshot-$(date +%Y-%m-%d-%H%M)"
INDEX_PATTERN=""
WAIT=false

while getopts ":r:s:i:we:h" opt; do
  case $opt in
    r) REPO_NAME="$OPTARG" ;;
    s) SNAPSHOT_NAME="$OPTARG" ;;
    i) INDEX_PATTERN="$OPTARG" ;;
    w) WAIT=true ;;
    e) ES_URL="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

[ -z "$REPO_NAME" ] && { echo "Error: -r REPOSITORY is required."; usage; exit 1; }

AUTH=()
[ -n "$ES_PASS" ] && AUTH=(-u "${ES_USER}:${ES_PASS}")

WAIT_PARAM=""
$WAIT && WAIT_PARAM="?wait_for_completion=true"

if [ -n "$INDEX_PATTERN" ]; then
  BODY="{\"indices\": \"$INDEX_PATTERN\", \"include_global_state\": false}"
else
  BODY='{"include_global_state": true}'
fi

echo "Creating snapshot: $REPO_NAME/$SNAPSHOT_NAME"
[ -n "$INDEX_PATTERN" ] && echo "Indices: $INDEX_PATTERN"

curl -sk "${AUTH[@]}" -X PUT "$ES_URL/_snapshot/$REPO_NAME/$SNAPSHOT_NAME$WAIT_PARAM" \
  -H "Content-Type: application/json" \
  -d "$BODY" | jq .

echo ""
if ! $WAIT; then
  echo "Snapshot running asynchronously."
  echo "Check status: curl ${ES_URL}/_snapshot/${REPO_NAME}/${SNAPSHOT_NAME}"
fi
