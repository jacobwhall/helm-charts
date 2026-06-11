# Sharkey Helm Chart

A Helm chart for deploying [Sharkey](https://joinsharkey.org) (a Misskey fork)
to Kubernetes, using:

- **CloudNativePG** for PostgreSQL (operator must be pre-installed)
- **Valkey** (official chart) for Redis-compatible caching and job queues
- **Meilisearch** (official chart) for full-text search

## Prerequisites

- Kubernetes 1.25+
- Helm 3.10+
- CloudNativePG operator installed in the cluster
- A StorageClass available (e.g. `local-path`)
- *(optional, for backups/recovery)* the [Barman Cloud Plugin](https://github.com/cloudnative-pg/plugin-barman-cloud) installed in the cluster

## Quick Start (fresh install)

```bash
helm repo add valkey https://valkey.io/valkey-helm/
helm repo add meilisearch https://meilisearch.github.io/meilisearch-kubernetes
helm dependency update .

# Edit values.yaml — at minimum set:
#   sharkey.url                        (your instance URL, IMMUTABLE)
#   cnpg.password                      (database password)
#   valkey.auth.aclUsers.default.password
#   sharkey.meilisearch.masterKey      (>= 16 random chars; required when meilisearch is enabled)
#   sharkey.objectStorage.accessKey/secretKey  (only if objectStorage.enabled)

helm install sharkey . -n sharkey --create-namespace
```

## Backups

WAL archiving and scheduled backups are configured via the Barman Cloud
Plugin. Pre-create a Secret in the release namespace holding your S3
credentials:

```bash
kubectl create secret generic cnpg-backup -n sharkey \
  --from-literal=ACCESS_KEY_ID=... \
  --from-literal=SECRET_ACCESS_KEY=...
```

Then enable backups in `values.yaml`:

```yaml
cnpg:
  backup:
    enabled: true
    schedule: "0 0 3 * * *"      # 6-field cron (sec min hr dom mon dow)
    retentionPolicy: "30d"
    s3Credentials:
      destinationPath: s3://my-bucket/sharkey
      endpointUrl: https://s3.example.com    # omit for AWS S3
      accessKeyId:
        name: cnpg-backup
        key: ACCESS_KEY_ID
      secretAccessKey:
        name: cnpg-backup
        key: SECRET_ACCESS_KEY
```

This renders an `ObjectStore` for the backup destination, a `ScheduledBackup`
on the chosen cron, and adds the `barman-cloud.cloudnative-pg.io` plugin to
the `Cluster` as a WAL archiver.

## Restoring from a backup

Set `cnpg.recover.enabled: true` and point its `s3Credentials` at the bucket
holding the backup. The cluster will bootstrap from the most recent base
backup and replay WAL. `recover` is mutually exclusive with `import` (the
chart fails fast at template time if both are set). `recover.serverName`
defaults to the current cluster name; override it if you're restoring from
a backup that was taken under a different cluster name.

## Migrating from a VM

See the migration runbook in the plan document for full details.
The short version:

1. Stop Sharkey on the VM
2. Open PostgreSQL on the VM to accept connections from k8s pod CIDR
3. Set `cnpg.import.enabled: true` with source VM details in values
4. `helm install` — CNPG will pull the database automatically
5. Verify data, update DNS / Cloudflare Tunnel
6. Set `cnpg.import.enabled: false` and `helm upgrade`

## Architecture

```
┌──────────────────────────────┐
│  Cloudflare Tunnel Pod       │
│  (already in your cluster)   │
└──────────┬───────────────────┘
           │ :3000
┌──────────▼───────────────────┐
│  Sharkey Deployment          │
│  (sharkey container)         │
└──┬──────────┬───────────┬────┘
   │          │           │
   ▼          ▼           ▼
 CNPG       Valkey    Meilisearch
 (PG16)   (standalone)  (:7700)
 :5432      :6379
```

## Why Valkey instead of Bitnami Redis?

Bitnami's free container images and pre-packaged Helm charts stopped
receiving updates in August 2025 under Broadcom's new commercial model.
The official Valkey Helm chart is maintained by the Valkey community
under a BSD-3-Clause license with no vendor lock-in risk.

Valkey is wire-compatible with Redis — Sharkey's `redis:` config blocks
work identically.

## Secrets

The chart renders Sharkey's `default.yml` (which contains the DB and Valkey
passwords inline) into a `Secret`, not a `ConfigMap`. The Meilisearch master
key is held in its own `Secret` (`<release>-meilisearch-key`), referenced by
the Meilisearch pod via `envFrom` and by Sharkey via the rendered config.

Object storage credentials can either be set inline in `values.yaml` or
sourced from a pre-existing Secret by setting
`sharkey.objectStorage.existingSecret` to the Secret name (keys: `accessKey`,
`secretKey`). Pre-existing Secrets are resolved via Helm `lookup`, so the
Secret must exist in the release namespace before `helm install/upgrade`.
