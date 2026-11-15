# Monitoring ThermalDeck

Overview shows the hottest available mapped CPU and GPU zones and measured fan speeds. Sensors shows the name and temperature of each reading. Choose Name or Temperature to sort alphabetically or hottest first. Group by zone sorts within each hardware section. Use Sensor Visibility to hide individual rows. Hidden sensors remain available for monitoring, History and the menu bar. A dash means the value is unavailable. Fans shows measured RPM, firmware-reported target, limits, and mode. Zero RPM means the fan is stopped when the reading is live.

On supported Macs, Overview also shows the internal battery's charge level, power source, charging state, and estimated battery power flow. The watts shown describe flow into or out of the battery. The Mac can draw power from its adapter while battery flow reads 0 W. Battery power readings appear live and are omitted from history and exports.

History records mapped peaks and measured fan speeds. Enable Battery or Targets in History to show those series. Change the time range and retention in Settings. Missing samples create chart gaps. History is in memory by default. Opt in to save a bounded five-second aggregate across launches. Use Clear History to remove current and saved data. Disabling saved history also removes the local archive. Collection can remain on independently. The archive is periodically checkpointed, so the most recent samples can be lost on exit.

Choose Menu Bar in the sidebar to show up to two live values using the two selectors side by side. Each slot can show a specific sensor, the highest mapped temperature, the highest CPU or GPU temperature, or a fan speed. The monochrome logo appears to the left of one reading and between two readings. Select None for the first value to clear both readings and show the logo by itself. macOS decides which status items fit in the available space.

Open Settings with the gear beside the Mac model to choose Celsius or Fahrenheit and a dashboard interval. A visible, active dashboard can poll every 0.5 seconds. Background polling uses an interval of at least 1 second. Local alerts require opt-in and macOS notification permission. A high-temperature notification threshold is a personal setting. Alert policy uses the available mapped CPU/GPU peak, a cooldown and hysteresis.

Automatic leaves cooling to macOS. The Custom editor previews one percentage curve for both fans using simulated input. For each fan, 0% represents 0 RPM and 100% represents its reported maximum. Earlier RPM drafts can be converted when the two reported maxima match and the draft fits that range. Saved curves are local drafts. The Fans page reports actual firmware mode separately.

With the [local fan helper installed](../../README.md), Max Fans in Overview and the menu bar sets both fans to their respective maxima. Choose Restore Automatic in Overview or Use Automatic in Profiles or the menu bar to return cooling to macOS. Normal Quit waits for the helper to confirm that macOS regained control. If the helper cannot confirm the handoff, the app stays open so you can retry. Live control was verified on the 16-inch M4 Pro MacBook Pro (Mac16,7) on macOS 26.6.2 build 25G83.

In History, use Tracked Sensors to record up to four individual temperatures from the time you select them. Their readings appear in the chart and in CSV and JSON exports. Local notifications, when enabled, also report an unexpected end to Max Fans, a lost helper connection during an override, and an unconfirmed return to Automatic.

Run `open -n dist/ThermalDeck.app --args --demo` to try cooling controls with sample data. In Demo, you can also run a saved curve from Profiles. Turning off Max Fans returns to the previous Demo mode, which can be Automatic or a saved curve.

Login-item availability depends on the bundle and macOS. The local development bundle reported unavailable on the test host. Registration with a distribution build remains unverified.

Use Export in History to save retained samples as CSV or JSON. Exports use UTC timestamps, Celsius for temperatures and RPM for fans. Fan metric IDs are zero-based firmware indices. Missing readings have no exported value. Explicit demo exports carry a simulation flag. You choose where to save the file.

To describe a compatibility issue, choose Review Compatibility Report on the Compatibility page. The preview shows the app version, Mac model, chip, macOS version, and which telemetry is available. It leaves out readings, history, and serial numbers. Select and copy the fields you want to share.
