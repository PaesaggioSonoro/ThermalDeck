# Changelog

## Unreleased (0.1.0 development)

### Added

- Native macOS dashboard, fan and sensor details, live charts, menu bar companion, and preferences.
- Unprivileged AppleSMC reading on the tested Mac16,7, including stopped-fan RPM and reported fan limits.
- Bounded in-memory history, optional aggregated local history, local alert policy, and a graphical offline curve editor.
- CSV and JSON history export, selectable menu bar fan, and dashboard chart visibility.
- Battery charge, source, charging state, and power flow where supported.
- A local, reviewable compatibility report.
- Sensor sorting, optional zone grouping, and per-sensor visibility.
- A sidebar Menu Bar page for two live values and a gear next to the Mac model.
- Half-second dashboard polling and a shared percentage curve preview for both fans.
- Deterministic fan-control simulation, fault coverage, and local app packaging.

### Fixed

- Preference edits could recurse and terminate the app. Settings now normalize changes before writing them.
- The menu bar uses a text label when live values are selected.

### Known limitations

- M4 Pro zone mappings are partial. Other hardware and macOS versions need validation.
- Automatic is the only live profile. Manual fan control and automatic curve execution are disabled.
- Developer ID distribution, notarization and physical compatibility beyond the recorded host remain pending.
