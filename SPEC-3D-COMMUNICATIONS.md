# SPEC — Communications and live source props P14b

Captured before code2026-11-18. Root approved real feed/news,12 calls,29 world events and
bounded source-PROPS owner. Sources communications.js11–116,126–260; boot.js19–20;
update.js199–238; audio_save.js52,239–240; start.js21–157. Parent full-port/day/street specs.
Root owns Runtime scheduling, scene/panels/input, persistence IO and real rendered evidence.

## Single owners and API

RockBottomPropState(owner) owns one mutable source-PROPS array (canonical indices/positions),
published by reference as s.propRuntime. Content definitions stay immutable. records() supplies
a detached read snapshot; record(id) is a live authoring seam for future prop actions, and
set_dumpster_looted(id,value) updates both live record and durable s.lootedDumpsters projection.
IDs are existing "prop:INDEX". Non-dumpster identities remain source records, not new actors.
ready(), reset_session(reason), garbage_reset()->Dictionary are the public lifecycle methods.

Source PROPS is session-global: new-game never clears dumpster looted/tipsJar; load overlays
only saved true looted flags, without clearing earlier true ones. Preserve that asymmetry.
Cold construction clones canonical props then overlays saved looted coordinates. Fresh/restore
rebind the same live array to new s; restore alone adds saved true rows. Root calls the explicit
reset_session("fresh"|"restore") before saves/actions after changing state. Unknown saved
coordinates cannot create props. Tips jars and diveCdT remain unsaved. Garbage clears every
dumpster looted flag/projection and chooses one source dumpster to set tipsJar=true; it does
not clear older jars or reset dive cooldowns. Future dumpster actions must use this owner.
No direct mutation of Content or independently duplicated prop flags is allowed.

RockBottomCommunications(owner,props,unix_ms:Callable) holds weak GameState/Props owners.
The clock is an independent/static provider, not a closure retaining Runtime. It is the same
injected Unix-ms source as Days. Session-global posts/visible/news text/index live only here;
they are not saved or reset on GameState fresh/restore, matching source globals. Cold session
starts empty feed/hidden and rotates initial news once. No duplicate feed/history in scene.

Public ready(), day_capabilities_ready(), silence_active(), show_feed(), toggle_feed(),
post(text,author=""), broadcast(text), snapshot(), advance_wall(monotonic_ms),
ring_phone(index=-1), fire_mom_intro_once(), maybe_mom_proud(), fire_random_event(index=-1),
dispatch_day_callback(kind), consume_event(event), flush_pending_events(). Data comes from exported PHONE_CALL_LINES/MOM_TIP_CALL/
MOM_PROUD_LINES/NEWS_POOL/FEED_HANDLES/WORLD_EVENTS. No function-valued JSON execution.

post accepts valid input even when silence suppresses it; false means unavailable/invalid
dependency. Silence check precedes fallback-handle RNG. Keep8 newest {h,t,day} records,
newest first. show/toggle change the same visible flag; rendered visibility is visible AND
mode=="playing". Phone Guy uses this actual owner; root consumes ordinary feed/news events
once through post/broadcast. snapshot returns detached render data, not writable authority.
Presentation-change events use a distinct kind, so the feed consumer cannot recurse.
Days call post/broadcast synchronously where ordering relative to day7 silence matters: a
queued dawn receipt must not be retroactively suppressed after the same commit sets silence.
The approved narrow flush consumes only pending feed/news in their existing order after
Progression.roll_hustles and before day7 mutates silence. Preserve all other queued events
and distinct presentation events; never run arbitrary Runtime rewards while committing day.

## Clock and ticker asymmetry

silenceUntilT is persisted absolute Unix milliseconds, active iff truthy and >now. Equality
expires. Invalid clock refuses operations before RNG/resource side effects. Day7 sets that
flag through Days; Communications never owns a second silence timer.

broadcast and post are suppressed during silence. Source rotateNews ignores silence.
Preserve that asymmetry: rotate once on cold boot, then every50000ms real/monotonic elapsed,
including menus/title. Each rotation renders5 consecutive source headlines and increments
index modulo pool length. advance_wall accepts finite nondecreasing timestamps; first call
anchors time. Large elapsed intervals advance index arithmetically and emit only the final
visible rotation (no unbounded loop or intermediate gameplay effect). Broadcast prepends
"· BREAKING · line   ◆   " to current tape; next rotation replaces it. No invented ticker cap.

## Calls and events

ring_phone only runs in playing. Default selection uses exactly one seeded index over12 calls;
explicit valid indices avoid that selection draw. It emits source dialogue sound/incoming
toast, posts caller receipt, then applies exact source callback effects:
Mom brain-5floor0; wrong number cash3; possum brain4cap100; scam cred1; own voice brain10cap100;
remaining7 no resource changes. Calls are toasts, not choice menus or modal pauses.
Direct ring_phone is not itself silence-gated (its feed still is). Root's ambient timer applies
source intro/silence/80% gates; no new suppression is invented inside the callback.

Mom intro requires playing and not momIntroFired, stamps once, uses forced authored line and
saves. It bypasses ambient-intro/silence call suppression exactly as source. Proud call requires
playing, spiritual>=10, unstamped day and inactive silence; stamp before one line RNG, ring,
brain+5cap100, no immediate save. dispatch_day_callback("mom_proud") returns true for accepted
source-gated no-op; it does not turn a missed callback into a retry/reward later.

dispatch_day_callback("garbage_truck") preflights real PropState before any receipt/RNG:
traffic twice, source toast/feed, real garbage_reset, then authored news. It runs in any mode
like the source timeout. It neither invents a daytime gate nor merely announces emptying.
Source audio.traffic() evaluates one Math.random() for pitch before tone checks audio readiness
(audio_save.js307). Preserve that draw at each Communications traffic call, including muted
or uninitialized audio: two before garbage's tips selection and one before helicopter's final
news roll. Cached waveform playback remains presentation-only and must not draw gameplay RNG
again. This source coupling is intentional compatibility, not a new randomized audio owner.
day_capabilities_ready requires valid clock/data and real ready prop owner. Missing owners
return false; Days retain scheduling authority and do not use success-shaped placeholders.

All29 WORLD_EVENTS remain exact table entries. Implement the finite authored effect map:
cash12/4/3/5/20; cred2/1/5; forget_year brain-3floor0 plus cone; pizza_box gold_tooth;
mom_drives_by brain-3floor0; free_meatball hp12cap; philosopher_man conditional5cash→6cred;
tony_blinks additionally its authored news. Other entries are narration/sfx only; their words
do not spawn fake actors/vehicles or change AI. Order: choose, toast, effect, optional sfx,
first-line lowercase feed, final30% news draw/broadcast. Source event resources have no new
daily cap or save call. Unknown event IDs fail explicitly, never silently skip a future effect.

Ambient phone/random-event timers, incident scheduling, pet-possum spawn/menu and public phone
are still separate remaining rows. This packet does not claim those actions from table/data
presence. Root will call exact active-time timer stages in source order; Days own their
garbage/proud wall callbacks. No communications method advances day, high/crash or player timers.

## Evidence

Unchanged-source oracle covers12 call outcomes, intro/proud gates, each of29 effects and exact
RNG/event ordering, feed truncation/fallback handles/silence,50s ticker rotation and silence
asymmetry, garbage reset/tips retention, source prop fresh/load behavior. Properties cover
invalid clock/no partial mutation, real save projection, weak owners, detached snapshots,
real Street Phone transaction, Day dispatch capabilities and no event-consumer recursion.
Root central gates and actual native/Web feed/choices remain required integration evidence.
