# ADR 0002 — Versioned preferences and bounded local history

Status: Accepted.

## Context

Monitoring should operate offline, and a failed configuration read must not cause unsafe restoration or unbounded storage.

## Decision

Use a versioned Codable preferences document in the app's UserDefaults domain. Normalize supported values. If the schema is unknown or corrupt, use defaults for the session and preserve the stored configuration. New optional fields are backward compatible with schema 1.

Keep timestamped samples in memory, limited by age and count. An opt-in, versioned JSON archive records five-second aggregates. Preserve gaps in the aggregated series. Use atomic writes and revision ordering so a stale save cannot recreate a cleared archive. Validate archive size and scope on read. Store curve definitions as drafts and leave real fan state unpersisted.

## Consequences

Preferences and monitoring history stay on the Mac. Disk data can lag live history between periodic writes. A damaged or newer history file requires an explicit clear before replacement. No accounts or external database are needed.
