-- ============================================================
-- Vaanee On-Premise Database Migration
-- Run this once on your PostgreSQL database before installing Vaanee
-- Usage: psql "postgresql://user:password@host:5432/dbname" -f migrate.sql
-- ============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- organizations
-- ============================================================
CREATE TABLE IF NOT EXISTS organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR NOT NULL,
    is_active BOOLEAN DEFAULT true,
    n8n_instance_url VARCHAR,
    n8n_api_key TEXT,
    postgres_connection_string TEXT,
    azure_resource_group VARCHAR,
    infrastructure_status VARCHAR DEFAULT 'not_provisioned',
    provisioned_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- users
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    email VARCHAR NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    first_name VARCHAR,
    last_name VARCHAR,
    is_active BOOLEAN DEFAULT true,
    is_temporary_password BOOLEAN DEFAULT false,
    last_login_at TIMESTAMPTZ,
    password_changed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- invitations
-- ============================================================
CREATE TABLE IF NOT EXISTS invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    email VARCHAR NOT NULL,
    first_name VARCHAR,
    last_name VARCHAR,
    role VARCHAR NOT NULL,
    temporary_password VARCHAR NOT NULL,
    invitation_token VARCHAR NOT NULL,
    status VARCHAR NOT NULL DEFAULT 'pending',
    invited_by_user_id UUID REFERENCES users(id),
    invited_by_admin_id UUID,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '7 days'),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- otp_sessions
