# SPEC — SMOKE CONCESSIONS (v20 Landing 3)
## Project: Rock Bottom
## Implements: `SPEC-V20-PACKET.md` §2 (OD-5), flavor ratified
## Status: AI-led draft 2026-07-16 · operator veto standing · graduates into SPEC.md on green gate
## Depends on: `src/systems/recognition.js` (Landing 2, merged `ccdbf75`)

---

## WHAT

At `conceded` tier, a venue becomes a **conditional smoke spot**. The Block stays the only
unconditional spot, forever.

Four concessions, flavor locked by the packet:

| Venue | Condition | Ratified flavor |
|---|---|---|
| `park` | night only | the philosopher pretends to be asleep. he is not. |
| `choir_office` | during office hours | office hours are b flat to b flat. |
| `underpass` | while the dog is present | the dog with the lanyard. |
| `laundromat` | mid-cycle only | the dryer provides cover. the dryer knows. |

---

## THE HOOK AUDIT — READ THIS BEFORE ESTIMATING

**Two of the four conditions have real world hooks. Two do not exist at all.** This was checked
in source on 2026-07-16, not assumed. The delta is the entire job.

**EXISTS — use it, do not rebuild it:**
- **night** → `state.dayTime`, driven by the 4-minute day/night cycle at `src/core/update.js:172`.
  Persisted (`audio_save.js:44`, `:212`). **A night predicate is a read, not a feature.**
- **dog present** → `state.freedDogFollowT > 0` (`runtime_ui.js:516`, decremented `update.js:480`).
  The freed dog returns on `state.freedDogT = 90000 + Math.random()*180000` and follows for a
  window. **Presence is already queryable.**

**DOES NOT EXIST — this is the build:**
- **office hours.** There is no hours window anywhere. "b flat" is scattered *flavor* only
  (`runtime_ui.js:182`, `:429`, `:451`; `update.js:364`; a `B FLAT / RECEIVED` prop sign). The
  copper-choir inventory incident is a separate thing and is not an hours system. **A choir-office
  hours window must be authored.**
- **dryer mid-cycle.** No cycle state exists. There is an `incident_dryer` sprite
  (`sprites.js:677`), a `dryer` palette (`:908`), and one line about a dryer running on
  professional courtesy (`neighborhood_a.js:653`). **A dryer cycle must be authored.**

**Do not report Landing 3 as "wire up four conditions." It is two reads and two new clocks.**

---

## DECISION — THE LANYARD IS FLAVOR, NOT STATE (orchestrator call, veto standing)

The packet says *"only while the dog with the lanyard is present."* The lanyard comes from
**encounter #1** in the packet's §4 draft table — and §4 is **not** in the implementation order
ahead of this landing.

**The condition is the dog's presence. The lanyard is a line, not a flag.** Encounter #1 can
later explain where the lanyard came from without touching this condition.

**Why:** coupling a concession to an unbuilt encounter table would make Landing 3 block on
Landing 5. The dog is already there and already comes and goes on its own timer. **The joke
survives either way — the dog does not know it is a condition.**

---

## INVARIANTS

- **I-ONE-LOOP.** ⭐ 18000ms high / 8000ms crash **byte-identical at every spot.** Enforced
  **by construction, not by comparison**: the smoke transaction currently living inline inside
  `blockMenu()` (`src/minigames/activities.js:208-243+`) is **extracted to exactly one exported
  function** that every spot calls. **Copying the transaction and keeping the numbers in sync is
  a violation even while the numbers match.** One loop, many rooms.
- **I-CONCEDED-ONLY.** No concession exists before its venue reaches `conceded`
  (`recognitionTier()` from `recognition.js`). No purchase path. No quest-flag path. No cheat.
- **I-BLOCK-CORONATION.** Royal static stays Block-only. The `state.kingdom.stage==='anoint'`
  branch (`activities.js:234-236`) must **not** fire at a concession. *Royal static is not
  portable.* The extraction is where this gets silently broken — guard it explicitly.
- **I-BAD-IDEA-HONEST.** The BAD IDEA strip may target a concession **only while its condition is
  TRUE**; otherwise it points home. It never advertises a spot you cannot use.
