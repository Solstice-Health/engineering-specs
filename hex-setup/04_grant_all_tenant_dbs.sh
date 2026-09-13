#!/usr/bin/env bash
# Apply 03_grant_tenant_db.sql to every tenant DB on the PRIMARY via the prod tunnel.
# Start the tunnel first:  docker-compose --profile tunnel up ssh-tunnel   (prod = port 5433)
#
#   PGPASSWORD=<postgres-master-pw> ./04_grant_all_tenant_dbs.sh postgres 5433
#
# Prints the tenant DB list at the end. Each one becomes a separate Hex connection,
# because a Postgres connection in Hex is scoped to a single database.
set -euo pipefail
cd "$(dirname "$0")"
ADMIN_USER="${1:?usage: 04_grant_all_tenant_dbs.sh <admin-user> <port>}"
PORT="${2:?usage: 04_grant_all_tenant_dbs.sh <admin-user> <port>}"
HOST="${HOST:-localhost}"

DBS=$(psql -h "$HOST" -p "$PORT" -U "$ADMIN_USER" -d postgres -Atc \
  "select datname from pg_database where not datistemplate and datname not in ('postgres','rdsadmin') order by datname")

for db in $DBS; do
  psql -h "$HOST" -p "$PORT" -U "$ADMIN_USER" -d "$db" -q -f 03_grant_tenant_db.sql
  echo "granted  $db"
done

echo
echo "Tenant databases to add in Hex (one connection each):"
echo "$DBS"
