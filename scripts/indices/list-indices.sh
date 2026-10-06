#!/usr/bin/env bash
# List indices with size, doc count, and health.
# Usage: ./list-indices.sh [-p PATTERN] [-s] [-o]

set -euo pipefail

ES_URL="${ES_URL:-http://localhost:9200}"
ES_USER="${ES_USER:-elastic}"
ES_PASS="${ES_PASS:-}"

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -p  Index pattern (default: all)
  -s  Sort by size descending
  -o  Show only open indices
  -c  Show only closed indices
  -e  Elasticsearch URL (default: \$ES_URL or http://localhost:9200)
  -h  Show this help
EOF
}

PATTERN="*"
SORT=""
STATUS_FILTER=""

while getopts ":p:soce:h" opt; do
  case $opt in
    p) PATTERN="$OPTARG" ;;
    s) SORT="--sort-by-size" ;;
    o) STATUS_FILTER="open" ;;
    c) STATUS_FILTER="closed" ;;
    e) ES_URL="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

AUTH=()
[ -n "$ES_PASS" ] && AUTH=(-u "${ES_USER}:${ES_PASS}")

PARAMS="v&h=health,status,index,uuid,pri,rep,docs.count,docs.deleted,store.size,pri.store.size&s=store.size:desc"
[ -n "$STATUS_FILTER" ] && PARAMS="${PARAMS}&expand_wildcards=${STATUS_FILTER}"

curl -sk "${AUTH[@]}" "$ES_URL/_cat/indices/$PATTERN?$PARAMS"
