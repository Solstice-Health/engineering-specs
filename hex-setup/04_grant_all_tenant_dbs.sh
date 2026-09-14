#!/usr/bin/env bash
# Apply 03_grant_tenant_db.sql to every TENANT database on the prod instance via the
# SSH tunnel (prod = port 5433). Idempotent. Superseded by Backend-Server
# scripts/tenant_onboarding/onboard_all_tenants.sh; kept for reference.
#
#   PGPASSWORD=<postgres-master-pw> ./04_grant_all_tenant_dbs.sh postgres 5433
#
# Tenant test: the database has an admin_requests table (same discovery rule as the CRM
# sync Lambda). Anything else on the instance is skipped. solstice-auth is a separate RDS
# instance and never appears here; the check is still applied so a future non-tenant
# database on this instance is not granted by accident.
set -euo pipefail
cd "$(dirname "$0")"
ADMIN_USER="${1:?usage: 04_grant_all_tenant_dbs.sh <admin-user> <port>}"
PORT="${2:?usage: 04_grant_all_tenant_dbs.sh <admin-user> <port>}"
HOST="${HOST:-localhost}"
export PGSSLMODE="${PGSSLMODE:-require}"

DBS=$(psql -h "$HOST" -p "$PORT" -U "$ADMIN_USER" -d postgres -Atc \
  "select datname from pg_database where not datistemplate and datname not in ('postgres','rdsadmin') order by datname")

for db in $DBS; do
  is_tenant=$(psql -h "$HOST" -p "$PORT" -U "$ADMIN_USER" -d "$db" -Atc \
    "select to_regclass('public.admin_requests') is not null")
  if [ "$is_tenant" != "t" ]; then
    echo "skip     $db (no admin_requests table: not a tenant database)"
    continue
  fi
  psql -h "$HOST" -p "$PORT" -U "$ADMIN_USER" -d "$db" -q -f 03_grant_tenant_db.sql
  echo "granted  $db"
done
echo "Done. Each tenant above needs a 'Prod - <tenant>' connection in Hex if per-tenant querying is wanted."
