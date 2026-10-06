#!/usr/bin/env bash
# Delete indices matching a pattern that are older than N days.
# WARNING: This is irreversible. Use ILM delete phase or snapshots before running.

set -euo pipefail

ES_URL="${ES_URL:-http://localhost:9200}"
ES_USER="${ES_USER:-elastic}"
ES_PASS="${ES_PASS:-}"

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -p  Index pattern prefix (required)  e.g. logs-app
  -d  Delete indices older than N days (required)
  -n  Dry run (strongly recommended before first use)
  -e  Elasticsearch URL (default: \$ES_URL or http://localhost:9200)
  -h  Show this help

Notes:
  Indices must follow date suffix format: PREFIX-YYYY.MM.DD or PREFIX-YYYY-MM-DD
  Consider using ILM policies instead for automated lifecycle management.
  Always take a snapshot before bulk deletion.

Example:
  $0 -p logs-app -d 90 -n   # dry run first
  $0 -p logs-app -d 90
EOF
}

PATTERN=""
DAYS=""
DRY_RUN=false

while getopts ":p:d:ne:h" opt; do
  case $opt in
    p) PATTERN="$OPTARG" ;;
    d) DAYS="$OPTARG" ;;
    n) DRY_RUN=true ;;
    e) ES_URL="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

[ -z "$PATTERN" ] && { echo "Error: -p PATTERN is required."; usage; exit 1; }
[ -z "$DAYS" ]    && { echo "Error: -d DAYS is required.";    usage; exit 1; }

AUTH=()
[ -n "$ES_PASS" ] && AUTH=(-u "${ES_USER}:${ES_PASS}")

CUTOFF=$(date -d "$DAYS days ago" +%Y.%m.%d 2>/dev/null || date -v-${DAYS}d +%Y.%m.%d)

echo "Pattern: ${PATTERN}-*  |  Deleting indices with date < $CUTOFF"
$DRY_RUN && echo "[DRY RUN — nothing will be deleted]"
echo ""

INDICES=$(curl -sk "${AUTH[@]}" "$ES_URL/_cat/indices/${PATTERN}-*?h=index" | \
  grep -E "${PATTERN}-[0-9]{4}[.\-][0-9]{2}[.\-][0-9]{2}" || true)

if [ -z "$INDICES" ]; then
  echo "No matching indices found."
  exit 0
fi

DELETED=0
while IFS= read -r index; do
  date_part=$(echo "$index" | grep -oE '[0-9]{4}[.\-][0-9]{2}[.\-][0-9]{2}' | tr '-' '.')
  if [[ "$date_part" < "$CUTOFF" ]]; then
    if $DRY_RUN; then
      echo "Would delete: $index"
    else
      echo -n "Deleting: $index ... "
      result=$(curl -sk "${AUTH[@]}" -X DELETE "$ES_URL/$index" | jq -r '.acknowledged')
      echo "$result"
      DELETED=$((DELETED + 1))
    fi
  fi
done <<< "$INDICES"

if ! $DRY_RUN; then
  echo ""
  echo "Deleted $DELETED indices."
fi
