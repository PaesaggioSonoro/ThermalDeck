# Fan control feasibility and recovery

## Device decision

Manual and curve control remain disabled on Mac16,7/M4 Pro with macOS 26.6.2. The physical read-only probe confirms two fans, firmware mode 3, and reported telemetry. It cannot prove a writable path or recovery. The reference M4 procedure uses an undocumented diagnostic override that can inhibit the normal thermal manager. Evidence for reliable fail-safe behavior if a privileged process dies with that override active is missing. The device also lacks a validated control-grade thermal sensor set and a reliable estimate of system cooling demand.

The follow-up comparison used the installed Macs Fan Control window as a second RPM display while the system controlled the fans. Read-only SMC checks on the same Mac returned `F0Md = 3`, `F1Md = 3`, and `Ftst = 0`. The lowercase mode keys were absent. The vendor reports M3/M4 control support without publishing a write and independent recovery contract. The comparison verified fan readings and left the write and recovery requirements open. [Macs Fan Control implementation discussion](https://github.com/crystalidea/macs-fan-control/issues/822) · [SMC research](https://github.com/agoodkind/macos-smc-fan/blob/31a1feae0c4999ebd8cdddfbd90d2c98182091b8/docs/research.md)

No real write test is proposed while those prerequisites are open. ThermalDeck has no write selector, service, privilege escalation, diagnostic override, or path from the app into the simulator. No real fan command or thermal stress was performed.

## State and restoration

The deterministic in-memory plant is driven with virtual monotonic time. Control starts only with an explicitly validated simulation, a complete fresh trusted input set, confirmed authority, and valid fan bounds. The simulated system demand is a floor for every target. Firmware limits alone would be insufficient.

```mermaid
stateDiagram-v2
    SystemManaged --> Preparing: validate and accept request
    Preparing --> ManualActive: verified readback
    Preparing --> CurveActive: verified curve readback
    CurveActive --> Preparing: next bounded target
    Preparing --> RestoringSystem: timeout or fault
    ManualActive --> RestoringSystem: automatic or fault
    CurveActive --> RestoringSystem: automatic or fault
    RestoringSystem --> SystemManaged: confirmed automatic
    RestoringSystem --> Faulted: confirmed restoration after fault
    RestoringSystem --> RecoveryRequired: any fan unconfirmed
    RecoveryRequired --> RestoringSystem: explicit retry
```

The simulated supervisor stops sending targets after stale, missing, invalid or future-dated inputs, read or write errors, mode/target divergence, changing capabilities, authority loss, or a missed lease deadline. It restores all owned fans and verifies readback. A competing controller's fan is reported as unconfirmed. A switch while settling triggers restoration and requires a fresh request. Wake never replays the previous profile.

The simulator can apply one percentage curve to exactly two fans, converting each point using that fan's reported maximum. The curve editor's 0% endpoint represents 0 RPM. The simulator still requires each resulting target to meet the model's minimum and the current system cooling demand.

## Prospective privilege and threat model

If a defensible pathway emerges, evaluate an embedded, minimally privileged daemon registered through SMAppService with an XPC listener. Validate a designated requirement that pins the intended signing team and app identifier against the connection. Missing or invalid signing identity fails closed. Audit identity, session ownership and authorization must be independent checks. Treat every message as untrusted. Keep the command surface to typed, bounded operations against fixed compatible fans. Reject arbitrary keys, arbitrary filesystem paths, untrusted executables, unknown enum cases, stale requests and concurrent owners.

A daemon must own leases, trusted sensor reads, bounds, command rate limits, verification and recovery independently of the app. An active app heartbeat must never be sufficient to sustain control. Revoke authority on disconnect, logout, sleep, shutdown, authorization change, service upgrade/uninstall or competing control. Startup may verify and recover previously unconfirmed state. It must never reapply persisted manual commands. Consider a separate independent watchdog or verifiable firmware lease before any persistent operation. Cleanup inside a process cannot handle that process's SIGKILL, kernel failure, or power loss. Simulation provides no evidence that the hardware can handle those cases.

## First hardware write gate

Establish independently reviewed command, encoding, privilege, thermal-floor and restoration semantics for the exact model and OS. Demonstrate independent recovery, complete mock fault coverage, and record a bounded test and restoration protocol. Only then request explicit user authorization for that exact test. Verify both applied mode and measured RPM within a bounded settle interval, then verify return of system mode. Long-duration testing follows only after the bounded test succeeds. Keep normal monitoring available throughout feasibility work.

Manual cooling can alter normal thermal behavior and may contribute to higher temperatures, instability, hardware damage or data loss. ThermalDeck uses undocumented read interfaces and is provided as is under the MIT license. Use is at your own risk. ThermalDeck has no affiliation with Apple.
