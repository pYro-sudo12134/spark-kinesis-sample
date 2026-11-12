DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'iceberg') THEN
    RAISE EXCEPTION 'database "iceberg" does not exist — check POSTGRES_DB';
  END IF;
END $$;

CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator';
CREATE ROLE readonly   WITH LOGIN PASSWORD 'readonly';
GRANT CONNECT ON DATABASE iceberg TO readonly;
GRANT USAGE  ON SCHEMA public   TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO readonly;