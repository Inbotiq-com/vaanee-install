-- 002_agents_and_flows.sql
CREATE TABLE IF NOT EXISTS caller_ai_agent_profiles (
    id UUID PRIMARY KEY,
    organization_id UUID NOT NULL,
    name TEXT NOT NULL,
    calling_on_behalf_of TEXT NOT NULL,
    language TEXT NOT NULL,
    phone_numbers TEXT[] NOT NULL,
    voice_option TEXT,
    volume NUMERIC,
    speed TEXT,
    emotion TEXT,
    pronunciation TEXT,
    use_case TEXT,
    prompt TEXT NOT NULL,
    welcome_message TEXT,
    end_message TEXT,
    max_call_duration_ms INTEGER,
    timeout_duration_ms INTEGER,
    budget_minutes INTEGER,
    retry_config JSONB,
    calling_hours JSONB,
    parallel_calls INTEGER DEFAULT 1,
    key_info JSONB,
    is_active BOOLEAN DEFAULT true,
    created_by UUID,
    updated_by UUID,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT false,
    deleted_at TIMESTAMPTZ,
    budget_minutes_left INTEGER,
    variables JSONB DEFAULT '{}',
    interruption_word_threshold INTEGER DEFAULT 6,
    interruption_stopwords TEXT[] DEFAULT ARRAY['stop','wait','hold on','hold','one moment','one second','pause'],
    agent_direction TEXT DEFAULT 'outbound',
    concurrency_settings JSONB,
    transfer_settings JSONB,
    kb_trigger_instructions TEXT,
    functions JSONB,
    trigger_rules JSONB,
    stateful_mode SMALLINT NOT NULL DEFAULT 0,
    flow_id UUID,
    published_flow_id UUID,
    first_node_id UUID,
    intent TEXT[] DEFAULT ARRAY[]::TEXT[]
);

ALTER TABLE caller_ai_agent_profiles
  DROP CONSTRAINT IF EXISTS caller_ai_agent_profiles_published_flow_fkey;

CREATE TABLE IF NOT EXISTS caller_ai_agent_flows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    agent_id UUID NOT NULL,
    first_node_id UUID,
    status TEXT NOT NULL DEFAULT 'draft',
    schema JSONB NOT NULL DEFAULT '{"Nodes": []}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS caller_ai_stateful_flows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL UNIQUE,
    organization_id UUID NOT NULL,
    flow_data JSONB,
    published_flow JSONB,
    status VARCHAR DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS caller_ai_agent_flow_published (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    agent_id UUID NOT NULL,
    source_flow_id UUID,
    flow_id UUID,
    first_node_id UUID,
    status TEXT NOT NULL DEFAULT 'published',
    schema JSONB NOT NULL DEFAULT '{"Nodes": []}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE caller_ai_agent_flow_published
  ADD COLUMN IF NOT EXISTS flow_id UUID;

UPDATE caller_ai_agent_flow_published
SET flow_id = source_flow_id
WHERE flow_id IS NULL;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'caller_ai_agent_flow_published_agent_id_key'
    ) THEN
        ALTER TABLE caller_ai_agent_flow_published
            ADD CONSTRAINT caller_ai_agent_flow_published_agent_id_key UNIQUE (agent_id);
    END IF;
END $$;
