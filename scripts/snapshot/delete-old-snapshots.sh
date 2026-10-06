#!/usr/bin/env bash
# Delete snapshots older than N days from a repository.
# Usage: ./delete-old-snapshots.sh -r REPO -d 30

set -euo pipefail

ES_URL="${ES_URL:-http://localhost:9200}"
ES_USER="${ES_USER:-elastic}"
ES_PASS="${ES_PASS:-}"

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -r  Repository name (required)
  -d  Delete snapshots older than N days (required)
  -n  Dry run — print what would be deleted without deleting
  -e  Elasticsearch URL (default: \$ES_URL or http://localhost:9200)
  -h  Show this help

Example:
  $0 -r s3-backup -d 90
  $0 -r s3-backup -d 90 -n
EOF
}

REPO_NAME=""
DAYS=""
DRY_RUN=false

while getopts ":r:d:ne:h" opt; do
  case $opt in
    r) REPO_NAME="$OPTARG" ;;
    d) DAYS="$OPTARG" ;;
    n) DRY_RUN=true ;;
    e) ES_URL="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

[ -z "$REPO_NAME" ] && { echo "Error: -r REPOSITORY is required."; usage; exit 1; }
[ -z "$DAYS" ]      && { echo "Error: -d DAYS is required.";        usage; exit 1; }

AUTH=()
[ -n "$ES_PASS" ] && AUTH=(-u "${ES_USER}:${ES_PASS}")

CUTOFF=$(date -d "$DAYS days ago" +%s 2>/dev/null || date -v-${DAYS}d +%s)
CUTOFF_MS=$((CUTOFF * 1000))

echo "Repository:  $REPO_NAME"
echo "Deleting snapshots older than $DAYS days (before $(date -d @$CUTOFF 2>/dev/null || date -r $CUTOFF))"
$DRY_RUN && echo "[DRY RUN — no deletions will be performed]"
echo ""

SNAPSHOTS=$(curl -sk "${AUTH[@]}" "$ES_URL/_snapshot/$REPO_NAME/_all" | \
  jq -r ".snapshots[] | select(.start_time_in_millis < $CUTOFF_MS) | .snapshot")

if [ -z "$SNAPSHOTS" ]; then
  echo "No snapshots older than $DAYS days found."
  exit 0
fi

for snap in $SNAPSHOTS; do
  if $DRY_RUN; then
    echo "Would delete: $snap"
  else
    echo -n "Deleting: $snap ... "
    curl -sk "${AUTH[@]}" -X DELETE "$ES_URL/_snapshot/$REPO_NAME/$snap" | jq -r '.acknowledged'
  fi
done
