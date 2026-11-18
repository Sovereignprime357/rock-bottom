# SPEC — Recognition, concessions, discovery and the one smoke path

Full-port packet P10, captured before generation, 2026-11-18. Source:
`src/systems/recognition.js`, `concessions.js`, `discovery.js`, `hitter.js`, and the high/crash
boundary in `src/core/update.js`. New module `game3d/scripts/memory_loop.gd` composes the single
GameState authority. Root owns this module and its tests. Data definitions come from P02.

## State and behavior

Keep source pixel coordinates and millisecond timer fields in p/s; scene conversion is external.
Four venues (park/laundromat/underpass/choir_office), five verbs (sit/bother/buy/sell/full_high),
thresholds3/8/15. Sit/bother credit at most once per source/witness per continuous visit; changing
venue resets the visit. Successful buy/sell credit per transaction. Cap each lane at1,000,000.
Recognition changes no money/items/stats or mechanical advantage beyond earned concession access.
Tier reactions/feed use original text. A normal full-high boundary credits the player's current
venue; a hitter boundary never does. Leaving before the boundary moves the witness with the player.

Discovery only marks a known venue, never recognition or resources. Block is always known and
cannot enter discoveredVenues. Known-but-unearned rooms state the keeper/condition and have only
leave. Unknown rooms expose no concession action. Conceded rooms show current condition honestly:
park at night, choir office while open, underpass with a live freed-dog follower AND follow timer,
laundromat in the70s running window with15s excluded at both ends. The Block stays unconditional.

Independent source LCG drives persistent choir/dryer clocks: choir closed90–150s then open55s;
dryer idle50–90s then running70s. Active-time only. Announce turn only to a conceded player inside
that venue. Normalize phases/finite positive time caps and seed; malformed clocks reset safely.
Nearest legal smoke target considers current legality, chooses Block on any nearest-distance tie.
Recheck condition and location on action; opening a menu cannot grant a later illegal ignition.

## Smoke and emergency hitter

One validated smoke method for every spot. Reject unknown/illegal location, no rocks, and active
high. Consume soap first: no high, shakes relief, brain cost, cred, reputation or royal static;
increment smoked count, soap achievement and complete source intro smoke. Real rock: consume1,
18s high, clear crash/hitter flag, shakes-50, brain-4, cred+1, smoked count+1, street+1/spiritual-1.
Only real smoke at Block during kingdom anoint advances emperor_gate and resets marks. Emit
original receipt/audio/feed and progression notifications; save request after accepted action.

Hitter craft consumes2 copper and adds1 consumable anywhere; no reverse conversion. Use consumes1,
6s high,14s crash at boundary, shakes-20, brain-8, no cred/rep/smoked/intro/royal/recognition credit.
At high expiry normal rock adds30 shakes/8s crash; hitter adds35/14s and clears hitterHigh. The
core clock boundary calls this module once; no second timer loop lives here. Far-dumpster find
requires farFactor>0.25 and one4% roll; reward acknowledgement follows a committed find only.

Presentation events retain source sound and flash cues. Soap emits hurt plus glassBreak;
normal ignition emits rockUp and gold flash; hitter uses hurt/orange flash; both crashes emit
crash/purple flash. A full-high tier-crossing receipt carries defer_ms2300/duration_ms3600
after the immediate2200ms crash receipt. The ledger mutation is immediate; only the future
presenter delays display. That delay is not a second gameplay timer or reward path.

## Acceptance

Exercise real GameState mutations, not a separate mock implementation: zero resources, duplicate
input, soap priority, normal/hitter transitions and remaining-delta behavior, all condition
combinations, mid-cycle boundaries, Block-only coronation, current-venue full-high, per-visit
witnesses, tier transitions, idempotent reveal, no resource/recognition leakage, negative/NaN
saves and deterministic clock roundtrip. Source-oracle fixtures should pin representative
outcomes/text independently. Scene/UI integration and native/Web loop tours remain separate
requirements before this packet can be marked verified.
