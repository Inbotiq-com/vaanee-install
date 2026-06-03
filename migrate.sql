-- ============================================================
-- Vaanee On-Premise Client Database Migration (Master)
-- Run this once on the CLIENT PostgreSQL database before installing Vaanee
-- Usage: psql "postgresql://user:password@host:5432/dbname" -f migrate.sql
-- ============================================================

\set ON_ERROR_STOP on

\ir migrations/001_extensions.sql
\ir migrations/002_agents_and_flows.sql
\ir migrations/003_knowledge_base.sql
\ir migrations/004_calls_runtime.sql
\ir migrations/005_pronunciation_and_campaigns.sql
\ir migrations/006_indexes_and_finalize.sql
\ir migrations/007_telephony_and_config.sql
