-- 003_knowledge_base.sql
CREATE TABLE IF NOT EXISTS knowledge_base_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL,
    organization_id UUID NOT NULL,
    agent_id UUID NOT NULL,
    source_type TEXT,
    title TEXT,
    url TEXT,
    content TEXT NOT NULL,
    chunk_index INTEGER DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'ready',
    metadata JSONB DEFAULT '{}',
    content_vector vector(768),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_kb_agent_status
ON knowledge_base_items(agent_id, status);

CREATE INDEX IF NOT EXISTS idx_kb_item_id
ON knowledge_base_items(item_id);

CREATE INDEX IF NOT EXISTS idx_kb_content_vector
ON knowledge_base_items USING ivfflat (content_vector vector_cosine_ops);

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
