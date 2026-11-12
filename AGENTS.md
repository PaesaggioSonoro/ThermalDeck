# ThermalDeck development

This repository contains a native macOS thermal and fan monitor. The current app is read-only.

On resumption, confirm the working directory, Git branch, status and recent commits. Read STATUS.md, TASKS.md, ROADMAP.md, relevant ADRs and optional .local/agent-recovery notes. Preserve unfinished changes, inspect the next task and establish a build/test baseline before editing.

Use Swift 6 and the macOS 15 deployment target. Build with `Scripts/build-app.sh` and test with `Scripts/test.sh`. See README.md for app packaging and launch once the application target is present.

Never perform experimental hardware writes, diagnostic unlocks, thermal stress tests, privilege escalation or security changes. A first real fan write requires a validated, reviewed pathway and explicit user authorization for a specific test. Keep monitoring unprivileged and independent. Do not sign with private credentials or publish, add a remote, or push.

Verify each milestone, update tracked progress and local recovery notes, and make focused conventional commits without agent attribution. Keep device identifiers other than model and chip, logs, credentials, and research checkouts under ignored local storage.
