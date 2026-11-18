# SPEC — Static street prop actions P09c/P10a

Captured before implementation 2026-11-18. Root approved this bounded packet and its explicit
source quirks. Sources: interactions.js107–129,148–172,196–357; vendors_places.js389–412;
update.js278–284,376–405,431–448; catalogs.js51–72; start.js99–109; hitter.js28–39.
This packet covers park_bench, dumpster and pay_phone only. Interactive trash/bottles, Old
School and Block activities remain separate packets. No Runtime/Scene/world edits here.

## Composition and API

`RockBottomWorldPropActions.new(host,spatial,props,memory,companions)` has weak dependency
references and uses the existing Inventory and ActionSession helpers. PropState remains the
only source-PROPS owner. Its live `record('prop:INDEX')` is the command seam; changes to looted
always use `set_dumpster_looted` so durable projection stays correct. Immutable content is never
changed. Source22-item dumpster pool and10 phone texts come from exported catalogs.

Public API: ready(), supports(id), open(id), select(token,action), close(), reset_session(reason),
consume_possum_handoff(ticket), tick_props(dt_ms), tick_bench(dt_ms), tick_phone(dt_ms), snapshot().
`open` returns the established envelope: dumpster domain `world_props`, title/text/options/token;
bench and phone are immediate `{ok,closed,committed}` commands. A blocked phone reply additionally
has pending=true and committed=false. No success gesture/receipt is emitted before commit.
Root injects the owners and calls the three hooks at their corresponding source positions:
dumpster cooldowns before territory; bench before Day active checks; public phone after Day
active checks and before Companion clocks. Finite0<dt<=50ms, playing only, no independent process,
wall clock, AI or movement owner. Root is responsible for modal exclusions and clock ordering.

Open requires playing/dialogue, no kingdom battle, canonical prop ID/type, source strict center
radius and spatial.can_reach_target(id). Bench radius50px; dumpster44px; phone38px and ringing.
Ordinary bosses, raw HP and stun introduce no additional gates. Selecting a dumpster option
consumes a one-use p/s-bound captured modal capability before effects, without rerolling offers
or adding a new per-choice geometry requirement. Invalid consumed capabilities close only their
owned modal; an old token cannot close a newer menu. Pause/replace closes the owner capability.

## Benches

Use shared s.sittingOnBench/benchSitT/benchSitGainT/benchSitPasserT. Sitting toggles at any bench,
records Memory.record('park','sit','park_bench'), zeroes all three timers and emits exact text.
Standing reports floor(sat/1000), clears sit and elapsed only. Source does NOT immobilize the
player, bind them to a bench, auto-stand on movement, or change shakes. +1brain capped100 each
2000ms; achievement at>=60000ms. Passer timer begins on the step reaching60s, triggers strictly
>30000ms, resets to0, draws one of five exact lines. Pause/dialogue/cooking freeze active clocks.

## Dumpsters

Opening an already-looted dumpster only gives its source refusal. A tips jar is removed on
open; actual8–14 cash and displayed8–14 cash use independent rolls. Opening the menu alone does
not save that grant. Draw base loot r FIRST, then Memory.dumpster_hitter_roll(farFactor), then
only the source conditional draws, then two filler items. farFactor=min(1,distance(top-left,
(1050,840))/900); noneCut=.30+(1-far)*.20. Preserve thresholds that can exceed1 near the Block;
do not repair unreachable branches or interpret misleading percentage comments as authority.
Loose-cash label and actual value also use separate1–4 rolls. Exactly three options plus exit.
Distance-based loot thresholds retain scalar double precision; physical Vector2 conversion must
not shift a source branch at the exact rare-find/table boundaries.

All22 filler outcomes retain exact source effects/text. Ordinary items use the source ASCII
nonword-removal ID fallback. Equipment overwrites its source slot and applies equip stats.
Broken bottle uses source weapon/feed. Hitter delegates existing Memory roll/grant, never a
second pocket transaction. Rats emit a cosmetic event; cosmetic particle RNG is excluded under
the approved P07 simulation/presentation split and characterized separately by the oracle.

Choosing any item marks looted, starts90000ms cooldown, increments dumpDives and saves. Cooldown
subtracts active dt and can go negative; its crossing clears looted without a new save. Garbage
reset may clear looted and add tipsJar without replacing an active captured offer or its cooldown.
`climb out` only marks looted and emits its line: NO new cooldown, dive count or save. Generic
Escape/close applies no climb-out effects. Source PROPS/looted/tipsJar/diveCdT survive fresh and
load, with load overlaying only saved true flags, as already specified by PropState.

