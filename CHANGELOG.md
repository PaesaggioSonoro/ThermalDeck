# Changelog

## Unreleased (0.1.0 development)

### Added

- Native macOS dashboard, fan and sensor details, live charts, menu bar companion, and preferences.
- Unprivileged AppleSMC reading on the tested Mac16,7, including stopped-fan RPM and reported fan limits.
- Bounded in-memory history, optional aggregated local history, local alert policy, and a graphical offline curve editor.
- CSV and JSON history export, selectable menu bar fan, and dashboard chart visibility.
- Battery charge, source, charging state, and power flow where supported.
- A local, reviewable compatibility report.
- Sensor sorting, optional zone grouping, zone icons, and per-sensor visibility.
- A sidebar Menu Bar page for two live values and a gear next to the Mac model.
- Half-second dashboard polling and a shared percentage curve preview for both fans.
- Deterministic fan-control simulation, fault coverage, and local app packaging.
- An Overview Max Fans toggle and saved curve activation in Demo mode. Turning off Max Fans restores the prior demo cooling mode.
- A signed helper path for live Max Fans and verified Auto on Quit. Physical validation is pending on Mac16,7 with macOS 26.6.2.
- Administrator installation of the local fan helper without an Apple Developer membership.

### Fixed

- Preference edits could recurse and terminate the app. Settings now normalize changes before writing them.
- The menu bar keeps a monochrome logo visible alongside live values. Its settings page previews all layouts and requires a first value before a second can be selected.
- The two Menu Bar selectors sit side by side.

### Known limitations

- M4 Pro zone mappings are partial. Other hardware and macOS versions need validation.
- Live control is limited to Max Fans and Automatic on the supported Mac with an approved helper. Curves run in Demo.
- Developer ID distribution, notarization and physical compatibility beyond the recorded host remain pending.
