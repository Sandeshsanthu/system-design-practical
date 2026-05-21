#!/bin/bash
set -e

DATA_DIR="/var/lib/postgresql/data"

echo "⏳ Checking primary database readiness..."
until pg_isready -h postgres-primary -p 5432 -U admin; do
  echo "Waiting for primary database to accept connections..."
  sleep 2
done

# If the data directory is completely empty, pull down the physical backup from primary
if [ -z "$(ls -A "$DATA_DIR")" ]; then
  echo "🚀 Data directory is empty. Initializing base backup from primary..."

  # Run backup using the 'admin' superuser account
  PGPASSWORD="password" pg_basebackup \
    -h postgres-primary \
    -D "$DATA_DIR" \
    -U admin \
    -v \
    -P \
    -R \
    -X stream

  echo "✅ Base backup completed successfully."

  # Inject the replica's specific configurations onto the cloned state
  cp /etc/postgresql/postgresql.conf "$DATA_DIR/postgresql.conf"
else
  echo "ℹ️ Data directory already has records. Skipping backup phase."
fi

echo "🏁 Starting PostgreSQL Standby Server..."
exec postgres
