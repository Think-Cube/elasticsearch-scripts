#!/usr/bin/env bash
# Register an S3 snapshot repository.
# Requires elasticsearch-repository-s3 plugin (bundled in ES 9.x).
# AWS credentials are read from keystore or environment variables.

set -euo pipefail

ES_URL="${ES_URL:-http://localhost:9200}"
ES_USER="${ES_USER:-elastic}"
ES_PASS="${ES_PASS:-}"

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -r  Repository name (required)
  -b  S3 bucket name (required)
  -p  S3 bucket prefix (default: elasticsearch-snapshots)
  -g  AWS region (default: eu-west-1)
  -e  Elasticsearch URL (default: \$ES_URL or http://localhost:9200)
  -h  Show this help

Prerequisites — add credentials to ES keystore before running:
  bin/elasticsearch-keystore add s3.client.default.access_key
  bin/elasticsearch-keystore add s3.client.default.secret_key
  POST /_nodes/reload_secure_settings
EOF
}

REPO_NAME=""
BUCKET=""
PREFIX="elasticsearch-snapshots"
REGION="eu-west-1"

while getopts ":r:b:p:g:e:h" opt; do
  case $opt in
    r) REPO_NAME="$OPTARG" ;;
    b) BUCKET="$OPTARG" ;;
    p) PREFIX="$OPTARG" ;;
    g) REGION="$OPTARG" ;;
    e) ES_URL="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

[ -z "$REPO_NAME" ] && { echo "Error: -r REPOSITORY_NAME is required."; usage; exit 1; }
[ -z "$BUCKET" ]    && { echo "Error: -b BUCKET is required.";          usage; exit 1; }

AUTH=()
[ -n "$ES_PASS" ] && AUTH=(-u "${ES_USER}:${ES_PASS}")

echo "Registering S3 snapshot repository: $REPO_NAME (bucket: $BUCKET/$PREFIX)"
curl -sk "${AUTH[@]}" -X PUT "$ES_URL/_snapshot/$REPO_NAME" \
  -H "Content-Type: application/json" \
  -d "{
    \"type\": \"s3\",
    \"settings\": {
      \"bucket\":  \"$BUCKET\",
      \"base_path\": \"$PREFIX\",
      \"region\":  \"$REGION\",
      \"compress\": true
    }
  }" | jq .

echo ""
echo "Verify: curl ${ES_URL}/_snapshot/${REPO_NAME}"
