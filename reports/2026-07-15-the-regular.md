# Completion report — THE REGULAR (SPEC-V20-PACKET item #2)

**Date:** 2026-07-16 · **Builder:** Fable (Claude Code, headless)
**Branch:** `v20-regular` (from `main` @ `ce70ae3`) · **Pushed to origin:** yes · **Merged to main:** no (as instructed)

## Commits

| Hash | What |
|------|------|
| `a103265` | codex WIP cherry-picked (`-x` from `1248cea`): recognition counters + tier text + 10 integration edits + SPEC/register drafts |
| `e6eece3` | permanent recognition gate + run-gates wiring + register status note + BRAIN log |

## WIP-review justification (keep / rewrite / reimplement)

**Verdict: KEEP the WIP intact; add the one missing artifact.**

Codex's `1248cea` was reviewed line-by-line against SPEC-V20-PACKET §1 and the four HARD RULES. It conforms on every axis, so a rewrite would have been churn:

- **Acknowledgment only.** `recordRecognition` mutates only `state.recognition`, the ephemeral `state.recognitionVisit`, and the toast/feed/save surfaces. It touches no `cash`, `rocks`, `hp`, `cred`, `rank`, `shakes`, `brain`, `speed`, faction, `rockedT`, or `crashT`. Verified mechanically by the gate's reward-fingerprint diff across a full 15-verb climb and across the full_high boundary.
- **Additive save.** One new top-level `recognition` key; `SAVE_KEY`/version stay `10`; existing payload shape untouched; `normalizeRecognition` rebuilds a clean null-proto ledger on load. Roundtrip preserves state (gate-asserted).
- **Clerical ≤ 50%.** 12 venue/tier beats, 3 clerical = 25%. On-voice: lowercase fragments, flat landings, packet beats reproduced verbatim ("the dry committee stops recounting when you pass", "the bench develops your dent", "the philosopher pretends to be asleep. / he is not.").
- **No decay; tiers derived, never saved; `sell` a dormant schema lane** — all as the packet and OD-7 require.
- **Frozen constants.** No timing/balance/id/sprite change; `full_high` credits exactly once at the existing `rockedT>0 → 0; crashT=8000` transition and changes neither constant. `rock_bottom_v19.html` never touched.

The one genuine gap was the permanent gate the SPEC landing itself names (`tools/recognition-gate.mjs`) — codex left it unwritten. That is the whole of the second commit. OD-7 (thresholds `3/8/15`, per-visit free-verb dedup, dormant `sell`) originated in the WIP; it is **carried forward, not independently re-ratified**, and remains operator-veto-standing. Flagged in the register status note.

## Files touched (branch vs `ce70ae3`)

New:
- `src/systems/recognition.js` — the system (venues, tiers, counters, reactions, record/normalize/persist)
- `tools/recognition-gate.mjs` — permanent gate

Integration edits:
- `src/main.js` — `init_recognition()`
- `src/core/start.js` — fresh recognition + visit on new game
- `src/core/audio_save.js` — save/load the additive `recognition` key
- `src/core/update.js` — `syncRecognitionVisit()` per frame; `recordFullHighAtPlayer` at the high→crash boundary
- `src/core/runtime_ui.js` — THE REGULAR block in the Q ledger (tiers, remembered total, non-zero verbs)
- `src/systems/interactions.js` — `recordNpcBother` on NPC interact
- `src/systems/campaigns.js` — choir-office `bother` on the wire door read
- `src/data/npc_spawns.js` — laundromat `buy` credits (laundry / detergent / karaoke)
- `src/dialogue/vendors_places.js` — park `sit`, laundromat Barb `buy`
- `src/dialogue/neighborhood_b.js` — park `buy` (pigeon secret)
- `tools/run-gates.mjs` — recognition gate wired ahead of runtime smoke

Docs:
- `SPEC.md` — "v20 landing 2 — THE REGULAR recognition ledger" (from WIP)
- `REFACTOR-FINDINGS.md` — OD-7 (from WIP) + 2026-07-16 status note (this session)
- `BRAIN.md` — session log

## Gate runner output (`node tools/run-gates.mjs`)

```
MODULE GATE: PASS (37/37 chunks extracted, 40 JS files linked)
NPC REGISTRY GATE: PASS (55 canonical rows, 59 source identities, 56 runtime actors/45 identities, 4 aliases, 1 generated family, 60 actor sites)
LEGIBILITY GATE: PASS (24 signs, 23 zone labels, 56 active nameplates, 14 fitted tags)
PRESENTATION GATE: PASS (6 viewport fixtures, 1 rideable cart, 106.2px nearest NPC, ordinary/Big Guy/save paths)
RECOGNITION GATE: PASS (4 venues, 5-lane schema, 12 beats/3 clerical, stranger->conceded ladder, zero reward leakage, high-boundary 18000->8000, malformed-save + save/load roundtrip)
RUNTIME SMOKE: PASS (56 NPCs, WASD chord/release, exact 18s->8s status, dialogue, 373 sprite keys, save/load)
GATE RUNNER: 6/6 PASS
```

## What the recognition gate proves

Registry/threshold contract (4 venues, `sit/bother/buy/sell/full_high`, `3/8/15`, tier-derivation boundaries); the **stranger→counted→furniture→conceded ladder reachable via simulated paid verbs** at totals 3/8/15; **zero reward-state leakage** across the whole climb and across the full_high boundary; free-verb **per-visit dedup** (repeat E-press cannot grind; the same source re-credits only after leaving and re-entering); **wrong venue/source rejection** (park verb rejected in the laundromat, pigeon rejected off-park, unknown npc/action/venue rejected); **full_high at the exact 18000→8000 boundary** with the status transition unchanged; **no idle-frame decay**; **malformed-save normalization** (negatives clamp, fractions floor, non-finite/non-numeric zero, unknown venue/action keys dropped, null-proto); **save/load roundtrip** with version pinned at 10 and the `recognition` key present.

## Not done / deferred (out of scope for item #2)

- Concessions (§2): conceded venues becoming conditional smoke spots — next landing.
- World-relationship gate (§4).
- `sell` stays a dormant, normalized lane until an honest hook exists (no relabeling of trades).
- Live in-browser feel pass of the toast/feed/Q surfaces — the deterministic gate is not a playtest; operator playtest still owed.

## Definition-of-done checklist

- [x] All gates green (6/6)
- [x] Coherent commit(s) on `v20-regular` (`a103265`, `e6eece3`)
- [x] Branch pushed to origin
- [x] Not merged to main
- [x] Append-only register status note
- [x] Completion report committed on the branch
- [x] Worktree returned to `main`
