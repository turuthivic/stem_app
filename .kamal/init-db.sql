-- Initialize all databases required for the application
-- This script is run when the PostgreSQL container is first created

-- Main application database (created by default via POSTGRES_DB)
-- stem_app_production

-- Additional databases for Solid components
CREATE DATABASE stem_app_production_cache;
CREATE DATABASE stem_app_production_queue;
CREATE DATABASE stem_app_production_cable;

-- Grant privileges to the stem_app user
GRANT ALL PRIVILEGES ON DATABASE stem_app_production TO stem_app;
GRANT ALL PRIVILEGES ON DATABASE stem_app_production_cache TO stem_app;
GRANT ALL PRIVILEGES ON DATABASE stem_app_production_queue TO stem_app;
GRANT ALL PRIVILEGES ON DATABASE stem_app_production_cable TO stem_app;
