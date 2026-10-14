-- E only. Prepared, not applied. Depends on 00001-00003; preserve B1/A-D.
-- Same terminal expression as cleanup discovery; no clock or interval in index.
-- PostgreSQL LEAST ignores NULL optional terminal marks.
-- +goose Up
SET LOCAL ROLE tp_owner;
SET LOCAL search_path TO pg_catalog;
CREATE INDEX idx_sessions_cleanup_terminal
ON identity.sessions ((LEAST(idle_expires_at, absolute_expires_at, revoked_at, expired_at)), session_id);

-- +goose Down
-- Disable/drain cleanup and remove E function first, in authorized disposable DB.
SET LOCAL ROLE tp_owner;
SET LOCAL search_path TO pg_catalog;
DROP INDEX identity.idx_sessions_cleanup_terminal;
