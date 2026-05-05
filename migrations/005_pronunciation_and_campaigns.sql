-- 005_pronunciation_and_campaigns.sql
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