- **I-NO-REWARD.** Unchanged from Landing 2: a concession is permission, not payment. No
  currency, item, combat, or timer change follows from *where* you smoke.
- **I-SOAP-PARITY.** The soap-rock path (`activities.js:217-228`) rides the same extraction and
  behaves identically at every spot. **Soap is soap everywhere.**
- **I-VOICE.** The venue is named in the feed post. `feedPost("smoked a rock at the block...")`
  (`activities.js:242`) is **hardcoded and will lie at a concession.** Venue-aware, lowercase,
  no editorializing, per `VIBE.md`.

---

## EDGE CASES (from the packet, plus what the hook audit surfaced)

- **Condition expires mid-high** → the high completes normally. *The world tolerates what it
  already tolerated.* Never truncate a high because the dryer finished.
- **Save/load mid-high at a concession** → resumes identical to Block behavior. No venue is
  recorded in the high; the high is the high.
- **Two conditions true at once** → BAD IDEA points to the nearer legal spot; **ties go to the
  Block.**
- **Dog leaves while the menu is open** → the option was legal when opened. Re-check at
  *action*, not at *render*, or the menu becomes a lie. Decide once and state which.
- **Night rolls over mid-menu at the park** → same rule as above. One re-check point, documented.
- **All four conditions false** → this is the normal state. The Block is always there. A player
  who never earns a concession loses nothing but rooms.

---

## ACCEPTANCE CRITERIA

- [ ] **One** smoke transaction exists in source. `grep` for `rockedT = 18000` returns exactly
      one assignment site.
- [ ] Four conditional spots, each gated on `conceded` **and** its live condition.
- [ ] Choir-office hours window authored, persisted, and readable in `Q`.
- [ ] Dryer cycle authored, persisted, and legible in-world (the player can *see* mid-cycle;
      an invisible condition is a bug, not a mystery).
- [ ] Royal static provably Block-only — with a test that fails if it fires elsewhere.
- [ ] BAD IDEA never targets an illegal spot; ties resolve to the Block.
- [ ] Soap parity at all five spots.
- [ ] `tools/concession-gate.mjs` authored and wired into `run-gates.mjs` **before**
      `runtime-smoke`. Suite reports **8/8**.
- [ ] `node tools/run-gates.mjs` green. `corpus-gate` included — it runs first now.
- [ ] BRAIN.md appended. DELEGATION.md Landing 3 checked. Register entry added.

---

## THE GATE (`tools/concession-gate.mjs`) — what it must actually prove

A gate that only asserts "the numbers are 18000/8000" is **theater** — it passes a copy-paste
just as happily as an extraction. It must prove:

1. **Single-site**: exactly one `rockedT = 18000` assignment in `src/`. Structural, not numeric.
2. **Identity across venues**: simulate the full smoke at all five spots; diff **every** `P` field
   before/after. Deltas must be identical except the feed text. *(This is the Landing-2
   reward-fingerprint diff, reused. It worked. Steal it.)*
3. **Gating**: each spot rejects below `conceded`, rejects with condition false, accepts with both.
4. **Coronation**: `anoint` + smoke at each concession → stage **unchanged**; at the Block →
   advances. **This one has to fail if the guard is removed. Verify it fails.**
5. **BAD IDEA**: with conditions toggled across all 16 combinations, the target is always legal;
   with two true, it is the nearer; on a tie, it is the Block.
6. **Mid-high expiry**: kill the condition at t=1ms after ignition; the high still runs the full
   18000 and crashes 8000.

---

## THE FAILURE MODE THIS LANDING INVITES

**An eager model will "improve" the smoke while it is holding it.** The extraction puts every
value in the transaction — brain -4, shakes -50, cred +1, the flash, the toast timing — under one
model's hand at one moment, for the first time since v3. **It will look like an obvious place to
tidy up.** It is not. `I-ONE-LOOP` means the loop that comes out is the loop that went in, at the
Block, byte for byte. **A refactor that improves the thing it was moving is not a refactor.**

The second invitation: **making the conditions generous** so the feature "feels good." The
conditions are supposed to bite. A concession you can always use is not a concession — it is a
second Block, and there is only ever one Block.
