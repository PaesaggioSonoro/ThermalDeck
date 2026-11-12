# ThermalDeck

ThermalDeck is a native, offline macOS utility for thermal and fan monitoring. The name and bundle identifier are provisional.

## Build locally

On macOS with Swift 6 and a compatible Apple SDK, run:

```sh
Scripts/test.sh
Scripts/build-app.sh
open dist/ThermalDeck.app
```

The script packages and ad-hoc signs a local app. For explicit sample data, use `open -n dist/ThermalDeck.app --args --demo`. The deployment target is macOS 15. See [status](STATUS.md) for the tested host and [architecture](docs/architecture/overview.md) for component boundaries.
