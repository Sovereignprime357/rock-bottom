# 3D robbery — P11a

Status: specified before implementation, 2026-11-18. Scope is the shipped
`src/systems/robbery.js` transaction and its real grabber integration. Other
heists/break-ins remain separate incomplete packets.

`RobberySystem` borrows the single GameState via WeakRef. Runtime exposes
`attempt_robbery(actor)` to the existing Combat/Director domain seam. Only a
live `robs:true` actor may spend this transaction, after the source landed grab.
No new hit, timer, damage, sound, recovery reward or random resistance roll.

The governor is `(day + dayTime) * 240000`, with a 60000ms cooldown and two
attempts per day. Existing persisted counters own both values; DaySystem owns
the daily reset. Even empty pockets consume one attempt. No candidate means no
RNG consumption; otherwise the exact ordered candidates are ordinary clothing
in coat/hat/shoes order, allowlisted inventory records in source order, hitter,
then cash. A stack is one candidate and loses one unit. Cash uses a second RNG
draw, inclusive 5..15 capped at current cash. Source allowlists are copied
literally; unknown items, rocks, bus pass, crossword, package, uniques and tools
remain protected by default. Equipment loss clears the actual slot and applies
existing equipment stats before publication and save.

Committed outcomes emit the exact ledger toast, equipment-only feed post and
one save request. Events are consumed by the shared presentation/feed/save
owners; the robbery module has no IO. Restored counters preserve cooldown;
world-clock advancement, including sleep, is authoritative.

Verification: execute the unchanged JavaScript module to capture source cases
for every loss class, ordering, boundary, empty pockets, protected items,
stack decrement, cash cap and cooldown/daily cap. Compare GDScript resources,
RNG draw count and event payloads. Integration must prove real skid_lurch is
supported and a landed grab reaches this owner; invalid/dead/unmarked actor
and governor rejection leave state/RNG/events unchanged.
