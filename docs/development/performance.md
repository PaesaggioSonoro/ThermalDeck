# Monitoring measurements

Read-only checks on Mac16,7, Apple M4 Pro, macOS 26.6.2 (25G83), native arm64 debug build. No thermal stress or fan writes were involved. Results are short, local samples.

- The probe returned 20 usable snapshots at one-second intervals. Cold read time was 7.524 ms. The 19 warm reads had 4.987 ms median, 5.800 ms 95th percentile and 5.800 ms peak.
- The visible Overview with a live chart used 2.88% mean process CPU, 5.30% peak, and 105.5 MiB mean RSS in twelve one-second `ps` samples. Later, after the dashboard closed, twelve samples showed 0.31% mean CPU, 2.20% peak, and 127.6 MiB mean RSS. The same process retained allocations from the earlier window. These figures are process snapshots and do not isolate chart rendering or establish a memory trend.
- Unified logs showed one-second sampling while the dashboard was visible and five-second sampling with it closed. The same process remained running and displayed retained history after reopening.
- Live history is bounded by 3,600 records and the selected time retention. The archive is bounded by 721 five-second buckets and a 2 MB size limit. Battery impact and long-duration memory behavior have not been measured.

Reproduce read latency with `Scripts/swift-tool.sh run thermal-probe --timing 20`. For process snapshots, run `ps -p PID -o %cpu=,rss=` once per second for the same interval with Overview visible and again after closing it. Capture the monitoring category at info level using `log stream` to verify cadence. Repeat in a Release build and compare History against a non-chart page to isolate rendering. Use Instruments for allocations, time profiling and power measurements.

Physical sleep/wake and notification delivery remain integration test items. The app cancels polling, clears visible measurements and inserts a history gap at sleep. It discards the AppleSMC connection and takes a fresh sample on wake. The firmware and fan state remain under the system's authority.
