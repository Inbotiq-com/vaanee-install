-- ============================================================
-- Vaanee On-Premise Migration Script
-- Run this against your PostgreSQL database before starting Vaanee
-- Usage: psql "$DATABASE_URL" -f migrate.sql -v ON_ERROR_STOP=0
-- ============================================================

-- ============================================================
-- TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    email VARCHAR UNIQUE NOT NULL,
    password_hash VARCHAR,
    first_name VARCHAR,
    last_name VARCHAR,
    is_active BOOLEAN DEFAULT true,
    is_admin BOOLEAN DEFAULT false,
    user_type VARCHAR DEFAULT 'user',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS admins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    email VARCHAR UNIQUE NOT NULL,
    password_hash VARCHAR,
    first_name VARCHAR,
    last_name VARCHAR,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS agents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id),
    name VARCHAR NOT NULL,
    description TEXT,
    agent_type VARCHAR,
    is_active BOOLEAN DEFAULT true,
    is_available_for_purchase BOOLEAN DEFAULT false,
    n8n_workflow_ids JSONB,
    settings_schema JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR NOT NULL,
    plan_tier VARCHAR DEFAULT 'standard',
    max_agents_allowed INTEGER DEFAULT 50,
    max_concurrent_calls INTEGER DEFAULT 10,
    price NUMERIC,
    billing_cycle VARCHAR,
    currency VARCHAR DEFAULT 'INR',
    description TEXT,
    features JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    plan_id UUID,
    subscription_plan_id UUID,
    agent_id UUID,
    agent_type VARCHAR,
    status VARCHAR NOT NULL DEFAULT 'active',
    subscription_status VARCHAR DEFAULT 'active',
    is_active BOOLEAN DEFAULT true,
    auto_renew BOOLEAN DEFAULT true,
    started_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    razorpay_subscription_id VARCHAR,
    razorpay_status VARCHAR,
    purchased_users_count INTEGER DEFAULT 0,
    subscription_plan_name VARCHAR,
    plan_name VARCHAR,
    price NUMERIC DEFAULT 0,
    currency VARCHAR DEFAULT 'INR',
    billing_cycle VARCHAR DEFAULT 'monthly',
    max_users INTEGER DEFAULT 50,
    trial_ends_at TIMESTAMPTZ,
    next_billing_date TIMESTAMPTZ,
    payment_method VARCHAR,
    failure_count INTEGER DEFAULT 0,
    expiry_status VARCHAR,
    last_payment_at TIMESTAMPTZ,
    last_payment_amount NUMERIC,
    paused_at TIMESTAMPTZ,
    resumed_at TIMESTAMPTZ,
    cancelled_reason TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS subscription_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    subscription_id UUID,
    agent_id UUID,
    plan_id UUID,
    razorpay_subscription_id VARCHAR,
    razorpay_status VARCHAR,
    subscription_status VARCHAR DEFAULT 'active',
    status VARCHAR DEFAULT 'active',
    is_active BOOLEAN DEFAULT true,
    assigned_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    start_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    end_date TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_agent_access (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    agent_id UUID NOT NULL,
    organization_id UUID NOT NULL REFERENCES organizations(id),
    can_view BOOLEAN DEFAULT true,
    can_edit BOOLEAN DEFAULT false,
    can_delete BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS organization_billing_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    billing_email VARCHAR,
    company_name VARCHAR,
    address_line1 VARCHAR,
    address_line2 VARCHAR,
    city VARCHAR,
    state VARCHAR,
    country VARCHAR,
    postal_code VARCHAR,
    gst_number VARCHAR,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS agent_schema_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    schema JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS organization_kyc_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    document_type VARCHAR,
    document_name VARCHAR,
    document_url VARCHAR,
    file_size_bytes BIGINT,
    status VARCHAR DEFAULT 'pending',
    rejection_reason TEXT,
    uploaded_at TIMESTAMPTZ,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS phone_number_provisioning_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    phone_number VARCHAR,
    status VARCHAR DEFAULT 'pending',
    requested_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS phone_number_purchase_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    phone_number VARCHAR,
    status VARCHAR DEFAULT 'pending',
    razorpay_order_id VARCHAR,
    razorpay_subscription_id VARCHAR,
    amount NUMERIC DEFAULT 0,
    currency VARCHAR DEFAULT 'INR',
    requested_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    provisioned_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS organization_phone_numbers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    phone_number VARCHAR NOT NULL,
    friendly_name VARCHAR,
    status VARCHAR DEFAULT 'active',
    assigned_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS caller_ai_chatbot_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    is_enabled BOOLEAN DEFAULT true,
    config JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS caller_ai_agent (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id),
    name VARCHAR,
    config JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS caller_ai_agent_flows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL,
    organization_id UUID REFERENCES organizations(id),
    flow_schema JSONB,
    version INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS caller_ai_agent_flow_published (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL,
    organization_id UUID REFERENCES organizations(id),
    flow_schema JSONB,
    version INTEGER DEFAULT 1,
    published_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS caller_ai_agent_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL,
    organization_id UUID REFERENCES organizations(id),
    profile JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS caller_ai_campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id),
    agent_id UUID,
    name VARCHAR,
    description TEXT,
    status VARCHAR DEFAULT 'pending',
    source_type VARCHAR,
    config JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS organization_caller_ai_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    config JSONB,
    is_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS vaanee_package_licences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    subscription_id UUID NOT NULL DEFAULT gen_random_uuid(),
    api_key_hash TEXT NOT NULL DEFAULT 'vaanee_default',
    api_key_prefix TEXT NOT NULL DEFAULT 'vaan_live',
    api_key_issued_at TIMESTAMPTZ DEFAULT now(),
    licence_status TEXT NOT NULL DEFAULT 'active',
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
-- ALTER TABLES - Add missing columns safely
-- ============================================================

ALTER TABLE admins ADD COLUMN IF NOT EXISTS admin_id UUID;
ALTER TABLE admins ADD COLUMN IF NOT EXISTS is_temporary_password BOOLEAN DEFAULT false;

ALTER TABLE users ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_changed_at TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_temporary_password BOOLEAN DEFAULT false;

ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS subscription_plan_id UUID;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS agent_id UUID;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS agent_type VARCHAR;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS auto_renew BOOLEAN DEFAULT true;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS start_date TIMESTAMPTZ;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS end_date TIMESTAMPTZ;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS razorpay_subscription_id VARCHAR;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS razorpay_status VARCHAR;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS subscription_status VARCHAR DEFAULT 'active';
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS purchased_users_count INTEGER DEFAULT 0;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS plan_name VARCHAR;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS expiry_status VARCHAR;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS failure_count INTEGER DEFAULT 0;

ALTER TABLE subscription_plans ADD COLUMN IF NOT EXISTS plan_tier VARCHAR DEFAULT 'standard';
ALTER TABLE subscription_plans ADD COLUMN IF NOT EXISTS max_agents_allowed INTEGER DEFAULT 50;
ALTER TABLE subscription_plans ADD COLUMN IF NOT EXISTS max_concurrent_calls INTEGER DEFAULT 10;
ALTER TABLE subscription_plans ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE subscription_plans ADD COLUMN IF NOT EXISTS currency VARCHAR DEFAULT 'INR';

ALTER TABLE subscription_assignments ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE subscription_assignments ADD COLUMN IF NOT EXISTS start_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE subscription_assignments ADD COLUMN IF NOT EXISTS end_date TIMESTAMPTZ;
ALTER TABLE subscription_assignments ADD COLUMN IF NOT EXISTS plan_id UUID;
ALTER TABLE subscription_assignments ADD COLUMN IF NOT EXISTS razorpay_subscription_id VARCHAR;
ALTER TABLE subscription_assignments ADD COLUMN IF NOT EXISTS razorpay_status VARCHAR;
ALTER TABLE subscription_assignments ADD COLUMN IF NOT EXISTS subscription_status VARCHAR DEFAULT 'active';

ALTER TABLE organization_kyc_documents ADD COLUMN IF NOT EXISTS document_name VARCHAR;
ALTER TABLE organization_kyc_documents ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
ALTER TABLE organization_kyc_documents ADD COLUMN IF NOT EXISTS uploaded_at TIMESTAMPTZ;
ALTER TABLE organization_kyc_documents ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;
ALTER TABLE organization_kyc_documents ADD COLUMN IF NOT EXISTS file_size_bytes BIGINT;

ALTER TABLE phone_number_purchase_orders ADD COLUMN IF NOT EXISTS razorpay_order_id VARCHAR;
ALTER TABLE phone_number_purchase_orders ADD COLUMN IF NOT EXISTS razorpay_subscription_id VARCHAR;
ALTER TABLE phone_number_purchase_orders ADD COLUMN IF NOT EXISTS requested_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE phone_number_purchase_orders ADD COLUMN IF NOT EXISTS provisioned_at TIMESTAMPTZ;
ALTER TABLE phone_number_purchase_orders ADD COLUMN IF NOT EXISTS amount NUMERIC DEFAULT 0;
ALTER TABLE phone_number_purchase_orders ADD COLUMN IF NOT EXISTS currency VARCHAR DEFAULT 'INR';

-- ============================================================
-- UNIQUE CONSTRAINTS
-- ============================================================

ALTER TABLE agents DROP CONSTRAINT IF EXISTS agents_name_unique;
ALTER TABLE agents ADD CONSTRAINT agents_name_unique UNIQUE (name);

ALTER TABLE caller_ai_chatbot_configs DROP CONSTRAINT IF EXISTS caller_ai_chatbot_configs_org_unique;
ALTER TABLE caller_ai_chatbot_configs ADD CONSTRAINT caller_ai_chatbot_configs_org_unique UNIQUE (organization_id);

ALTER TABLE organization_caller_ai_config DROP CONSTRAINT IF EXISTS org_caller_ai_config_org_unique;
ALTER TABLE organization_caller_ai_config ADD CONSTRAINT org_caller_ai_config_org_unique UNIQUE (organization_id);

ALTER TABLE organization_kyc_documents DROP CONSTRAINT IF EXISTS org_kyc_org_id_unique;
ALTER TABLE organization_kyc_documents ADD CONSTRAINT org_kyc_org_id_unique UNIQUE (organization_id, document_type);

-- ============================================================
-- SEED DATA - Default Caller AI plan
-- ============================================================

INSERT INTO subscription_plans (name, plan_tier, max_agents_allowed, price, billing_cycle, is_active)
VALUES ('Caller AI Standard', 'standard', 50, 0, 'monthly', true)
ON CONFLICT DO NOTHING;
