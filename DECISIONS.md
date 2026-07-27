# Architecture Decisions

Short records of the choices that shaped the working system, and why.

## 1. One canonical data model: documents, with an EAV view for export

The repository contained two incompatible response models that had never run
together:

- an **entity-attribute-value** `responses` table (one row per answer) used by
  the R runtime (`database.R`, `storage.R`, `export.R`), and
- a **document** store (one JSONB blob per completed form) assumed by the REST
  API (`server.R`) and the offline PWA layer (`indexeddb.js`).

Neither was wrong; the seam between them had simply never been exercised. The
API even queried tables (`surveys`, `questions`) that the migration never
created.

**Decision:** the document model is canonical (`submissions` table), and the EAV
shape is exposed as a read-only SQL view (`answers`).

**Why:** in field collection the unit that syncs is a *completed form*, not an
individual answer. A document row makes offline retries idempotent (one client
id, `ON CONFLICT DO UPDATE`) and means a partial sync can never leave half a
form in the database. The `answers` view (`jsonb_each_text`) still gives the R
export/analysis path the long format it expects, so both halves' work is
preserved and neither was rewritten wholesale.

See `database/migrations/002_submissions.sql`.

## 2. Pinned R 4.4 in Docker as the only supported runtime

The package declares `R (>= 4.0.0)` but is commonly run against distro R 3.6,
where it cannot even be installed (missing packages, no libpq). Rather than
support an impossible matrix, the runtime is a pinned `rocker/r-ver:4.4.0`
image. Docker is therefore not a convenience — it is the supported way to run
NomadForms. This also happens to be the deployment artifact.

## 3. Optional dependencies are Suggests, not Imports

`shiny` is used only by the legacy Shiny/Quarto demo path, not by mobile
collection; `plumber` only by the API process. Both moved to `Suggests` with a
`requireNamespace()` guard, so the core package installs lean and the container
stays small. Heavy export backends (`haven` for Stata/SPSS) are likewise
optional and guarded.

## 4. Submissions are durable before they are sent

The mobile client writes every submission to IndexedDB **first**, then attempts
to sync. Nothing depends on network success at submit time. Sync happens on
submit, on reconnect, and on a 30-second timer, and is idempotent, so a flaky
field connection can retry freely without double-counting. The service worker
never caches `/api/*` responses, so stale data can never be shown as if it were
live.

## 5. CSV built without a serializer dependency

Plumber's built-in `csv` serializer requires `readr`. To avoid pulling it in,
the export endpoint serializes with base R (`write.csv` to a text connection)
under a `contentType` serializer. CSV and wide-JSON are the two export formats
shipped; Stata/SPSS/R remain available through the R package's `export.R`
(guarded by `haven`) but are not wired to an HTTP endpoint yet.

## 6. Auth is an optional filter, off by default

An `X-API-Key` filter gates write endpoints, but only when `API_KEY` is set.
Local development and the LAN demo stay friction-free; production locks down by
setting one environment variable. This is deliberately minimal — it is a shared
deployment key, not per-user auth. Real multi-user roles (the `users` table
exists but is not yet enforced) are the main gap before wider rollout.
