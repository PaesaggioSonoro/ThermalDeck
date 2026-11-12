# Monitoring ThermalDeck

Overview shows the hottest available mapped CPU and GPU zones and measured fan speeds. Sensors shows raw firmware IDs and health. A dash means the value is unavailable. Fans shows measured RPM, firmware-reported target, limits, and mode. Zero RPM means the fan is stopped when the reading is live.

History records mapped peaks and measured fan speeds. Enable Battery or Targets in History to show those series. Change the time range and retention in Settings. Missing samples create chart gaps. History is in memory by default. Opt in to save a bounded five-second aggregate across launches. Use Clear History to remove current and saved data. Disabling saved history also removes the local archive. Collection can remain on independently. The archive is periodically checkpointed, so the most recent samples can be lost on exit.

Choose Celsius or Fahrenheit and a menu bar readout in Settings. Local alerts require opt-in and macOS notification permission. A high-temperature notification threshold is a personal setting. Alert policy uses the available mapped CPU/GPU peak, a cooldown and hysteresis.

Automatic leaves cooling to macOS. The Profiles page describes unavailable modes and offers a Custom editor for simulated input. Saved curves are local drafts. The Fans page reports actual firmware mode separately.

Login-item availability depends on the bundle and macOS. The local development bundle reported unavailable on the test host. Registration with a distribution build remains unverified.

Use Export in History to save retained samples as CSV or JSON. Exports use UTC timestamps, Celsius for temperatures and RPM for fans. Fan metric IDs are zero-based firmware indices. Missing readings have no exported value. Explicit demo exports carry a simulation flag. You choose where to save the file.
