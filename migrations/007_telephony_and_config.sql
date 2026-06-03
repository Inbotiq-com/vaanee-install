-- 007_telephony_and_config.sql
--
-- Tables the on-prem backend/webhook query at runtime that earlier migrations
-- (001-006) never created, so a fresh VM 403'd every call ("Exotel is not
-- configured") and 500'd the caller-AI config surface (audit D2/INSTALL-03,
-- D4/SCH-03, URL-05).
--
-- Columns + UNIQUE constraints mirror the live qa schema EXACTLY so the code's
-- upserts behave identically (e.g. routes/exotel.js does
-- `ON CONFLICT (organization_id)` on organization_caller_ai_config).
--
-- ADAPTED FOR ON-PREM: organization_id / agent_id / *_by columns are plain UUIDs
-- with NO foreign keys, because the central organizations/agents/users tables do
-- not exist on the customer VM (and must not — they're Inbotiq-side). Pre-creating
-- these here also makes the backend's runtime `CREATE TABLE IF NOT EXISTS ... REFERENCES`
-- statements a harmless no-op, eliminating the 42P01 failures in SCH-03.

-- ---------------------------------------------------------------------------
-- Telephony credentials per org (Exotel + Plivo). Source of truth for the
-- webhook's db/org_config.py and the admin Set-Telephony / phone-number flows.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS organization_caller_ai_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    kyc_status VARCHAR(50) DEFAULT 'not_started',
    kyc_approved_at TIMESTAMPTZ,
    kyc_approved_by UUID,
    kyc_rejection_reason TEXT,
    telephony_enabled BOOLEAN DEFAULT false,
    telephony_enabled_at TIMESTAMPTZ,
    telephony_provider TEXT NOT NULL DEFAULT 'exotel',
    -- Exotel
    exotel_account_sid VARCHAR(255),
    exotel_api_key VARCHAR(255),
    exotel_api_token TEXT,
    exotel_subdomain VARCHAR(255) DEFAULT 'api.in.exotel.com',
    exotel_app_id VARCHAR(255),
    exotel_is_active BOOLEAN DEFAULT true,
    -- Plivo
    plivo_auth_id TEXT,
    plivo_auth_token TEXT,
    plivo_is_active BOOLEAN NOT NULL DEFAULT false,
    plivo_application_id TEXT,
    -- Per-org "Assigned Key" voice/LLM provider keys (P4 option-c). On-prem the
    -- VM normally reads these from the check-in cache; these columns exist for
    -- the local-DB fallback path in db/org_config.py.
    cartesia_api_key TEXT,
    sarvam_api_key TEXT,
    google_api_key TEXT,
    -- Shared / misc
    campaign_flow_id VARCHAR(255),
    encrypted_config TEXT,
    created_by UUID,
    updated_by UUID,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_org_caller_ai_config_org UNIQUE (organization_id)
);

-- Upgrade path (audit SCH-01b): the on-prem backend can runtime-create a leaner/
-- older organization_caller_ai_config, so CREATE TABLE IF NOT EXISTS may have left
-- it without the columns the check-in fallback + telephony read. Bring it to the
-- full shape idempotently (keeps any existing rows; NOT NULL adds carry defaults).
ALTER TABLE organization_caller_ai_config
    ADD COLUMN IF NOT EXISTS kyc_status VARCHAR(50) DEFAULT 'not_started',
    ADD COLUMN IF NOT EXISTS kyc_approved_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS kyc_approved_by UUID,
    ADD COLUMN IF NOT EXISTS kyc_rejection_reason TEXT,
    ADD COLUMN IF NOT EXISTS telephony_enabled BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS telephony_enabled_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS telephony_provider TEXT NOT NULL DEFAULT 'exotel',
    ADD COLUMN IF NOT EXISTS exotel_account_sid VARCHAR(255),
    ADD COLUMN IF NOT EXISTS exotel_api_key VARCHAR(255),
    ADD COLUMN IF NOT EXISTS exotel_api_token TEXT,
    ADD COLUMN IF NOT EXISTS exotel_subdomain VARCHAR(255) DEFAULT 'api.in.exotel.com',
    ADD COLUMN IF NOT EXISTS exotel_app_id VARCHAR(255),
    ADD COLUMN IF NOT EXISTS exotel_is_active BOOLEAN DEFAULT true,
    ADD COLUMN IF NOT EXISTS plivo_auth_id TEXT,
    ADD COLUMN IF NOT EXISTS plivo_auth_token TEXT,
    ADD COLUMN IF NOT EXISTS plivo_is_active BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS plivo_application_id TEXT,
    ADD COLUMN IF NOT EXISTS cartesia_api_key TEXT,
    ADD COLUMN IF NOT EXISTS sarvam_api_key TEXT,
    ADD COLUMN IF NOT EXISTS google_api_key TEXT,
    ADD COLUMN IF NOT EXISTS campaign_flow_id VARCHAR(255),
    ADD COLUMN IF NOT EXISTS encrypted_config TEXT,
    ADD COLUMN IF NOT EXISTS created_by UUID,
    ADD COLUMN IF NOT EXISTS updated_by UUID;

