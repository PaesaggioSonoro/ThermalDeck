# ADR 0003 — Keep fan control isolated from hardware

Status: Superseded by the authenticated maximum-only helper described in [fan control](../../safety/fan-control.md).

## Context

Upstream M4 control approaches rely on an undocumented diagnostic override. The write path and restoration on normal quit have not been demonstrated on the target Mac. Physical telemetry is suitable for the mapped monitoring display only.

## Decision

Compile a strictly read-only AppleSMC transport. Use the in-memory control backend in tests and the explicitly requested `--demo` session only. The regular launch does not instantiate a controller. Share pure curve arithmetic with the offline editor. Reconsider a narrow SMAppService/XPC boundary when the commands, normal-quit restoration, and trusted sensor semantics have been validated. Independent crash recovery is deferred. [Feasibility and threat model](../../safety/fan-control.md)

## Consequences

The app has no privileged service to install, upgrade or remove. Automatic is the only live profile. Demo controls and tests exercise the policy without establishing firmware behavior.
