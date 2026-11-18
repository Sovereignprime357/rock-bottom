# SPEC — The Heat P09b

Captured before code, 2026-11-18. Parent approved source cooking and the bounded extreme-count
adaptation below. Source: heat.js22–313,439–451; activities.js326–330; update.js33–45;
keyboard.js69–79. Root owns Runtime/scene/input/HUD integration and central engine processes.

## One owner and API

RockBottomCooking(owner,spatial) uses weak GameState/spatial references. Only s.heat owns the
active heat record; p resources, quests, achievements and seeded RNG remain GameState-owned.
COOK_MODES comes from canonical exported source definitions. No alternate cooking transaction
in Block menus, keyboard handlers, HUD or cached audio. State.heat is ephemeral and unsaved.

Public ready(), open_menu(), select(token,mode), lock(), bail(), cancel(reason), is_active(),
is_resolving(), tick(dt_ms), tick_presentation(dt_ms), snapshot(). open_menu/select return the
existing menu/action envelope (domain="cooking"); lock/bail return result dictionaries.
cancel returns false while an accepted large finalization is resolving; otherwise revokes
ephemeral activity without charging. Runtime must queue lifecycle replacement until accepted
resolution finishes. Escape uses bail, NOT cancel; ordinary menu Escape is free.

Opening requires playing/dialogue, no kingdom battle, actual inclusive Block zone membership
and spatial.can_use_zone("block"). No fixed marker radius. It may show an all-disabled menu
with no packets. Selection has one-use/epoch capability and the captured modal context, without
new per-choice geometry. Revalidate current required packets/shakes/equipped torch before
starting; no HP/stun/ordinary-boss gate. Keep the source menu's captured cook-all packet count.

Five choices: slow1 packet, fast3, shakes1 requiring shakes>=60, all captured n>=5, propane1
shown only with tool slot propane_torch. Ownership at Pete's locker does not enable use.
Exact text, predictor precedence, dirty-first line and leave choice match source. Menu quantity
requirements are not resource caps. Unknown modes fail instead of falling back silently.

## Clock and input

Start closes the menu, consumes ONE center RNG draw, sets mode=cookmini and s.heat with source
fields. Supplies are not consumed yet. Width=clamp(baseWidth+clamp((brain-30)/70,-.4,.6)*.10
minus .06 if high,.05,.40); center=clamp(base+uniform signed spread,.10,.95). Modes retain exact
fill times4000/2400/1800/3200/1200ms and base widths/.08 burn zone, propane .15 burn zone.

tick accepts finite positive dt<=50ms. Runtime calls it only in cookmini while hitPause<=0,
instead of Core/world tick. High/crash, AI, day and other gameplay clocks pause. The source is
one branch per frame: fill t/progress enters idle at full; the crossing frame does NOT decrement
idle's1000ms. Idle crossing locks at1 and starts600ms hold; that frame does NOT decrement hold.
Hold crossing finalizes once. Do not integrate leftover time across source phase boundaries.

Space,1,Enter and click/tap all acknowledge the SAME lock action. Lock accepts only fill/idle,
stores current progress and sets hold600. Repeated input cannot reroll or shorten hold. Outcome
sound occurs at lock; resources settle after hold. Escape during fill/idle/hold consumes n packets
and dirty-first count, clears heat, returns playing, emits exact bail feed/toast/save and NO reward.
Cancel for explicit fresh/restore/destruction clears unpaid ephemeral heat without a bail cost.

tick_presentation alone decrements s.smokeT by finite dt<=50ms in every mode, mirroring source's
post-update overlay decrement. It never advances cooking phases. Burn starts smokeT2000.
The source2200ms smell follow-up is a presentation-only delayed_toast event carrying delay_ms,
text and duration_ms for Runtime's existing monotonic scheduler. No second cooking wall clock.

## Outcome and resource ordering

Resolve order is load-bearing: if x<.25 and distance>half, undercook; else x>=1-burnZone burn;
else distance<=half perfect; <=1.8half OK; <=3half bad; then x<.20 undercook; otherwise consume
one roll for15% soaprock versus bad. Boundaries are inclusive exactly where source uses <=.

At finalization freeze n/mode/outcome, brain/high-derived bb, dirtyUsed=min(n,dirtySupplies),
cleanUsed=n-dirtyUsed. Per-packet probabilities remain source mode formulas; clamp double[0,.7]
and burn[.02,.5]. One draw per packet. Soaprock uses bad base yield, floor(total*.5), tagged
soapRocks, no propane1.30 multiplier and no normal clean/dirty soap conversion. It does not
increment rocksCooked, complete finisher or grant perfect/chef achievements.

