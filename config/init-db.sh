#!/bin/bash
set -e

# Create additional databases needed by Rails (Solid Queue, Solid Cache, Solid Cable)
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE stem_app_production_cache;
    CREATE DATABASE stem_app_production_queue;
    CREATE DATABASE stem_app_production_cable;
EOSQL
