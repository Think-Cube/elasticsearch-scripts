#!/usr/bin/env bash
# Apply an ILM policy to an existing index or index template.
# Usage: ./apply-ilm-to-index.sh -i INDEX_PATTERN -p POLICY_NAME

set -euo pipefail

ES_URL="${ES_URL:-http://localhost:9200}"
ES_USER="${ES_USER:-elastic}"
ES_PASS="${ES_PASS:-}"

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -i  Index name or pattern (required)  e.g. logs-app or logs-*
  -p  ILM policy name (required)
  -t  Apply to index template instead of index directly
  -e  Elasticsearch URL (default: \$ES_URL or http://localhost:9200)
  -h  Show this help
EOF
}

INDEX=""
POLICY_NAME=""
USE_TEMPLATE=false

while getopts ":i:p:te:h" opt; do
  case $opt in
    i) INDEX="$OPTARG" ;;
    p) POLICY_NAME="$OPTARG" ;;
    t) USE_TEMPLATE=true ;;
    e) ES_URL="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

[ -z "$INDEX" ]       && { echo "Error: -i INDEX is required.";       usage; exit 1; }
[ -z "$POLICY_NAME" ] && { echo "Error: -p POLICY_NAME is required."; usage; exit 1; }

AUTH=()
[ -n "$ES_PASS" ] && AUTH=(-u "${ES_USER}:${ES_PASS}")

if $USE_TEMPLATE; then
  echo "Applying ILM policy '$POLICY_NAME' to index template '$INDEX'..."
  curl -sk "${AUTH[@]}" -X PUT "$ES_URL/_index_template/$INDEX" \
    -H "Content-Type: application/json" \
    -d "{
      \"index_patterns\": [\"${INDEX}-*\"],
      \"template\": {
        \"settings\": {
          \"index.lifecycle.name\": \"$POLICY_NAME\",
          \"index.lifecycle.rollover_alias\": \"$INDEX\"
        }
      }
    }" | jq .
else
  echo "Applying ILM policy '$POLICY_NAME' to index '$INDEX'..."
  curl -sk "${AUTH[@]}" -X PUT "$ES_URL/$INDEX/_settings" \
    -H "Content-Type: application/json" \
    -d "{\"index.lifecycle.name\": \"$POLICY_NAME\"}" | jq .
fi

echo ""
echo "ILM status: curl ${ES_URL}/${INDEX}/_ilm/explain"
