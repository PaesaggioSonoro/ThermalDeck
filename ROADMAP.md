# Roadmap

1. Establish the local workspace and record source and device evidence (TD-00–01).
2. Ship a native shell and verify temperatures and measured fan RPM on the development Mac (TD-02–04).
3. Add bounded history, charts and alerts (TD-05).
4. Verify the maximum-only helper on the development Mac (complete), then verify sleep and wake during an override (TD-06–07). Crash recovery is deferred.
5. Complete offline profile editing and the monitoring interface (TD-08–09).
6. Measure reliability and performance, then prepare offline advanced features and release documentation (TD-10–12).

See TASKS.md and STATUS.md for current progress.

The local monitoring path includes battery charge and power flow where supported. Release gates are listed in [distribution](docs/releases/distribution.md). Hardware control remains conditional on the [control feasibility requirements](docs/safety/fan-control.md). Update checks depend on an established release endpoint.

The monitoring controls include cooling shortcuts, individual sensor history and fan control alerts. The M4 Pro list presents 26 temperature entries and draws on two firmware banks for the ten performance cores. Live curves and adjustable fan targets depend on a verified cooling floor and control sensors.
