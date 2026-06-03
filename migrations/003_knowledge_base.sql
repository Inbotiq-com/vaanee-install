-- 003_knowledge_base.sql
--
-- knowledge_base_items is the DOCUMENT-level table the backend KB service
-- (utils/knowledgeBaseService.js, mounted at /api/knowledge-base) actually
-- writes: it INSERTs source_name/source_url/content_hash/total_size_bytes and
-- SELECTs content_hash. The previous chunk/vector shape (item_id, content,
-- chunk_index, content_vector) caused Postgres 42703 (UNDEFINED_COLUMN) on
-- every upload (audit SCH-01/B2). This now mirrors the live qa schema exactly.
--
-- NOTE on vectors (audit SCH-02/B1): per-chunk embeddings live in a SEPARATE
-- local pgvector table (knowledge_base_chunks) created in migration 008 once
-- the on-prem KB retrieval path reads pgvector instead of central Cosmos.
-- This document table intentionally has no vector column (it matches qa).
--
-- Upgrade self-heal (audit SCH-01b): a pre-launch DB may already hold the OLD
-- broken knowledge_base_items (chunk/vector shape: item_id/content/chunk_index/
-- content_vector) which never worked — every upload hit 42703 — so it has no
-- usable data. CREATE TABLE IF NOT EXISTS would leave that wrong table in place
-- and the document-schema indexes below would fail (e.g. workflow_execution_id
-- does not exist). Detect the old shape by the ABSENCE of source_name (the key
-- column of the document schema) and drop it so the correct table is created.
-- A correct/populated table already has source_name -> never dropped (safe).
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables
               WHERE table_schema='public' AND table_name='knowledge_base_items')
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns
                       WHERE table_schema='public' AND table_name='knowledge_base_items'
                         AND column_name='source_name') THEN
        RAISE NOTICE 'Dropping pre-launch knowledge_base_items (old shape, no source_name)';
        DROP TABLE knowledge_base_items CASCADE;
    END IF;
END$$;

CREATE TABLE IF NOT EXISTS knowledge_base_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    agent_id UUID NOT NULL,
    source_type VARCHAR(50) NOT NULL,
    source_name VARCHAR(512) NOT NULL,
    source_url VARCHAR(2048),
    content_hash VARCHAR(128),
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    error_message TEXT,
    chunk_count INTEGER DEFAULT 0,
    total_size_bytes BIGINT DEFAULT 0,
    workflow_execution_id VARCHAR(255),
    last_fetched_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_kb_items_org_agent_hash UNIQUE (organization_id, agent_id, content_hash)
);

CREATE INDEX IF NOT EXISTS idx_kb_items_org ON knowledge_base_items(organization_id);
CREATE INDEX IF NOT EXISTS idx_kb_items_agent ON knowledge_base_items(agent_id);
CREATE INDEX IF NOT EXISTS idx_kb_items_status ON knowledge_base_items(status);
CREATE INDEX IF NOT EXISTS idx_kb_items_workflow ON knowledge_base_items(workflow_execution_id);

CREATE TABLE IF NOT EXISTS current_contact_info (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    agent_id UUID,
    phone_number TEXT,
    name TEXT,
    email TEXT,
    fields JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