-- ============================================================
CREATE TABLE IF NOT EXISTS otp_sessions (
    session_token TEXT PRIMARY KEY,
    email TEXT NOT NULL,
    purpose TEXT NOT NULL,
    otp_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    max_attempts INTEGER NOT NULL DEFAULT 3,
    last_sent_at TIMESTAMPTZ NOT NULL,
    verified BOOLEAN NOT NULL DEFAULT false,
    verified_at TIMESTAMPTZ,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- audit_logs
-- ============================================================
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID,
    user_id UUID,
    admin_id UUID,
    action VARCHAR NOT NULL,
    entity_type VARCHAR NOT NULL,
    entity_id VARCHAR,
    metadata JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- migration_history
-- ============================================================
CREATE SEQUENCE IF NOT EXISTS migration_history_id_seq;
CREATE TABLE IF NOT EXISTS migration_history (
    id INTEGER PRIMARY KEY DEFAULT nextval('migration_history_id_seq'),
    migration_name VARCHAR NOT NULL,
    applied_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    execution_time_ms INTEGER,
    success BOOLEAN DEFAULT true,
    error_message TEXT
);

-- ============================================================
-- agents
-- ============================================================
CREATE TABLE IF NOT EXISTS agents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR NOT NULL,
    description TEXT,
    agent_type VARCHAR NOT NULL,
    n8n_workflow_ids TEXT[],
    is_available_for_purchase BOOLEAN DEFAULT true,
    settings_schema JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- agent_credentials
-- ============================================================
CREATE TABLE IF NOT EXISTS agent_credentials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    agent_id UUID NOT NULL,
    name VARCHAR NOT NULL,
    type VARCHAR NOT NULL,
    credentials JSONB NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- agent_pronunciation_dictionaries
-- ============================================================
CREATE TABLE IF NOT EXISTS agent_pronunciation_dictionaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    agent_id UUID NOT NULL,
    cartesia_dictionary_id TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    is_locked BOOLEAN DEFAULT true,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- agent_pronunciation_dictionary_entries
-- ============================================================
CREATE TABLE IF NOT EXISTS agent_pronunciation_dictionary_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dictionary_id UUID NOT NULL REFERENCES agent_pronunciation_dictionaries(id),
    word TEXT NOT NULL,
    pronunciation TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- caller_ai_agent
-- ============================================================
CREATE TABLE IF NOT EXISTS caller_ai_agent (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    answer_type VARCHAR DEFAULT 'Yes/No',
    context_window TEXT,
    target_audience TEXT,
    purpose TEXT,
    question TEXT,
    greeting_message TEXT,
    caller_name TEXT,
    calling_on_behalf_of TEXT,
    chatbot_gender TEXT,
    chatbot_voice TEXT,
    first_message TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- caller_ai_agent_flows
-- ============================================================
CREATE TABLE IF NOT EXISTS caller_ai_agent_flows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    agent_id UUID NOT NULL,
    first_node_id UUID,
    status TEXT NOT NULL DEFAULT 'draft',
    schema JSONB NOT NULL DEFAULT '{"Nodes": []}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- caller_ai_agent_flow_published
-- ============================================================
CREATE TABLE IF NOT EXISTS caller_ai_agent_flow_published (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    agent_id UUID NOT NULL,
    source_flow_id UUID,
    first_node_id UUID,
    status TEXT NOT NULL DEFAULT 'published',
    schema JSONB NOT NULL DEFAULT '{"Nodes": []}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- caller_ai_agent_profiles
-- ============================================================
CREATE TABLE IF NOT EXISTS caller_ai_agent_profiles (
    id UUID PRIMARY KEY,
    organization_id UUID NOT NULL REFERENCES organizations(id),
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
    interruption_stopwords TEXT[] DEFAULT ARRAY['stop','wait','hold on','hold','one moment','one second','pause','रुको','रुकिए','एक मिनट','एक सेकंड','बस','रहने दो','ठहर जाओ','सुनिए','चुप'],
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

-- ============================================================
-- caller_ai_campaigns
-- ============================================================
CREATE TABLE IF NOT EXISTS caller_ai_campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    agent_id UUID NOT NULL,
    organization_id UUID REFERENCES organizations(id),
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

-- ============================================================
-- calls_thru_campaign
-- ============================================================
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
-- call_executions
-- ============================================================
CREATE TABLE IF NOT EXISTS call_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
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

-- ============================================================
-- call_retry_attempts
-- ============================================================
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

-- ============================================================
-- call_session
-- ============================================================
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

-- ============================================================
-- call_session_totals
-- ============================================================
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

-- ============================================================
-- caller_ai_chatbot_configs
-- ============================================================
CREATE TABLE IF NOT EXISTS caller_ai_chatbot_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    agent_id UUID NOT NULL,
    trigger_mode VARCHAR NOT NULL,
    webhook_url TEXT NOT NULL,
    webhook_secret TEXT NOT NULL,
    google_sheet_url TEXT,
    notes TEXT,
    created_by_user_id UUID,
    updated_by_user_id UUID,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- node_executions
-- ============================================================
CREATE TABLE IF NOT EXISTS node_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    call_execution_id UUID NOT NULL REFERENCES call_executions(id),
    node_id VARCHAR NOT NULL,
    node_name VARCHAR,
    node_type VARCHAR,
    status VARCHAR NOT NULL DEFAULT 'pending',
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    duration_ms INTEGER,
    input_data JSONB,
    output_data JSONB,
    branch_taken VARCHAR
);

-- ============================================================
-- organization_caller_ai_config
-- ============================================================
CREATE TABLE IF NOT EXISTS organization_caller_ai_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    kyc_status VARCHAR DEFAULT 'not_started',
    kyc_approved_at TIMESTAMPTZ,
    kyc_approved_by UUID,
    kyc_rejection_reason TEXT,
    telephony_enabled BOOLEAN DEFAULT false,
    telephony_enabled_at TIMESTAMPTZ,
    exotel_account_sid VARCHAR,
    exotel_api_key VARCHAR,
    exotel_api_token TEXT,
    exotel_subdomain VARCHAR DEFAULT 'api.in.exotel.com',
    exotel_app_id VARCHAR,
    exotel_is_active BOOLEAN DEFAULT true,
    campaign_flow_id VARCHAR,
    encrypted_config TEXT,
    created_by UUID,
    updated_by UUID,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- organization_phone_numbers
-- ============================================================
CREATE TABLE IF NOT EXISTS organization_phone_numbers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    phone_number VARCHAR NOT NULL,
    phone_number_normalized VARCHAR,
    exotel_phone_sid VARCHAR,
    exotel_app_id VARCHAR,
    friendly_name VARCHAR,
    status VARCHAR DEFAULT 'active',
    assigned_by UUID,
    assigned_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- workflow_states
-- ============================================================
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
-- vaanee_package_licences
-- ============================================================
CREATE TABLE IF NOT EXISTS vaanee_package_licences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    subscription_id UUID NOT NULL,
    api_key_hash TEXT NOT NULL,
    api_key_prefix TEXT NOT NULL,
    api_key_issued_at TIMESTAMPTZ DEFAULT now(),
    licence_status TEXT NOT NULL DEFAULT 'pending_setup',
    max_agents INTEGER NOT NULL DEFAULT 50,
    max_concurrent_calls INTEGER NOT NULL DEFAULT 5,
    executions_allotted INTEGER NOT NULL DEFAULT 0,
    executions_used INTEGER NOT NULL DEFAULT 0,
    period_start DATE,
    period_end DATE,
    subscription_end_date DATE,
    last_checkin_at TIMESTAMPTZ,
    instance_id TEXT,
    vaanee_version TEXT,
    latest_version TEXT,
    update_available BOOLEAN DEFAULT false,
    paused_reason TEXT,
    paused_by TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- vaanee_package_events
-- ============================================================
CREATE TABLE IF NOT EXISTS vaanee_package_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    licence_id UUID NOT NULL REFERENCES vaanee_package_licences(id),
    event_type TEXT NOT NULL,
    performed_by TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- vaanee_request_logs
-- ============================================================
CREATE TABLE IF NOT EXISTS vaanee_request_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    licence_id UUID NOT NULL REFERENCES vaanee_package_licences(id),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    request_type TEXT NOT NULL,
    ip_address TEXT,
    instance_id TEXT,
    vaanee_version TEXT,
    response_status INTEGER,
    response_ms INTEGER,
    retry_attempt INTEGER DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- vaanee_cartesia_dictionaries
-- ============================================================
CREATE TABLE IF NOT EXISTS vaanee_cartesia_dictionaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    agent_id UUID NOT NULL,
    cartesia_dictionary_id TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- Indexes for performance
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_users_organization_id ON users(organization_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_call_session_organization_id ON call_session(organization_id);
CREATE INDEX IF NOT EXISTS idx_call_session_agent_id ON call_session(agent_id);
CREATE INDEX IF NOT EXISTS idx_call_executions_organization_id ON call_executions(organization_id);
CREATE INDEX IF NOT EXISTS idx_call_executions_agent_id ON call_executions(agent_id);
CREATE INDEX IF NOT EXISTS idx_caller_ai_campaigns_organization_id ON caller_ai_campaigns(organization_id);
CREATE INDEX IF NOT EXISTS idx_caller_ai_agent_profiles_organization_id ON caller_ai_agent_profiles(organization_id);
CREATE INDEX IF NOT EXISTS idx_vaanee_package_licences_organization_id ON vaanee_package_licences(organization_id);
CREATE INDEX IF NOT EXISTS idx_vaanee_package_licences_api_key_hash ON vaanee_package_licences(api_key_hash);
CREATE INDEX IF NOT EXISTS idx_vaanee_request_logs_licence_id ON vaanee_request_logs(licence_id);
CREATE INDEX IF NOT EXISTS idx_calls_thru_campaign_campaign_id ON calls_thru_campaign(campaign_id);
CREATE INDEX IF NOT EXISTS idx_calls_thru_campaign_organization_id ON calls_thru_campaign(organization_id);

-- ============================================================
-- Done
-- ============================================================
DO $$ BEGIN
  RAISE NOTICE 'Vaanee migration completed successfully.';
END $$;
