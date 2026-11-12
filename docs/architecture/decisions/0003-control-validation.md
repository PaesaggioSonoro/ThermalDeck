# ADR 0003 — Keep control simulation out of the application

Status: Accepted.

## Context

Upstream M4 control approaches rely on an undocumented diagnostic override. Independent restoration after helper termination has not been demonstrated on the target Mac. Physical telemetry is suitable for the mapped monitoring display only.

## Decision

Compile a strictly read-only AppleSMC transport. Put simulated control state and backend in the test graph. Share pure curve arithmetic with the offline editor. Do not register a daemon or expose writable IPC. Reconsider a narrow SMAppService/XPC boundary only after independent recovery and trusted sensor semantics are established. [Feasibility and threat model](../../safety/fan-control.md)

## Consequences

The production app has no privileged service to install, upgrade or remove. Automatic is the only active profile. Simulated tests describe the policy without establishing firmware behavior.
