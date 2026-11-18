# SPEC — Source Karaoke P09a

Captured before code2026-11-18; root approved exact untimed behavior. Source activities.js186–217,
npc_spawns.js330–345, keyboard.js79–88, runtime_ui.js89–111. Parent full-port/street specs.

RockBottomRhythm(owner,spatial,memory) holds WeakRefs. start_paid_karaoke()->Dictionary is
the single paid entry used by Street. select(token,action)->Dictionary and close() own the
rhythm capability. Root routes domain:"activities", renders normal numbered choices and
calls close on Escape/modal replacement/death/arrest/fresh/restore. No scene/core edits here.

Entry checks current playing/dialogue, no existing live rhythm, bossKind!=kingdom, living
Karaoke Mike, strict60px plus actual LOS, cash>=5 and a real Memory.record dependency.
Refuse before charge/RNG if any preflight fails. Commit5cash once, generate8 source arrows
with seeded random_index4, show first menu and record laundromat/buy/karaoke once.
No new HP/stun/night/daily gate. Source allows repeat sessions.

Actual source has no rhythm timer. The declared WASD keyMap is unused. Standard dialogue
number1–4 or clicks choose ↑,↓,←,→; current correct answer is labeled "(now!)". The fifth
choice is forfeit. There is no beat window, timeout, held-key scoring or invented latency.
Each valid guess increments index exactly once and hits only if it matches. The next page
shows past authored sequence, including missed notes, not a history of attempted inputs.
Source menus use title "· n / 8 ·", text "next: arrow\n\nyour line:\n" plus prior arrows.

After8 guesses, grant3cash per hit and floor(hits/2)cred, coin, exact results toast and save.
Perfect8 additionally grants not_a_phase and authored news. The completion token is consumed
before reward; replay cannot pay again. No reward on forfeit or Escape;5cash is not refunded.
Forfeit gives its source toast; Escape is silent. No save on entry/forfeit beyond independent
recognition effects. Owner resources remain GameState p/s; no local copy of cash/cred.

Sequence/index/hits and action tokens are ephemeral. All next-page tokens revoke prior page,
fresh/restore identities invalidate a session, close discards it, and malformed actions cannot
advance. The paused minigame does not impose another physical-distance/actor-life gate after
entry: source closures can finish after an asynchronous relocation. Session geometry adapter
validates only the active dialogue capability on subsequent pages, not another fee or ray.
No world tick occurs here. Root owns modal pause and cross-domain invalidation.

Tests use unchanged source startRhythmMini and real inline paid callback for menus, mixed
answers,0–8hits, exact history, repeat payout, forfeit and Escape. Properties cover one paid
entry, dependency/LOS/resource refusals, stale pages/state epochs, no repeated charge/recognition,
post-entry relocation/death of singer, and no time-based scoring. Native/Web UI remains root
integration evidence, not a model-gate claim.