Approved decision PROP-DUMPSTER-TOOL: preserve the actual source equipped-only hasPropane
checks for rare torch selection and receipt. A torch in Pete's locker does not block this
dumpster branch; direct tool assignment can overwrite the carried crowbar and does not invoke
GameState.equip_tool/locker preservation. This is a documented dumpster quirk, not a change to
the safer vendor, pickup and boss-drop ownership rules. The rare-awarded flag changes only on
actual acquisition; a captured torch option rechecks the equipped slot when selected.

Possum option commits the dumpster, then delegates Companions.open_from_dumpster(ticket). The
ticket is opaque, one-use, tied to this accepted selection and both p/s identities. Only
consume_possum_handoff can spend it; no outdoor possum or invented distance check is required.
Return the Companion envelope so root transfers modal domain without closing the new menu.

## Public phone and physical transaction

Active timer initializes when null to240000+random*240000. While ringing, only its30000ms answer
window decays; the next timer is frozen. Otherwise timer decrements even during intro, but a new
ring requires introDone and playing, rerolls the interval, and emits source sound/feed. Answer
draws one of10 lines, consumes the ringing opportunity, increments publicPhoneAnswered, speaks
the line, applies its effect (brain-4floor0, hp+4cap, or church cash), awards the>=5 achievement
and saves. Other lines have no reward. Phone text is exact; the feed owner remains Communications.

Approved decision PROP-PHONE-PHYSICAL: the church line draws once and reserves that answer.
Call actual spatial.stage_cash_pickup((1800,1320),100). Accept only finite in-bounds Vector2
within100px; no cash/flags/count/feed/achievement/save commit or success receipt until valid.
When blocked, retain one epoch-bound intent and clear the ringing opportunity. No second answer
or new ring occurs while pending. Retry at most once per250 active ms without RNG. On success
create one50 cash pile with a unique ID, emit cash_spawned, set source church-tip coordinates,
then complete the original answer exactly once. The pile remains physical; cash is not directly
credited. Fresh/load discards this ephemeral intent. No phantom/durable Day grant is fabricated.

## Lifecycle continuity

Root calls reset_session('fresh'|'restore') after PropState rebinding and before actions/ticks.
Cold construction adopts existing source defaults without an extra draw. Capture old s by
identity only for specified unsaved continuity: bench sit/timers survive fresh and same-session
load; phone timer/ring survive load, while fresh rerolls interval and resets ring/answer count.
No new save keys or duplicate clocks. Pending phone/modal/handoff work is cleared on either
replacement. Unexpected replacement without reset makes the owner unavailable and cannot pay
stale work. Already emitted committed effects remain GameState-owned.

## Evidence

Unchanged-source oracle pins all22 filler choices, loot thresholds/conditional draws, cash-label
asymmetry, tips jars, torch-slot/locker quirk, each phone line, menu/counter/save/achievement
outcomes, bench and phone clock boundaries. Source cosmetic RNG is reported separately.
Properties test missing/invalid placement, blocked-to-clear retry without extra rolls, physical
cash rather than direct grant, stale/duplicate/forced epochs, actual Companion handoff, garbage
reset/cooldowns, active-only timers and source continuity. Root runs engine gates and actual
physical-world/controller integration. No model fixture alone claims rendered/playable parity.

The captured oracle contains159 unchanged-source paths and287 steps. Action snapshots compare
every scoped player field, live prop, offer label, receipt, feed, achievement, counter, save count
and mechanic draw count. Whole-world clock/start oracle calls remain unchanged source functions;
their expected projections cover this packet only, and unrelated source RNG/save counts are not
compared. Rat callbacks separately prove30 cosmetic draws; only those terminal draws are omitted
from this presentation-independent model under the approved P07 split.

## Live composition and physical controls

FullRuntime owns one WorldPropActions over its existing PropState, Memory and Companions.
Fresh/restore rebind it after shared props and companion epochs; all menu replacements and
death/arrest close its capability. Source active scheduling is dumpster cooldown before
territory, bench before Day's price/night-pile check, public phone after that check and before
dog discomfort. Pause/dialogue/cooking do not tick these clocks. Phone initialization is the
same source draw, with no presentation random consumption.

The actual scene resolves aimed park benches, ringing phones and dumpsters through the shared
source IDs. Bench uses50px, dumpster44px and phone38px with canonical source centers plus real
LOS; physical meshes keep their colliders. Dumpster options and the one-use possum handoff
retain their domain. Escape only closes the menu; it does not select climb-out or take loot.
The existing hands consume the committed gesture event; receipts and physical cash use the
existing presenters. A scene test must operate actual buttons and source prop state, including
cancel, one loot/cooldown, bench timing and a public-phone answer.
