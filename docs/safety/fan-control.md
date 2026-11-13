# Fan control feasibility and recovery

## Device decision

Manual and curve control remain disabled on Mac16,7/M4 Pro with macOS 26.6.2. There is a documented mechanism for returning the fans to system control. ThermalDeck has yet to validate its own write path and handoff from an active override on this exact Mac. Control-grade sensing for live curves also remains unverified. Independent crash recovery is deferred at the owner's request. Behavior after an abrupt exit is unknown.

The installed Macs Fan Control 1.5.21 app and its root-owned fan-write helper are present. CrystalIDEA reports that M3/M4 MacBook Pro control returned in 1.5.18 and that normal Quit returns all fans to Auto. The vendor does not publish the helper's write or restoration contract, and its [documented command line](https://crystalidea.com/macs-fan-control/command-line) does not expose fan control. [Release notes](https://crystalidea.com/macs-fan-control/release-notes) · [Normal Quit behavior](https://crystalidea.com/macs-fan-control)

Open-source M4 research describes `Ftst` as a force/test flag in the system management controller. Setting it makes macOS's thermal manager yield fan control; clearing it lets macOS reclaim the fans. Implementations also release the per-fan manual settings they own. The handoff should be verified using the flag, both mode readings and measured RPM as the fans settle. A successful write alone does not establish that the fans are back under system control. [M4 SMC research](https://github.com/agoodkind/macos-smc-fan/blob/31a1feae0c4999ebd8cdddfbd90d2c98182091b8/docs/research.md#key-findings) · [MacFanControl ownership and restoration](https://github.com/raminsharifi/MacFanControl#safety-design)

The read-only probe on this Mac returned `F0Md = 3`, `F1Md = 3`, and `Ftst = 0`. Lowercase mode keys were absent. Raising a fan's minimum would let the system keep choosing the actual speed on hardware that supports it. On this Mac, the metadata for both minimum keys is `0x84`, without the known write bit (`0x40`); the mode and force/test keys returned `0xd0`. Metadata alone cannot prove that any write will be accepted. [Minimum speed behavior on another M4 model](https://github.com/beomwookang/macos-fan-control#what-the-smc-fan-keys-actually-do)

The repository's [development rules](../../AGENTS.md) prohibit diagnostic unlocks and privilege escalation during development. ThermalDeck has no hardware-write selector or privileged service. The next reference observation, if separately authorized, is to record both fans' actual RPM and mode plus `Ftst` during a user-controlled Full Blast followed by a normal Quit in the installed vendor app. That would establish the vendor handoff on this host without testing a ThermalDeck write. No real fan command or thermal stress was performed.

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

The simulator can apply one percentage curve to exactly two fans, converting each point using that fan's reported maximum. The curve editor's 0% endpoint represents 0 RPM. The simulator still requires each resulting target to meet the model's minimum and the current system cooling demand. In explicit Demo mode, Max Fans temporarily selects each fan's maximum. Turning it off restores the prior mode; if a prior curve is no longer safe, it falls back to Automatic. Normal Quit clears the override and selects Automatic directly.

## Prospective privilege and threat model

If a defensible pathway emerges, evaluate an embedded, minimally privileged daemon registered through SMAppService with an XPC listener. Validate a designated requirement that pins the intended signing team and app identifier against the connection. Missing or invalid signing identity fails closed. Audit identity, session ownership and authorization must be independent checks. Treat every message as untrusted. Keep the command surface to typed, bounded operations against fixed compatible fans. Reject arbitrary keys, arbitrary filesystem paths, untrusted executables, unknown enum cases, stale requests and concurrent owners.

A daemon must enforce trusted sensor reads, bounds, command rate limits, and verification. On normal Quit, restore each fan ThermalDeck owns and confirm system mode before terminating. Revoke authority on logout, sleep, shutdown, authorization change, service upgrade/uninstall or competing control. Startup may verify previously unconfirmed state. It must never reapply persisted manual commands. Independent fallback after a crash is a follow-up.

## First hardware write gate

Establish independently reviewed command, encoding, privilege, thermal-floor and normal-quit restoration semantics for the exact model and OS. Complete mock fault coverage and record a bounded test and restoration protocol. Obtain explicit user authorization for that test. Verify both applied mode and measured RPM within a bounded settle interval, then verify return of system mode on Quit. Long-duration testing follows after the bounded test succeeds.

Manual cooling can alter normal thermal behavior and may contribute to higher temperatures, instability, hardware damage or data loss. ThermalDeck uses undocumented read interfaces and is provided as is under the MIT license. Use is at your own risk. ThermalDeck has no affiliation with Apple.
