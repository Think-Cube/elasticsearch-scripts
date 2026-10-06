#!/usr/bin/env bash
# Create or update an ILM policy.
# Usage: ./create-ilm-policy.sh -p POLICY_NAME -f POLICY_FILE.json
#        ./create-ilm-policy.sh -p logs-default  (uses built-in default)

set -euo pipefail

ES_URL="${ES_URL:-http://localhost:9200}"
ES_USER="${ES_USER:-elastic}"
ES_PASS="${ES_PASS:-}"

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -p  Policy name (required)
  -f  JSON policy file (optional — uses default hot/warm/cold/delete policy)
  -e  Elasticsearch URL (default: \$ES_URL or http://localhost:9200)
  -h  Show this help
EOF
}

POLICY_NAME=""
POLICY_FILE=""

while getopts ":p:f:e:h" opt; do
  case $opt in
    p) POLICY_NAME="$OPTARG" ;;
    f) POLICY_FILE="$OPTARG" ;;
    e) ES_URL="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

[ -z "$POLICY_NAME" ] && { echo "Error: -p POLICY_NAME is required."; usage; exit 1; }

AUTH=()
[ -n "$ES_PASS" ] && AUTH=(-u "${ES_USER}:${ES_PASS}")

if [ -n "$POLICY_FILE" ]; then
  BODY=$(cat "$POLICY_FILE")
else
  # Default: hot (7d rollover) → warm (30d) → cold (90d) → delete (365d)
  BODY='{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": {
            "max_age": "7d",
            "max_primary_shard_size": "50gb"
          },
          "set_priority": { "priority": 100 }
        }
      },
      "warm": {
        "min_age": "30d",
        "actions": {
          "shrink":   { "number_of_shards": 1 },
          "forcemerge": { "max_num_segments": 1 },
          "set_priority": { "priority": 50 }
        }
      },
      "cold": {
        "min_age": "90d",
        "actions": {
          "freeze": {},
          "set_priority": { "priority": 0 }
        }
      },
      "delete": {
        "min_age": "365d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}'
fi

echo "Creating ILM policy: $POLICY_NAME"
curl -sk "${AUTH[@]}" -X PUT "$ES_URL/_ilm/policy/$POLICY_NAME" \
  -H "Content-Type: application/json" \
  -d "$BODY" | jq .

echo ""
echo "Done. Verify: curl $ES_URL/_ilm/policy/$POLICY_NAME"
