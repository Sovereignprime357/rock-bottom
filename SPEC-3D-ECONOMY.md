# SPEC — Inventory, action sessions and the three core vendors

P03b/P06a, captured before generation, 2026-11-18. Parent: `SPEC-3D-FULL-PORT.md`.
Source: `src/dialogue/neighborhood_a.js:18-386`, `src/core/runtime_ui.js:34-108`,
`src/systems/interactions.js:47-94`, `src/minigames/heat.js:15-22`, and
`src/data/catalogs.js:12-16`. This packet supplies composed model modules, not scene integration.

## Ownership and API

`inventory.gd` references GameState weakly. All records remain in `p.inventory`; it exposes
`count_records(id)`, `quantity(id)`, `append_item(id,name,q=1)`, `remove_first_record(id)`,
`remove_records(id,count)`, `remove_all(id)`, `owns_tool(id)` and `swap_locker()`. Known item IDs
come from the exported source catalog. Appending preserves separate records and their names.
Ordinary source records keep literal semantics: q is displayed metadata; source actions that
consume one record remove that record even when its displayed q is larger than one.

Compatibility exception approved for schema1 migration: only migrated junk/food stacks receive
`migration_units:true`. A marked stack of q units represents q virtual source q1 records.
Counting/removing records consumes only the requested units and preserves the remaining stack,
without expansion or a new truncation cap. A single food use cannot erase the remaining migrated
food; Pete's remaining daily cash cannot erase unpaid migrated junk. Core validates a strict
boolean marker only on junk/food, preserves it across schema2 saves and never adds it to normal
source acquisitions. Existing finite resource/collection normalization remains.

`action_session.gd` owns ephemeral token/target/offered-action IDs, never resources. It holds a
WeakRef to GameState and a WeakRef to the spatial adapter. Adapter method
`can_reach_target(target_id)` must compute current reach and line of sight; a cached boolean is
not a production adapter. Both opening and selection call it. Missing/freed adapter fails closed.
`begin(target,action_ids)`, `consume(token,action_id)`, `close()` and `probe(target)` return plain
results. Tokens increase per instance; consumed/stale/unknown tokens cannot execute twice.
The session retains p/s dictionary identity; fresh/restore replacements invalidate the epoch.
Selection consumes the token before dispatch/revalidation, including a refused action. Opening
another modal or closing invalidates the preceding session. Source modal trades spend no world
time; the orchestrator remains responsible for pause/input and invalidating sessions on teardown.

`vendors_core.gd` composes Inventory and ActionSession with weak owner/memory/adapter references.
`open(vendor_id)` returns `{ok,token,vendor,title,text,options:[{id,label,enabled,reason}]}`;
`select(token,action_id)` returns `{ok,reason,...receipt}` and queues normal GameState events.
Only Tony, Pete and Yuri are handled here. Source-center reach is strictly less than60px,
in addition to live 3D adapter visibility. Current actor existence/death, Pete shopClosed,
kingdom interaction lock, mode, resource balances, faction, daily room, rank and ownership are rechecked at
selection. UI copies are never authority. No partial deduction or reward on rejection.

Source interaction parity amendment, 2026-11-18: only `bossKind == "kingdom"` blankets vendor
access, regardless of bossActive, matching tryInteract's first guard. An active Tony encounter
does not remove living Tony/Pete/Yuri interaction callbacks: ordinary buying/selling remains
available, with existing reach, closure and resource checks. Opening or selecting after the
kingdom lock appears must refuse without payment. Starting another Tony fight still requires
the capable synchronous boss adapter below; allowing trade does not bypass its start guard.

Boss adapter exposes pure `can_start_tony()` and synchronous `start_tony()->bool`. A third
short-payment or corner challenge refuses before vendor cash/offense changes if no capable
adapter exists or start rejects. The adapter must itself be atomic on false. Successful boss
start owns combat effects. This module cannot satisfy boss parity with an event or placeholder.

## Canonical transactions

Tony: rock base10, street liked/loved base9, then the existing charisma90% half-up discount.
Buying pays current price, grants one real rock, reduces offenses by one to minimum0, increments
rocksBought, awards tonys_worst at50, adds street1 and completes first_rock once. Shorting pays5,
adds one offense and starts Tony at offense3+. Corner challenge requires100cred and a real boss
adapter. Negotiation and all narrative lines retain source text. First valid contact marks a
tracked vendor met; available intro_tony completes once with +1cred and opens intro_smoke.

Yuri: copper pays25, or28 at scrap liked/loved. Bulk sale removes all copper and grants
scrap min(5,sold); single grants scrap1. Scrap>=5 and unowned shed permits a150 purchase,
scrap2 and source feed; the owned flag is the hideout hook, not an invented separate shelter.
Dog/Brutus questions preserve all source quest-dependent responses.

Pete: scrap hated (<=-10) refuses the entire menu. Copper pays15/17 liked+, with a shared200
daily outgoing-cash cap. Copper/license can be paid partially at the cap; copper consumes one,
license consumes ALL matching records. Sock pays1 without an inventory requirement. Junk pays1
per source record, consuming only paid records. Copper/license add scrap1; sock/junk do not.
These four sale forms increment peteSold once per transaction. Food costs3, appends the exact
source food record, increments peteSold, and is independent of Pete's outgoing cap.

Torch is stocked on a rank>=3 visit, costs80 and is one sale while not already owned; ownership
includes the locker. Crowbar costs35 while unowned; both use core equip_tool so the displaced
tool survives. Free locker swap preserves both tools and consumes no cash. Loved scrap permits
a50 loan once per day, outside the200 cap, with cred-1 clamped0 and the source feed. Prices for
Pete's food/tools do not receive Tony's charisma discount. Repeat torch question stays present
after the sold flag. All success prose, labels and source hot-pocket/11-minute beats remain.

Opening calls shared Memory.bother. Tony/Pete/Yuri are not regular-venue buy/sell mappings in
the source, so these trades do not fabricate recognition. Future Barb/Pigeon handlers must call
Memory.record at their exact source sites. Queue feed/sound/toast/quest/save through the one
event queue; resources commit before consumers drain it. A successful trade emits a descriptive
transaction event for later campaign/scene consumers, without claiming those consumers exist.
Sock keeps the source's lack of immediate save request; other durable trades request save.

## Proof and limitations

The dev-only economy oracle executes unchanged source dialogue callbacks and exports fixtures.
Fixtures cover prices/factions, Tony offenses/achievements, Yuri bulk/shed, Pete cap/partial
consumption, food/tools/locker/loan and refusal. Tests compare actual source state, not a second
formula implementation. Additional tests cover live reach/LOS changes, spent/foreign/replaced
sessions, actor removal/closure, mutation after menu opening, unavailable/rejected bosses,
finite inventory inputs, migrations through partial sale/food consumption/save, and ownership
isolation. Independent source oracle generation/check is allowed; only root runs Godot gates.
No production scene, combat placeholder, save IO, new item art or generic trade economy belongs
in this packet. Full vendor and full game parity remain integration claims to prove later.
