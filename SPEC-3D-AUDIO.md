# SPEC — Full-source synthesized audio P15

Captured before code, 2026-11-18; Root approved the bounded full-only audio owner,
ambient owner and compatibility adaptations below. `synth.gd` and the six original
slice PCM sounds remain unchanged. Root owns FullRuntime/FullScene composition.

## Source and ownership

`src/core/audio_save.js255–319` owns tone/noise primitives and24 recipes. Preserve
every recipe's waveform, frequency/range, duration, gain, exponential frequency
slide and relative note delay. Includes hit/hurt/pickup/coin/rockUp/crash/death/
rankUp/dialogue/copSiren/bossRoar/glassBreak/cricket/traffic/carDoor/cough/dogBark/
windup/bottleThrow/bottleHit/holyWaterThrow/holyWaterHit/radio/kick. No external
samples or music. FullScene sends source IDs directly; no rockUp→slice high alias.

`RockBottomSourceAudio` is a single Node used only by FullScene. API retains
`ready_for_sound`, `muted`, `players`, `play_sound(kind)->bool`; adds
`advance_wall(monotonic_ms)->bool`, readonly `metrics()` and static recipe/PCM
inspection helpers for tests. PCM is cached before play, never built per frame.
Root advances wall time in every mode. Only an actual user key/click unlocks sound;
no audible startup. The accepted dialogue-choice click is source dialogue sound,
including leave; disabled/stale choices and Escape do not beep.

Each tone/noise start independently checks current ready/mute state. A recipe's
future notes are still scheduled while muted/unready, matching source setTimeout;
they may sound if unlocked/unmuted by their due time. Immediate notes are never
replayed later. Changing mute does not stop voices already started. Queued notes
survive pause/title/fresh/restore, matching uncancelled source callbacks. They end
only when fired/dropped or the audio Node is destroyed. Equal-due notes retain
enqueue order. Late wall advancement starts due notes once at the current wall
time, matching delayed browser callbacks; no gameplay clock owns these notes.
Invalid/backwards time and unknown IDs refuse without queue/resource mutations.
The production wall queue is pumped once per rendered Scene frame. Cue origins
use that frame's monotonic timestamp (at most one rendered-frame quantization),
and deferred0 notes wait for the next pump. Do not pump again inside a nested
input/event callback: source setTimeout cannot fire before its current task ends.

## Explicit bounded synthesis adaptations

Source WebAudio oscillators/noise are recreated as mono22050Hz16-bit cached PCM.
Tone amplitude follows its source exponential ramp from gain to0.0001 over dur;
frequency slides exponentially to max(slide,20), with oscillator phase integrated
over the ramp. Source oscillator stop includes20ms at final gain/frequency. Noise
uses a deterministic independent stream, linear(1-i/count) taper and source gain.
Sampled waveforms approximate WebAudio oscillators; no claim of bit-identical
WebAudio output or anti-aliasing implementation. A conservative fixed master gain
applies equally to all full-source clips. No new master/gameplay mute state.

Eight deterministic variation banks bound random pitch/noise resources. Every
random frequency remains in its source half-open range; fixed recipes keep exact
parameters. Cosmetic recipe variation, noise synthesis and ambient scheduling use
independent PRNG streams and never touch GameState RNG. This intentionally removes
source's device/sample-rate/ready/mute-dependent noise RNG coupling from new audio.
Existing model compatibility draws (notably Communications traffic) remain intact;
playback does not consume them again. Oracle records original coupling separately.

32 audio voices and256 pending notes are fixed bounds. When full, drop the newest
note/voice request deterministically; retain existing work. Expose queued/started/
suppressed/dropped counts for diagnostics, without player-facing text or gameplay
events. A recipe may partially sound under overload, as an explicit presentation
limit. No unbounded cache or timer allocation follows spam or a large wall delta.

## Ambient source clock

`RockBottomAmbientAudio(state, cosmetic_seed)` has a weak host and sole mutable
clock `s.ambientT`; no second clock. `tick_active(dt_ms)->bool` accepts finite
positive steps up to50ms. Runtime calls after companion/chained-dog processing
and before Conductor/actor/pickup remainder, following update.js508–525. It does
not add a mid-step mode guard: the accepted source update completes its remainder.
Root does not call it for paused/cookmini/hitpause steps.

Exact clock semantics: `(ambientT||4000)-dt`; on<=0 reset3500+roll*4500 and make
one choice, not a catch-up loop. Night is dayTime<.25 or>.75. Night thresholds
.5/.7/.85 choose cricket/dogBark/cough/carDoor; day thresholds.4/.6/.75 choose
traffic/dogBark/cough/carDoor. Positive wanted adds a separate strict<.3 siren
roll. No intro or silence flag suppresses this scheduler. Emit existing sound
events; audio's current user/mute gate decides audible starts.

`reset_session(cold|fresh|restore)` explicitly rebinds p/s identity. Same-session
fresh/load carry the prior ambientT exactly as source overlay updates do; cold
missing ambientT remains missing until first active step. Unexpected replacement
refuses mutation until explicit reset. AmbientT stays unsaved, with source zero
truthiness reset and no silently introduced timer. The scheduling PRNG survives
same-session reset, independently from the synthesis variation/noise streams.

## Evidence

Unchanged-source oracle executes all24 recipes and scheduled callbacks with fake
WebAudio primitives; records params/delays and mute/readiness timing, plus separate
noise/sample-rate/global-RNG characterization. Ambient fixtures run actual source
updateWorld with other clocks suppressed and audio calls traced, testing source
thresholds/clock truthiness/silence/wanted/fresh/load. Compatibility adaptations
are separate properties, not relabelled as original source output.

Godot gates compare all banks' plans, wall/equal-due timing, readiness and mute
transitions, bounded saturation, immutable cache reuse, finite PCM and analytic
envelopes/frequencies/noise bounds, actual gain/duration, reset/epoch behavior and
unchanged gameplay RNG. Root must integrate and verify native/Web audible controls,
18s high→8s crash and actual cues before claiming full audio parity.

## Global mute while cooking — 2026-11-18

Source keyboard.js68 handles M before cooking and shows `muted.` / `unmuted.`
for800ms. FullScene therefore dispatches pressed, non-repeat M after its existing
readiness/loading guard and before cookmini. Reuse the existing audio ready/muted
fields and toast/HUD consumer. Do not pump audio wall time, beep, restart voices,
advance heat/world clocks, consume resources or replace the active menu.

Retain the existing3D title/paused/dialogue/ending mute scope and non-repeat policy;
only the formerly swallowed cooking input and missing receipt are corrected.
The source title ignores M and source repeat can toggle it repeatedly; this bounded
change deliberately preserves the established3D policy for those cases. Loading,
not-ready, key-up and repeat remain inert. Actual heat input tests verify unchanged
heat/player/RNG, real cue gating and the exact800ms receipt.
