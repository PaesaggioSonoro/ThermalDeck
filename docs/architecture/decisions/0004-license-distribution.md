# ADR 0004 — MIT source and local packaging

Status: Accepted for local development.

## Context

The independently implemented application uses Apple SDK frameworks and no bundled third-party libraries. The working product name is provisional and release signing credentials were outside the development environment.

## Decision

Use MIT for project code and original icon, with collective attribution to ThermalDeck contributors. Build reproducibly from the Swift package and ad-hoc sign development bundles. Prepare an opt-in Developer ID and notarization script for an authorized release operator. Distribute an arm64 app ZIP once the public name, compatibility claims and signing are verified. A future Homebrew cask can install the app bundle.

## Consequences

Local builds need no signing account. Publication requires the owner to select a name, validate the distribution path and configure a private security channel. [Release steps](../../releases/distribution.md)
