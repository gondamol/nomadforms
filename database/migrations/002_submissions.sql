-- Migration 002: Reconcile to a single canonical data model
-- Version: 002
-- Date: 2026-07-23
--
-- The repository shipped two incompatible response models that had never run
-- together: an entity-attribute-value `responses` table (one row per answer)
-- used by the R runtime, and a document-shaped store (one JSONB blob per
-- completed form) assumed by the REST API and the offline PWA layer.
--
-- For field data collection the unit that syncs is a *completed form*, not an
-- individual answer -- that is what makes offline retries idempotent and
-- conflict resolution tractable. So the document model is canonical here.
-- The EAV shape is preserved as a read-only VIEW (`answers`) so the R export
-- and analysis path keeps working unchanged.
--
-- The old EAV `responses` table never held data (the schema was never deployed
-- before this migration), so dropping it loses nothing.

-- Detach the sync queue FK before dropping the table it points at.
ALTER TABLE sync_queue DROP CONSTRAINT IF EXISTS sync_queue_response_id_fkey;

DROP TABLE IF EXISTS responses CASCADE;

-- Canonical submission store: one row per completed form.
CREATE TABLE IF NOT EXISTS submissions (
    -- Client-generatable so an offline device can assign the id before it ever
    -- reaches the server; that id is what makes sync idempotent (ON CONFLICT).
    response_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    survey_id      TEXT NOT NULL,
    project_id     UUID REFERENCES projects(id) ON DELETE SET NULL,
    session_id     TEXT NOT NULL,
    participant_id TEXT,
    response_data  JSONB NOT NULL DEFAULT '{}'::jsonb,
    device_info    JSONB DEFAULT '{}'::jsonb,
    is_offline     BOOLEAN DEFAULT FALSE,
    status         TEXT NOT NULL DEFAULT 'submitted'
                   CHECK (status IN ('submitted', 'approved', 'rejected', 'deleted')),
    submitted_at   TIMESTAMPTZ DEFAULT NOW(),
    synced_at      TIMESTAMPTZ,
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    updated_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_submissions_survey    ON submissions(survey_id);
CREATE INDEX IF NOT EXISTS idx_submissions_session   ON submissions(session_id);
CREATE INDEX IF NOT EXISTS idx_submissions_submitted ON submissions(submitted_at);
CREATE INDEX IF NOT EXISTS idx_submissions_status    ON submissions(status);
-- GIN index makes "find submissions where answer to Q = X" fast.
CREATE INDEX IF NOT EXISTS idx_submissions_data_gin  ON submissions USING GIN (response_data);

CREATE TRIGGER update_submissions_updated_at
    BEFORE UPDATE ON submissions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- EAV projection for the R export/analysis path. Each answer in a submission's
-- JSONB becomes one long-format row (question_id, response_value).
CREATE OR REPLACE VIEW answers AS
SELECT
    s.response_id    AS submission_id,
    s.survey_id,
    s.project_id,
    s.session_id,
    s.participant_id,
    s.submitted_at,
    s.status,
    kv.key           AS question_id,
    kv.value         AS response_value
FROM submissions s,
     LATERAL jsonb_each_text(s.response_data) AS kv(key, value)
WHERE s.status <> 'deleted';

-- Re-point the sync queue at the new canonical table.
ALTER TABLE sync_queue
    ADD CONSTRAINT sync_queue_response_id_fkey
    FOREIGN KEY (response_id) REFERENCES submissions(response_id) ON DELETE CASCADE;

-- The audit log's FK to the old EAV table was dropped by the CASCADE above;
-- re-point it at the canonical submission store.
ALTER TABLE audit_log
    ADD CONSTRAINT audit_log_response_id_fkey
    FOREIGN KEY (response_id) REFERENCES submissions(response_id) ON DELETE SET NULL;

COMMENT ON TABLE submissions IS 'Canonical document-model store: one row per completed form';
COMMENT ON VIEW  answers     IS 'EAV projection of submissions for long-format export/analysis';
