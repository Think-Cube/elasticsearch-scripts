#!/usr/bin/env bash
# Register an Azure Blob Storage snapshot repository.
# Requires repository-azure plugin (bundled in ES 9.x).

set -euo pipefail

ES_URL="${ES_URL:-http://localhost:9200}"
ES_USER="${ES_USER:-elastic}"
ES_PASS="${ES_PASS:-}"

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -r  Repository name (required)
  -c  Azure storage container name (required)
  -p  Blob prefix (default: elasticsearch-snapshots)
  -a  Azure storage account client name (default: default)
  -e  Elasticsearch URL (default: \$ES_URL or http://localhost:9200)
  -h  Show this help

Prerequisites — add credentials to ES keystore before running:
  bin/elasticsearch-keystore add azure.client.default.account
  bin/elasticsearch-keystore add azure.client.default.key
  POST /_nodes/reload_secure_settings
EOF
}

REPO_NAME=""
CONTAINER=""
PREFIX="elasticsearch-snapshots"
CLIENT="default"

while getopts ":r:c:p:a:e:h" opt; do
  case $opt in
    r) REPO_NAME="$OPTARG" ;;
    c) CONTAINER="$OPTARG" ;;
    p) PREFIX="$OPTARG" ;;
    a) CLIENT="$OPTARG" ;;
    e) ES_URL="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

[ -z "$REPO_NAME" ]  && { echo "Error: -r REPOSITORY_NAME is required."; usage; exit 1; }
[ -z "$CONTAINER" ]  && { echo "Error: -c CONTAINER is required.";        usage; exit 1; }

AUTH=()
[ -n "$ES_PASS" ] && AUTH=(-u "${ES_USER}:${ES_PASS}")

echo "Registering Azure snapshot repository: $REPO_NAME (container: $CONTAINER/$PREFIX)"
curl -sk "${AUTH[@]}" -X PUT "$ES_URL/_snapshot/$REPO_NAME" \
  -H "Content-Type: application/json" \
  -d "{
    \"type\": \"azure\",
    \"settings\": {
      \"client\":    \"$CLIENT\",
      \"container\": \"$CONTAINER\",
      \"base_path\": \"$PREFIX\",
      \"compress\":  true
    }
  }" | jq .

echo ""
echo "Verify: curl ${ES_URL}/_snapshot/${REPO_NAME}"
