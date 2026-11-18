# SPEC — One site engine and four-pin lockpick P11b

Captured before code, 2026-11-18. Parent approved the bounded model, source compatibility
decisions and physical seam below. Root owns Runtime, scene, geometry integration and gates.
Source authorities: activities.js24–177,217–252; props.js357–516,533–766;
interactions.js97–104; update.js869–871; SPEC-v22-copper-sites.md and SPEC-v22-breakins.md.

## Ownership and entry contract

RockBottomHeists(owner,spatial) owns one ephemeral three-stage flow for all four COPPER_SITES
and five BREAKIN_SITES, plus the nested four-pin lockpick used only by abandoned's entry.
Read the exported tables without copying their stories or prices into a second registry.
GameState remains sole owner of resources, counters, quests, achievements, death and RNG.
Inventory keeps its existing source record semantics and migration_units exception.

Public ready(), supports(site_id), site_at(center:Vector2), open(site_id),
select(token,action), close(), is_active(), sync_rank_unlock(), site_available(site_id).
Menus use the existing envelope with domain="heist", canonical target copper:ID or breakin:ID,
title/text/options and a fresh one-use ActionSession token. Unknown IDs refuse explicitly;
the source helper's abandoned fallback is not exposed as a remote malformed-ID action.

Entry requires playing/dialogue, no kingdom fight, a known available site, exact source
strict containment in its anchor expanded20px, and spatial.can_use_site(target_id)==true.
The adapter requires current valid player placement and actual accessible own-facade/door
LOS; it must not impose a fixed radius to the front service marker. No actor, loot, teleport
or fake interior substitutes for this geometry. Missing capability refuses before cap/RNG.
Root interaction priority is existing doors/routes/NPCs, copper sites in table order, break-in
sites in table order, then interactive props/zone verbs. This model does not own that resolver.

After entry, the source modal closure owns the action. ActionSession checks token, action,
same p/s epoch and active dialogue, with no new per-stage reach/LOS or actor-life condition.
Do not add HP, stun, ordinary-boss, time-of-day or per-site cooldown guards. Runtime closes
the session on replacement, death, arrest, fresh/restore and Escape. No persisted flow exists.

## Shared stages and exact effects

Check the listed tool/cred gates in order BEFORE the governor. A tool gate checks equipped
tool identity, not ownership in Pete's locker; cred uses >=. Refusal displays that exact gate
text and a leave choice, without spending the cap. Copper cap3 shares heistsToday; break-in
cap2 shares breakinsToday and cannot starve copper. Cap refusal displays the site's own text.
An accepted open increments its counter once, before stage1. Leaving or Escape does not refund.

Stage1 supports roll, lockpick, item, cash, wait, sure. Roll uses strict r<p. Soap consume=all
removes every soap record; food consume=one removes one source record (one virtual unit from
a migrated food stack). Cash/item disabled labels match the table and are revalidated before
cost. Costs are literal, without charisma discounts. Effects execute toast, raw hp subtraction,
glass sound, wanted cap3, brain floor0, shakes cap100. They do not call hurt()/respect iframes.
After ALL effects, hp<=0 calls GameState.die and stops before stage2; other entries proceed.

Stage2 copper has strip, listen, leave. Strip rolls 2+floor(r*3), adds copper and copperStripped,
plays glass, unlocks copper_singer at >=10, and completes copper_sings once with its original
quest receipt. Listen adds8 brain capped100. No invented immediate save or cred reward.
Stage2 break-ins take exact fixed cash/items from loot (q1 each) or the alternative brain/text.
These tables cannot mint copper/rocks. Both stage2 actions advance directly to getaway; leave
ends without getaway. All stage2 rewards remain granted even if a later getaway is fatal.

Stage3 presents exactly two exits and no invented leave button. Each exit consumes one roll,
applies the same full ordered effects, calls die if fatal, then sets playing and requests save.
Preserve the source extra save after death's own save. Escape still closes any dialogue without
running an exit. It does not claw back already granted loot or charge a new getaway cost.

## Four-pin lockpick and deterministic source compatibility

