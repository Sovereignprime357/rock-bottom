# Independent bounded review — 2026-11-19

Read-only review of the driver, copied probe, contract and live Adapter; no engine/Git or
production edits. No remaining concrete blocker found after the owner corrected the test
issue below. This is not native survival/performance evidence.

The original test runner could print PASS after a group aborted with a GDScript runtime
error. Its dynamically assigned literals also targeted typed `Array[Dictionary]` properties
(`f.host.npcs` and `f.space.peers`), a known runtime type hazard. Owner changed both to
`.assign(...)` and added four completion counters. The driver/probe were not changed by this
correction. Central parsing/contract execution remains required.

The measured Scene class matches the current tracked class exactly after newline
normalization. Its normalized class text ending in one newline hashes to
`3b5eaf2ee0a6a94b283c0d7bd360cb4bc8226748c82ca15b9a8e3bc6d1c58d27`, matching BASELINE.json.
Driver/controller/evidence work occurs after the timer is captured and before the next
sample. It remains inside full frame intervals and the held engine-process monitor, whose
semantics are correctly disclosed. Query subtraction uses the actual Adapter query counter
around measured `_drive` calls, not an assumed one-query-per-candidate count. The34 bound is
on movement API calls; each call can perform multiple bounded physical queries.

The queried player body is detached. The player branch never enters NPC navigation
`note_motion`; its placement certificates are cleared by the next production
`begin_navigation_frame`. Live actor contacts, walls, source input deadzone, speed, shakes,
stun, damage and arrest remain authoritative. Only the original premeasurement seed/day,
wanted setup and one physically validated placement write source fields. No HP refill,
invulnerability, actor insertion/removal, extra source AI steps or lifecycle repair was found.

Death/arrest/epoch events invalidate the driver, preserve the failure and exclude the
relocation delta from walked metres. Each measured frame still counts live/supported/rigged
actors; failed population cannot be repaired by the controller. Both1080-frame windows and
the unchanged16ms limits remain. Run precisely the same externally hashed driver/probe on
both8bcd and648 snapshots; the old fixed-route workload is not a valid paired comparison.
