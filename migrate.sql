-- ============================================================
-- Vaanee On-Premise Client Database Migration
-- Run this once on the CLIENT PostgreSQL database before installing Vaanee
-- Usage: psql "postgresql://user:password@host:5432/dbname" -f migrate.sql
-- ============================================================

-- Extensions required on client DB
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "vector";

-- ============================================================
-- caller_ai_agent_profiles
-- Core agent configuration used by Vaanee engine
-- ============================================================
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

-- ============================================================
-- Flow tables
-- ============================================================
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

-- ============================================================
-- Knowledge base tables (pgvector)
-- ============================================================
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

-- ============================================================
-- Contact data
-- ============================================================
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

-- ============================================================
-- Call runtime/history tables
-- ============================================================
CREATE TABLE IF NOT EXISTS call_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    agent_id UUID NOT NULL,
    flow_version_id UUID,
    call_sid VARCHAR,
    session_id VARCHAR,
    phone_number VARCHAR,
    status VARCHAR NOT NULL DEFAULT 'initiated',
    execution_status VARCHAR NOT NULL DEFAULT 'running',
    started_at TIMESTAMP NOT NULL DEFAULT now(),
    completed_at TIMESTAMP,
    duration_seconds INTEGER,
    metadata JSONB
);

CREATE TABLE IF NOT EXISTS node_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    call_execution_id UUID NOT NULL,
    node_id VARCHAR NOT NULL,
    node_name VARCHAR,
    node_type VARCHAR,
    status VARCHAR NOT NULL DEFAULT 'pending',
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    duration_ms INTEGER,
    input_data JSONB,
    output_data JSONB,
    branch_taken VARCHAR,
    CONSTRAINT node_executions_call_execution_fk
      FOREIGN KEY (call_execution_id) REFERENCES call_executions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS call_retry_attempts (
    id TEXT PRIMARY KEY,
    call_sid TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    organization_id TEXT NOT NULL,
    agent_id TEXT NOT NULL,
    attempt_number INTEGER NOT NULL DEFAULT 1,
    max_attempts INTEGER NOT NULL DEFAULT 2,
    retry_delay_minutes INTEGER NOT NULL DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'pending',
    scheduled_at TIMESTAMPTZ,
    executed_at TIMESTAMPTZ,
    result_status TEXT,
    error_message TEXT,
    original_payload JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS call_session (
    call_id TEXT PRIMARY KEY,
    organization_id TEXT NOT NULL,
    caller_number TEXT,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    answered BOOLEAN NOT NULL DEFAULT false,
    streamed BOOLEAN NOT NULL DEFAULT false,
    used_fallback BOOLEAN NOT NULL DEFAULT false,
    http_status INTEGER,
    ttfb_ms INTEGER,
    end_reason TEXT,
    region TEXT,
    ws_url TEXT,
    meta JSONB DEFAULT '{}',
    question_response TEXT,
    agent_id TEXT,
    field_responses JSONB DEFAULT '{}',
    conversation JSONB DEFAULT '{}',
    budget_decremented BOOLEAN NOT NULL DEFAULT false,
    intent TEXT,
    recording_url TEXT
);

CREATE TABLE IF NOT EXISTS call_session_totals (
    organization_id TEXT PRIMARY KEY,
    total_calls BIGINT NOT NULL DEFAULT 0,
    calls_picked BIGINT NOT NULL DEFAULT 0,
    calls_not_picked BIGINT NOT NULL DEFAULT 0,
    hangups_total BIGINT NOT NULL DEFAULT 0,
    hangups_before_answer BIGINT NOT NULL DEFAULT 0,
    hangups_after_answer BIGINT NOT NULL DEFAULT 0,
    ws_errors BIGINT NOT NULL DEFAULT 0,
    timeouts BIGINT NOT NULL DEFAULT 0,
    success_rate_pct NUMERIC NOT NULL DEFAULT 0,
    total_usage BIGINT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS workflow_states (
    execution_id VARCHAR NOT NULL,
    user_id VARCHAR NOT NULL,
    organization_id VARCHAR NOT NULL,
    type VARCHAR NOT NULL,
    phase VARCHAR,
    status VARCHAR,
    input_data JSONB,
    state_data JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (execution_id, user_id)
);

-- ============================================================
-- Pronunciation dictionary (client-side entries only)
-- cartesia_dictionary_id can remain NULL in on-prem mode
-- ============================================================
CREATE TABLE IF NOT EXISTS agent_pronunciation_dictionaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    agent_id UUID NOT NULL,
    cartesia_dictionary_id TEXT,
    name TEXT NOT NULL,
    description TEXT,
    is_locked BOOLEAN DEFAULT true,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS agent_pronunciation_dictionary_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dictionary_id UUID NOT NULL,
    word TEXT NOT NULL,
    pronunciation TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT agent_pron_dict_entries_dictionary_fk
      FOREIGN KEY (dictionary_id) REFERENCES agent_pronunciation_dictionaries(id) ON DELETE CASCADE
);

-- ============================================================
-- Optional campaign/runtime support tables
-- ============================================================
CREATE TABLE IF NOT EXISTS caller_ai_campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    agent_id UUID NOT NULL,
    organization_id UUID,
    source_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'DRAFT',
    total_contacts INTEGER DEFAULT 0,
    completed_contacts INTEGER DEFAULT 0,
    failed_contacts INTEGER DEFAULT 0,
    auto_deactivate_when_done BOOLEAN NOT NULL DEFAULT true,
    start_at TIMESTAMPTZ,
    end_at TIMESTAMPTZ,
    timezone TEXT DEFAULT 'Asia/Kolkata',
    config JSONB DEFAULT '{}',
    campaignsid TEXT,
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE SEQUENCE IF NOT EXISTS calls_thru_campaign_id_seq;
CREATE TABLE IF NOT EXISTS calls_thru_campaign (
    id BIGINT PRIMARY KEY DEFAULT nextval('calls_thru_campaign_id_seq'),
    phone_number TEXT NOT NULL,
    normalized_phone TEXT NOT NULL,
    campaign_id TEXT NOT NULL,
    organization_id TEXT,
    agent_id TEXT,
    caller_id TEXT,
    row_data JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- Indexes for performance
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_call_session_organization_id ON call_session(organization_id);
CREATE INDEX IF NOT EXISTS idx_call_session_agent_id ON call_session(agent_id);
CREATE INDEX IF NOT EXISTS idx_call_executions_organization_id ON call_executions(organization_id);
CREATE INDEX IF NOT EXISTS idx_call_executions_agent_id ON call_executions(agent_id);
CREATE INDEX IF NOT EXISTS idx_caller_ai_campaigns_organization_id ON caller_ai_campaigns(organization_id);
CREATE INDEX IF NOT EXISTS idx_caller_ai_agent_profiles_organization_id ON caller_ai_agent_profiles(organization_id);
CREATE INDEX IF NOT EXISTS idx_calls_thru_campaign_campaign_id ON calls_thru_campaign(campaign_id);
CREATE INDEX IF NOT EXISTS idx_calls_thru_campaign_organization_id ON calls_thru_campaign(organization_id);

ALTER TABLE caller_ai_campaigns
  DROP CONSTRAINT IF EXISTS caller_ai_campaigns_org_unique;

-- ============================================================
-- Done
-- ============================================================
DO $$ BEGIN
  RAISE NOTICE 'Vaanee client on-prem migration completed successfully.';
END $$;
