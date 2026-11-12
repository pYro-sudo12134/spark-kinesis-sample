#!/bin/bash
set -e

PGDATA="${PGDATA:-/var/lib/postgresql/data}"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo ">>> basebackup from postgres-primary"
  until PGPASSWORD="${PG_REPL_PASSWORD}" pg_basebackup \
      -h postgres-primary \
      -U "${PG_REPL_USER}" \
      -D "$PGDATA" \
      -Fp -Xs -P -R; do
    echo ">>> primary not ready, retry in 2s"
    sleep 2
  done
fi

chown -R postgres:postgres "$PGDATA"
chmod 700 "$PGDATA"

exec gosu postgres postgres \
  -c hot_standby=on \
  -c hot_standby_feedback=on \
  -c hba_file=/etc/postgresql/pg_hba.conf