CREATE INDEX IF NOT EXISTS idx_org_caller_ai_config_org ON organization_caller_ai_config(organization_id);

-- ---------------------------------------------------------------------------
-- Phone numbers assigned to an org (Exotel or Plivo). Drives caller-id lookup.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS organization_phone_numbers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    phone_number VARCHAR(32) NOT NULL,
    phone_number_normalized VARCHAR(32),
    provider TEXT NOT NULL DEFAULT 'exotel',
    -- Exotel
    exotel_phone_sid VARCHAR(255),
    exotel_app_id VARCHAR(255),
    -- Plivo
    plivo_number_id TEXT,
    plivo_application_id TEXT,
    friendly_name VARCHAR(255),
    status VARCHAR(32) DEFAULT 'active',
    assigned_by UUID,
    assigned_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_org_phone_numbers_org_number UNIQUE (organization_id, phone_number)
);

-- Upgrade path (audit SCH-01b): the backend can runtime-create an older
-- organization_phone_numbers without provider/status (which the lookup index +
-- caller-id resolution need). Add the missing columns idempotently before indexing.
ALTER TABLE organization_phone_numbers
    ADD COLUMN IF NOT EXISTS phone_number_normalized VARCHAR(32),
    ADD COLUMN IF NOT EXISTS provider TEXT NOT NULL DEFAULT 'exotel',
    ADD COLUMN IF NOT EXISTS exotel_phone_sid VARCHAR(255),
    ADD COLUMN IF NOT EXISTS exotel_app_id VARCHAR(255),
    ADD COLUMN IF NOT EXISTS plivo_number_id TEXT,
    ADD COLUMN IF NOT EXISTS plivo_application_id TEXT,
    ADD COLUMN IF NOT EXISTS friendly_name VARCHAR(255),
    ADD COLUMN IF NOT EXISTS status VARCHAR(32) DEFAULT 'active',
    ADD COLUMN IF NOT EXISTS assigned_by UUID,
    ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_org_phone_numbers_org ON organization_phone_numbers(organization_id);
CREATE INDEX IF NOT EXISTS idx_org_phone_numbers_lookup ON organization_phone_numbers(organization_id, provider, status);

-- ---------------------------------------------------------------------------
-- Caller-AI chatbot config (CSV/Google-Sheet campaign webhook wiring).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS caller_ai_chatbot_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    agent_id UUID NOT NULL,
    trigger_mode VARCHAR(50),
    webhook_url TEXT,
    webhook_secret TEXT,
    google_sheet_url TEXT,
    notes TEXT,
    created_by_user_id UUID,
    updated_by_user_id UUID,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_caller_ai_chatbot_configs_org_agent UNIQUE (organization_id, agent_id)
);

CREATE INDEX IF NOT EXISTS idx_caller_ai_chatbot_configs_org ON caller_ai_chatbot_configs(organization_id);

-- ---------------------------------------------------------------------------
-- Lightweight caller-AI agent record (legacy companion to caller_ai_agent_profiles).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS caller_ai_agent (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    answer_type VARCHAR(50) DEFAULT 'Yes/No',
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
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_caller_ai_agent_org UNIQUE (organization_id)
);

-- ---------------------------------------------------------------------------
-- Inbound contact / escalation config (transfer-to-agent fallback numbers).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS inbound_contact_info (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    agent_id UUID,
    new_request BOOLEAN NOT NULL DEFAULT true,
    phone_numbers TEXT[] NOT NULL DEFAULT '{}',
    email_addresses TEXT[] NOT NULL DEFAULT '{}',
    ring_timeout_seconds INTEGER NOT NULL DEFAULT 20,
    fallback_action TEXT NOT NULL DEFAULT 'hangup',
    webhook_url TEXT,
    escalation_action_type TEXT NOT NULL DEFAULT 'forward',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_inbound_contact_info_org_agent UNIQUE (organization_id, agent_id)
);

CREATE INDEX IF NOT EXISTS idx_inbound_contact_info_org ON inbound_contact_info(organization_id);
