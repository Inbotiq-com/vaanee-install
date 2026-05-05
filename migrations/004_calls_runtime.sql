-- 004_calls_runtime.sql
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