Normal perfect/OK/bad: propane floors base yield*1.30 FIRST, then outcome floors*1.15/1/.60.
Weighted soap rate=(dirty*.25+clean*.12)/n times .70/1/1.50. If mode!=shakes AND positive yield,
one soap roll may replace exactly one real rock with one inventory soap record. Shakes skips
the draw and ignores brain in its base probabilities. Costs then remove supplies/dirty first,
grant resources, apply brain floor0 cost min(6,1+n), shakes cap100 (+2n except shakes mode),
increment lifetime real rocksCooked, sounds, finisher/chef/arson/perfect achievements, exact
ledger text,50% feed draw, then bulk-smell35% draw only n>=3 and perfect/OK, finally save.

Burn: consume supplies, brain-10 floor0,wanted+1 cap3,smoke2000,sounds,toast,50%feed,
controlled_burn and n>=3 arson_of_nothing,save. Undercook consumes supplies,sound,toast,
50%feed,save. No raw HP cost. Bail/failed batches do not grant normal cook progression.

## Approved adaptation COOK-BOUNDED-FINALIZE

The normalized save permits up to1e9 packets and source cook-all synchronously loops n times.
Do not freeze the application or silently cap/throw away resources. Once hold expires, freeze
the source calculation inputs and accept the finalization. Process at most2048 packet RNG draws
per tick. Normal n<=2048 batches finish in that same hold-crossing call. Larger batches use an
ephemeral phase="resolve" and keep cookmini active; no packets/rewards mutate until one commit.

Consume authoritative GameState RNG per chunk. Never clone then overwrite the live seed: wall
callbacks may consume legitimate RNG between chunks. Within cooking, preserve conditional draw
order exactly. Interleaving with unrelated wall callbacks in extreme batches is an explicit
timing adaptation, not a claim of globally identical source RNG timing. Freeze probability
inputs; apply final cost/grant deltas to the current same-epoch player once, with source caps.

An accepted resolve rejects bail/cancel with resolution_pending. Runtime queues mode changes,
fresh/restore and shutdown persistence behind settlement while continuing bounded updates and
presentation. An unexpected forced p/s replacement invalidates remaining work before writes;
already consumed RNG draws are not refunded and no stale payout reaches the replacement state.
Do not allow a failed cancel request to be interpreted as successful cleanup.

Counterexamples: double lock cannot roll again; hold Escape consumes without reward; no-input
fill crossing cannot spend its leftover dt twice; n2049 cannot partially pay at first chunk;
interleaved wall draw cannot be overwritten; forced restore cannot receive prior batch rewards;
repeated finalize/tick cannot consume twice; source mode-specific skipped draws remain skipped.

## Evidence

Unchanged-source fixtures cover every mode/outcome, menu quantities/predictor/torch gating,
center/width caps, exact phase-crossing snapshots, outcome boundaries and draw counts, dirty
precedence, soap distinction, yield floor order, achievement/quest thresholds, burn/smell,
and Escape during each unpaid phase. Properties cover stale/epoch inputs, chunked-v-normal
same-stream outcomes, authoritative interleaving, atomic cost/grant, lifecycle refusal and
no separate clock/resource owner. Root must verify native/Web heat bar/input, pause behavior,
source update order, real Block reach, sound/presentation and deferred lifecycle integration.

## Runtime and scene wiring

Cooking receives one clamped50ms frame call in cookmini, with no leftover phase integration or world advance. Presentation smoke decay runs once after that update in every mode. The scene accepts only the source lock keys/click and Escape-bail while cooking; starting a batch closes the ordinary menu without routing through resume/cancel. One bounded pending lifecycle request (first request wins) retains a mode/fresh/validated-restore intent during extreme resolution; after settlement it executes once and emits a completion event. Failed requests leave the current heat surface active. Save requests remain queued until settlement. Native close requests wait for settlement and the save queue; a forced process termination cannot be made transactional. Delayed smell text is an epoch-bound presentation queue on the existing monotonic Runtime wall input, capped32 receipts, never a gameplay reward or timer owner.

Lifecycle boundary correction: reaffirming cookmini is a no-op only while heat is active;
entering it without heat is refused. While accepted resolution remains active, Runtime detects
direct mode writes from wall callbacks (including Tony's delayed ending), retains the first
requested destination and restores cookmini so bounded work continues. Ending/death/arrest
presentation is held until settlement. Death/arrest may already have applied authoritative
same-epoch consequences; Runtime does not roll those back or pretend a refused cancel cleared
the batch. Their menu cleanup and presentation complete after the single accepted settlement.
Duplicate transition presentation of the same kind coalesces while held. An ending superseded
by the first queued pause/fresh/restore cannot subsequently override that winning lifecycle.
All delayed receipts, held transitions and pending lifecycle records carry both p/s identities.
Forced replacement discards stale presentation/intents without paying or modifying the new epoch.