P06c extraction: `lockpick_system.gd` is now the single puzzle implementation shared with
freeing the scrap-yard dog. Heists accepts an optional injected puzzle in its constructor;
standalone callers create that same implementation. Owner context+state epoch revoke stale
puzzles, while Heists retains its existing ActionSession and entry success/failure effects.
The existing98 exact comparator-stream fixtures remain unchanged.

The actual source has FOUR pins, not three. It is untimed and uses normal numbered choices.
The four target numbers are a permutation, pins initially all unset, nextPin0. Correct choice
sets that numbered pin, plays pickup and advances; the fourth calls the entry success effect.
Wrong choice plays hurt, resets all pins/progress and subtracts TWO brain floored0 (the source
comment incorrectly says1); no HP cost, deadline, attempt cap or target reroll. Give-up runs
the entry failure text and its extra roll when present, then the same raw-cost/death advance.
Escape closes silently and never invokes give-up. No modal callback retains its own owner.

Approved adaptation HEIST-V8-SORT: source uses [1,2,3,4].sort(()=>Math.random()-.5), an invalid
ordering comparator whose schedule is JavaScript-engine-dependent. The3D port pins the
observed current V8 four-item schedule explicitly: detect an ascending/strictly-descending
natural run, reverse descending run, then binary-insert each remaining value. Each comparator
consumes exactly one seeded roll; equality belongs to the ascending/right insertion branch.
At most6 comparator draws are possible. This preserves the current unchanged-source oracle,
including its biased permutations and later RNG positions. It is NOT a universal cross-engine
JavaScript guarantee and is not silently replaced by Fisher-Yates or advertised as uniform.
Pin all64 sign streams, equality and seeded numeric streams against actual JS Array.sort.

## Abandoned availability is session-global

Approved compatibility HEIST-ABANDONED-LATCH: source trigger exists ONLY while an authored
BUILDINGS row is locked. Rank>=4 update unboards that row and removes the heist trigger; it
does not create a replacement interior action. The BUILDINGS mutation is session-global and
unsaved. Actual loadGame of a lower-rank save after unlocking does not restore the trigger.
startGame(false) also never relocks (nor does that source function reset rank).

One Heist session latch initializes from the canonical locked building. sync_rank_unlock()
is called directly after Progression.update_ranks at the source update position; rank>=4 clears
availability once and emits site_availability_changed for the scene boards. Keep this owner
across fresh/load just like the source array. A cold application starts from the canonical
locked row and its first active rank pass can clear it. Other eight sites remain available.
No second writable building table or saved flag is introduced. Active modal flow can finish
after later availability changes, matching its captured source closure.

## Evidence and integration limit

Unchanged-source oracle exhausts every entry kind/branch, both exits/branches, all9 sites,
both stage2 choices, cap/gate precedence, disabled cash/items, raw/fatal entry and getaway
ordering, soap-all/food-one, copper achievement/quest boundaries and Escape versus give-up.
Separate exact four-pin sort probes cover64 sign streams/equality/seeded draws. Characterize
actual source updateWorld plus low-rank loadGame for the abandoned latch.

Godot properties add single-use/stale/epoch tokens, no post-entry spatial queries, missing
capability/no partial mutation, exact strict rectangle boundaries, cap independence/replay,
save durability and one-unit migration consumption. Root runs central model and whole-suite
gates. Native/Web real site approach, own-facade LOS, interior menu rendering, source priority
and board availability integration remain partial until root supplies and verifies them.

## Production integration contract

Runtime retains one Heists owner across fresh/load, closes its modal on all replacement,
pause, death and arrest paths, and calls its rank latch immediately after rank updates.
Scene resolves sites after existing door/route/NPC priorities and before loose pickups and
zone verbs. Heist options are exact: the scene must not append an extra leave button to
the two getaway exits or the four-pin puzzle. Escape remains the universal modal exit.

World service records expose their actual authored world-space site rectangle. The adapter
checks the strict20px expansion, a clear current player capsule, and an eye ray to the nearest
point of that rectangle (nearest boundary when inside it). A first hit on the declared own
structure is a valid facade contact; an unrelated collider refuses. This avoids requiring a
walk to an arbitrary front marker and rejects embedded or remote interaction. These checks
run only on opening. Decorative abandoned boards follow the session latch without changing
physical walls, source rectangles or creating a new interior action.
