#!/usr/bin/env bash
# Close indices matching a pattern that are older than N days.
# For use when ILM is not available or for manual lifecycle management.

set -euo pipefail

ES_URL="${ES_URL:-http://localhost:9200}"
ES_USER="${ES_USER:-elastic}"
ES_PASS="${ES_PASS:-}"

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -p  Index pattern prefix (required)  e.g. logs-app
  -d  Close indices older than N days (required)
  -n  Dry run
  -e  Elasticsearch URL (default: \$ES_URL or http://localhost:9200)
  -h  Show this help

Notes:
  Indices must follow date suffix format: PREFIX-YYYY.MM.DD or PREFIX-YYYY-MM-DD
  Consider using ILM policies instead for automated lifecycle management.

Example:
  $0 -p logs-app -d 30
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

echo "Pattern: ${PATTERN}-*  |  Closing indices with date < $CUTOFF"
$DRY_RUN && echo "[DRY RUN]"
echo ""

INDICES=$(curl -sk "${AUTH[@]}" "$ES_URL/_cat/indices/${PATTERN}-*?h=index,status" | \
  awk '{print $1}' | grep -E "${PATTERN}-[0-9]{4}[.\-][0-9]{2}[.\-][0-9]{2}" || true)

if [ -z "$INDICES" ]; then
  echo "No matching indices found."
  exit 0
fi

while IFS= read -r index; do
  date_part=$(echo "$index" | grep -oE '[0-9]{4}[.\-][0-9]{2}[.\-][0-9]{2}' | tr '-' '.')
  if [[ "$date_part" < "$CUTOFF" ]]; then
    if $DRY_RUN; then
      echo "Would close: $index"
    else
      echo -n "Closing: $index ... "
      curl -sk "${AUTH[@]}" -X POST "$ES_URL/$index/_close" | jq -r '.acknowledged'
    fi
  fi
done <<< "$INDICES"
