# SPEC — Resident dialogue P06b1

Captured before generation, 2026-11-18. Scope and API approved. Central model validation:
4753 checks and38 unchanged-source fixtures passed; production integration remains separate. Parent:
SPEC-3D-FULL-PORT.md; shared token/transaction contracts: SPEC-3D-ECONOMY.md.
Model packet only. Runtime, scene targeting, presentation and native/Web tours are separate
integration evidence; an implemented handler alone does not prove reachable full parity.

## Scope and source authority

Nine authored residents: Lurch, Sherri, Paulie, Larry, Mom, Priest, Mathematician, Train Hopper,
Philosopher. The transformed omalley_fallen ID retains the Priest's source defensive callback.
Sources: neighborhood_a.js389-598,635-695; neighborhood_b.js78-86;
vendors_places.js290-387; interactions.js48-94. Source authored prose and capitalization remain.

The base source has37 interaction callbacks among41 actors. Core Tony/Pete/Yuri3, Big Guy
Travel1 and Lease/Greg campaign2 are separate owners. Remaining31 are partitioned:
this packet9; Barb/Dave/Stripe/Conductor/Pigeon5 with their linked quest lifecycles;
Pinky and14 inline spawn residents15; Possum/Scrap Dog2 with pet/follower schedules.
Price Guy, day visitors, bus and generated pets remain explicit dynamic rows beyond those37.
No unsupported actor receives generic replacement dialogue.

## Ownership and command API

RockBottomResidentDialogue.new(owner,spatial,memory,combat,bosses) holds weak references.
Existing GameState p/s/npcs and event queue remain authoritative; no new save or clock owner.
Existing ActionSession handles live reach/LOS, consumed tokens and state-identity epochs.
supports(actor_id), open(actor_id), select(token,action_id), close() are public.
Menus return {ok,token,actor,title,text,options:[{id,label,enabled,reason}]}.
A non-modal source receipt returns {ok:true,closed:true}; refusal returns {ok:false,reason}.
Nested Math/Hopper requests produce fresh tokens, invalidating the preceding capability.
Runtime owns invalidation between different menu domains and on pause/death/restore.

Opening and selection require a living exact actor, center distance strictly<60px, fresh
adapter can_reach_target result, playing/dialogue mode, and bossKind!="kingdom".
Tony fights do not blanket resident interactions. Hidden/daytimeOnly is not an invented
generic gate: source Mom and Hopper own their explicit nighttime branches. Hopper's night
interaction emits only the original refusal and opens no modal.

Opening effects occur only after geometry/session acceptance. Each genuine Priest/Math
opening increments its counter once; changing or validating choices never replays opening
effects or consumes flavor RNG. An explicit Math request for another number or Hopper story
opens another source conversation and runs that opening again. Common opening tracks
VENDOR_FLOATER_IDS and calls Memory.bother on the actual actor ID. Resource, daily, faction,
quest and transformed state are revalidated at selection. Duplicate/unknown/stale choices
cannot mutate resources. Existing source-mode menus spend no active world time.

## Behavior

Lurch's $1→2cred is once/day; Sherri's spider1cred and Paulie's face1cred are once/day.
Paulie increments pauliCompliments and unlocks at5. Their discovery options call Memory.tell:
Lurch underpass, Paulie choir_office, Sherri park then laundromat, one room per conversation.
These reveal visibility only and cannot grant concession, discovery credit or a new smoke spot.
Fight options call Combat.aggro on the exact live actor. Larry's shout1cred remains uncapped.

Mom is available in daylight (night iff dayTime<.25 or>.75). Accept10 and ask20 share one
daily ask stamp; asking20 succeeds at RNG<.4, otherwise brain-2. Either ask gives spiritual-1.
The separate daily compliment grants5cred/spiritual1. spiritual>=10 and unowned couch enables
the30 purchase, owned flag, current rent day and spiritual2. A changed day/night/faction/cash
between menu and action is rechecked. Future rent/dawn ownership remains the day pipeline.

Priest increments priestVisits even for the transformed defensive menu. Blessed tic-tac
adds5brain capped100, completes priest_mercy once, and never reduces shakes. Donation5
grants3cred, spiritual2, churchDonations5 and ecclesiastes at100; one donation per day.
Steal attempts increment plateStealAttempts. At visit>=4, not previously fallen and spiritual<10,
invoke the single Bosses.transform_fallen_priest transaction, then street1/spiritual-3.
Otherwise RNG<.55 gives22cash and plateStolen1, with judas if stripeBetrayed counter>=1;
failure directly subtracts12HP and wanted+1 capped3. Every attempt applies the same reputation.

Approved source-compatibility decision: the plate's direct HP subtraction bypasses iframes,
hurt flash, combo reset and immediate die/arrest. It can leave negative HP until another source
system resolves it. Preserve the literal p.hp delta; do not route through core.hurt or silently
add a health floor/death. Keep a low-HP source fixture proving this distinction. Save loading
continues to use the existing guarded normalization; no save-contract change is implied.

Approved atomic adaptation: when the steal would transform, unavailable Bosses/placement
returns failure before attempt count or reputation changes. Bosses false is atomic. No fake
Fallen actor or generic fight. Normal stealing needs no boss capability.

Mathematician increments mathInteractions per opening, calculates the exact source brain/high
slow-cook expectation text and dirty-supply aside, and grants scrap1 on every third opening
only for the first five authored tips. No extra rank/resource grant. Hopper's day opening
sets trainHopperTalkedTo and train_hopped once; asking about trains costs2brain capped0.
Philosopher chooses the authored question by day modulo list length and grants spiritual1
once/day on thinking. The source has no immediate save request on that action; preserve it.

## Validation

An unchanged-source Node oracle exercises real callbacks, opening effects and nested dialogues,
with controlled random sequences and exact resulting state. Compare source text/options where
their values are deterministic, not only balances. Additional properties cover daily boundaries,
strict reach/LOS, stale/foreign/duplicate tokens, removal/death, kingdom and nighttime changes,
fresh/restore epochs, absent dependencies and atomic transform refusal, lower/upper resource
boundaries, discovery without concession, no hidden opening replay and WeakRef ownership.
Every group and fixture loop needs a completion guard against script-abort false PASS.
Only root runs Godot and composes the Runtime; no engine invocation or integration claim here.
