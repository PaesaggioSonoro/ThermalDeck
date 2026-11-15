# Tasks

| ID | Work | State |
| --- | --- | --- |
| TD-00 | Environment, Git and recovery | Complete |
| TD-01 | Reference review, architecture and hardware boundary | Complete |
| TD-02 | Launchable native foundation | Complete |
| TD-03 | Temperature discovery, validation and polling | Complete, partial model mapping |
| TD-04 | Physical fan monitoring | Complete, stopped and spinning states observed |
| TD-05 | History, charts and notifications | Complete, policy tested |
| TD-06 | Control feasibility and simulation | Complete, simulated only |
| TD-07 | Validated hardware control and helper | Max Fans, Restore Automatic and normal-quit handoff physically verified on Mac16,7. Sleep/wake during an override remains unverified. |
| TD-08 | Profiles and offline curve editing | Complete, simulation only |
| TD-09 | UI and integration | Complete, local smoke tested |
| TD-10 | Reliability and performance | Complete, physical sleep/wake unverified |
| TD-11 | Optional advanced features | Export, display options, battery power, and local diagnostics complete. Update checking awaits a release endpoint. |
| TD-12 | Local release preparation | Complete, distribution gates pending |
| TD-13 | Sensor, menu bar, polling and shared percentage controls | Implemented and checked in the QA app |
| TD-14 | Maximum fan override and prior mode restoration | Verified in Demo and on the development Mac. Automatic is the only prior mode for live overrides. |
| TD-15 | Cooling shortcuts, selected sensor history and fan alerts | Implemented. Native notification delivery and the menu bar actions need installed testing. |
| TD-16 | Live curves and adjustable fan targets | Pending trusted control sensors and a validated cooling floor. Independent fan controls are deferred. |
| TD-17 | Discover and name more M4 Pro temperatures | AppleSMC and HID verified on Mac16,7. Additional probes are available in the diagnostic catalog. |
| TD-18 | Match the M4 Pro Sensors list to Macs Fan Control labels | 26 requested entries, with four efficiency-core labels sharing two sensor readings. |
| TD-19 | Match automatic menu bar temperatures to Sensors | Uses visible readings and the same precision. The dropdown identifies the source. |
| TD-20 | Group menu bar choices and revise Overview | Both slots support grouped sensor and fan readings. Overview prioritizes RPM and compares CPU and GPU peaks and averages. |
| TD-21 | Install the local fan helper from Overview | Package verified and native Installer review tested. Administrator installation through this flow remains to be verified. |
