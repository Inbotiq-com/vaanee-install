-- 006_indexes_and_finalize.sql
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

DO $$ BEGIN
  RAISE NOTICE 'Vaanee client on-prem migration completed successfully.';
END $$;
