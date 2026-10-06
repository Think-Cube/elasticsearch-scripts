# elasticsearch-scripts
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Operational scripts for Elasticsearch 9.x — ILM policy management, Snapshot backup/restore, and index lifecycle operations.

## Requirements

- Elasticsearch 9.x
- `curl` and `jq`
- Credentials with appropriate cluster privileges

## Configuration

All scripts read connection details from environment variables:

```bash
export ES_URL="https://my-cluster:9200"
export ES_USER="elastic"
export ES_PASS="changeme"
```

## Scripts

### Health

| Script | Description |
|---|---|
| `scripts/health/cluster-health.sh` | Cluster health, node stats, shard summary, disk usage |

```bash
./scripts/health/cluster-health.sh
```

### ILM (Index Lifecycle Management)

| Script | Description |
|---|---|
| `scripts/ilm/create-ilm-policy.sh` | Create or update an ILM policy |
| `scripts/ilm/apply-ilm-to-index.sh` | Apply a policy to an index or index template |

```bash
# Create default policy (hot 7d → warm 30d → cold 90d → delete 365d)
./scripts/ilm/create-ilm-policy.sh -p logs-default

# Create from custom JSON
./scripts/ilm/create-ilm-policy.sh -p logs-default -f examples/ilm-policy.json

# Apply to existing index
./scripts/ilm/apply-ilm-to-index.sh -i logs-app-000001 -p logs-default

# Apply to index template (all future indices)
./scripts/ilm/apply-ilm-to-index.sh -i logs-app -p logs-default -t
```

### Snapshot Backup & Restore

| Script | Description |
|---|---|
| `scripts/snapshot/register-s3-repository.sh` | Register S3 snapshot repository |
| `scripts/snapshot/register-azure-repository.sh` | Register Azure Blob Storage repository |
| `scripts/snapshot/create-snapshot.sh` | Create a snapshot |
| `scripts/snapshot/restore-snapshot.sh` | Restore from a snapshot |
| `scripts/snapshot/delete-old-snapshots.sh` | Delete snapshots older than N days |

```bash
# Register S3 repository (add credentials to keystore first)
./scripts/snapshot/register-s3-repository.sh -r s3-backup -b my-es-bucket -g eu-west-1

# Register Azure repository
./scripts/snapshot/register-azure-repository.sh -r azure-backup -c es-snapshots

# Create snapshot (all indices)
./scripts/snapshot/create-snapshot.sh -r s3-backup

# Create snapshot (specific pattern, wait for completion)
./scripts/snapshot/create-snapshot.sh -r s3-backup -i "logs-*" -w

# Restore snapshot
./scripts/snapshot/restore-snapshot.sh -r s3-backup -s snapshot-2025-08-01-0000

# Restore with rename (avoid conflicts with existing indices)
./scripts/snapshot/restore-snapshot.sh -r s3-backup -s snapshot-2025-08-01-0000 \
  -x "logs-(.*)" -n "restored-\$1"

# Delete snapshots older than 90 days (dry run first)
./scripts/snapshot/delete-old-snapshots.sh -r s3-backup -d 90 -n
./scripts/snapshot/delete-old-snapshots.sh -r s3-backup -d 90
```

### Index Management

| Script | Description |
|---|---|
| `scripts/indices/list-indices.sh` | List indices with health, size, doc count |
| `scripts/indices/close-old-indices.sh` | Close indices older than N days |
| `scripts/indices/delete-old-indices.sh` | Delete indices older than N days |

```bash
# List all indices sorted by size
./scripts/indices/list-indices.sh

# List indices matching pattern
./scripts/indices/list-indices.sh -p "logs-app-*"

# Close indices older than 30 days (dry run first)
./scripts/indices/close-old-indices.sh -p logs-app -d 30 -n
./scripts/indices/close-old-indices.sh -p logs-app -d 30

# Delete indices older than 90 days
./scripts/indices/delete-old-indices.sh -p logs-app -d 90 -n
./scripts/indices/delete-old-indices.sh -p logs-app -d 90
```

## Examples

| File | Description |
|---|---|
| `examples/ilm-policy.json` | Full ILM policy: hot → warm → cold → frozen → delete |
| `examples/index-template.json` | Index template with ILM and field mappings |

## Cron example

```bash
# Daily snapshot at 02:00, cleanup snapshots older than 90 days
0 2 * * * ES_URL=https://es:9200 ES_USER=elastic ES_PASS=secret \
  /opt/elasticsearch-scripts/scripts/snapshot/create-snapshot.sh -r s3-backup -w

30 2 * * * ES_URL=https://es:9200 ES_USER=elastic ES_PASS=secret \
  /opt/elasticsearch-scripts/scripts/snapshot/delete-old-snapshots.sh -r s3-backup -d 90
```

## License

MIT © [Think-Cube](https://github.com/Think-Cube)

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.
