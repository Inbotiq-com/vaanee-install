-- 008_knowledge_base_vectors.sql
--
-- Local pgvector store for KB chunk embeddings (audit P4/B1/SCH-02). On-prem the
-- knowledge base lives in the CUSTOMER's own Postgres (their DATABASE_URL) — NOT
-- Inbotiq's central Cosmos — so KB content + vectors never leave the VM.
--
--   * knowledge_base_items (migration 003) = document-level rows.
--   * knowledge_base_chunks (here)         = per-chunk text + 768-dim embedding.
--
-- Ingestion (inbotiq-backend utils/pgvectorKbClient.js) writes chunks here;
-- retrieval (AI_Webhook db/cosmos_search.py, VAANEE_MODE pgvector path) reads them
-- with cosine distance. Embeddings are Gemini text-embedding-004 (768) using the
-- org's "Assigned" Google key delivered via check-in. Requires the `vector`
-- extension (migration 001 + the installer pgvector preflight).
CREATE TABLE IF NOT EXISTS knowledge_base_chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    agent_id UUID NOT NULL,
    item_id UUID NOT NULL,
    chunk_index INTEGER NOT NULL DEFAULT 0,
    content TEXT NOT NULL,
    content_vector vector(768),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_kb_chunks_item_chunk UNIQUE (item_id, chunk_index)
);

-- Filter indexes (every query scopes by org + agent; deletes scope by item).
CREATE INDEX IF NOT EXISTS idx_kb_chunks_org_agent ON knowledge_base_chunks(organization_id, agent_id);
CREATE INDEX IF NOT EXISTS idx_kb_chunks_item ON knowledge_base_chunks(item_id);

-- HNSW cosine index for fast approximate nearest-neighbour retrieval.
-- (pgvector >= 0.5.0; falls back fine to a seq scan on small KBs if absent.)
DO $$
BEGIN
    BEGIN
        CREATE INDEX IF NOT EXISTS idx_kb_chunks_vec_hnsw
            ON knowledge_base_chunks USING hnsw (content_vector vector_cosine_ops);
    EXCEPTION WHEN feature_not_supported OR undefined_object THEN
        -- Older pgvector without HNSW: use ivfflat instead.
        CREATE INDEX IF NOT EXISTS idx_kb_chunks_vec_ivf
            ON knowledge_base_chunks USING ivfflat (content_vector vector_cosine_ops) WITH (lists = 100);
    END;
END $$;
