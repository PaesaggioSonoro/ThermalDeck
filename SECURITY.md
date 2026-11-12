# Security policy

ThermalDeck is in local development. There are currently no published supported versions or configured private vulnerability contact. When the repository is published, its owner should enable a private vulnerability reporting channel and update this policy. Until then, share a minimal report privately with the project owner through your existing contact channel.

Include the commit, model identifier, OS build, affected operation and minimal reproduction. Avoid public posts containing security-sensitive reproductions, machine serials, private log data, account identifiers, signing material or filesystem paths.

The current app opens AppleSMC for reads as the logged-in user. It ships no privileged helper, fan-write pathway, network client or telemetry service. The C request layout, sensor classification, local history, bundle distribution and any future authenticated IPC merit security review. [Fan control threat model](docs/safety/fan-control.md)
