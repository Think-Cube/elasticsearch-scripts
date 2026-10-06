#!/usr/bin/env bash
# Cluster health overview — nodes, shards, disk usage, JVM heap.

set -euo pipefail

ES_URL="${ES_URL:-http://localhost:9200}"
ES_USER="${ES_USER:-elastic}"
ES_PASS="${ES_PASS:-}"

AUTH=""
[ -n "$ES_PASS" ] && AUTH="-u ${ES_USER}:${ES_PASS}"

echo "=== Cluster Health ==="
curl -sk $AUTH "$ES_URL/_cluster/health?pretty"

echo ""
echo "=== Nodes ==="
curl -sk $AUTH "$ES_URL/_cat/nodes?v&h=name,ip,heap.percent,ram.percent,cpu,load_1m,node.role,master,disk.used_percent"

echo ""
echo "=== Shards Summary ==="
curl -sk $AUTH "$ES_URL/_cat/shards?v&h=index,shard,prirep,state,docs,store,node" | head -50

echo ""
echo "=== Disk Usage ==="
curl -sk $AUTH "$ES_URL/_cat/allocation?v"
