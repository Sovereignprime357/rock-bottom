# SPEC-V20-PACKET — the recognition wave

status: AI-led draft 2026-07-15 · operator veto standing · sections graduate into SPEC.md as each system implements and its gates pass. Register: OD-5 (+ forthcoming entries per system).

## NORTH STAR (VIBE amendment, ratified)

success is the neighborhood adjusting around you. recognition without reward. the ladder is not upward — the throne was a lawn chair. it is inward.

## 1. THE REGULAR — recognition system

WHAT: per-venue counters on repeated verbs (sit, bother, buy, sell, carry a full high through). Tiers per venue: stranger -> counted -> furniture -> conceded. Tier effects are acknowledgment only — text, placement, world reaction. Never stats, cash, discounts, damage, or timers. The form has no social authority; the pigeons do.

Tier beats (voice reference):
- counted: the dry committee stops recounting when you pass.
- furniture: the bench develops your dent. yuri starts the receipt before you speak.
- conceded: the venue tolerates the loop (section 2).

INVARIANTS:
- recognition counters persist in save as NEW additive keys; existing save shape untouched.
- no recognition effect grants currency, items, combat, or timer changes.
- tier text obeys the pattern-rotation cap (clerical <= 50% of new permanent-loop beats).
- recognition never decays in v20 (revocation belongs to a future heat system; out of scope).

## 2. SMOKE CONCESSIONS (OD-5)

WHAT: at conceded tier, a venue becomes a CONDITIONAL smoke spot. The Block is the only unconditional spot, forever.

The four v20 concessions (flavor locked; coordinates at implementation):
- the park bench — night only. the philosopher pretends to be asleep. he is not.
- the choir office — during office hours. office hours are b flat to b flat.
- the underpass — only while the dog with the lanyard is present.
- the laundromat vent — mid-cycle only. the dryer provides cover. the dryer knows.

INVARIANTS:
- 18000ms high / 8000ms crash byte-identical at every spot. one loop, many rooms.
- the BAD IDEA strip may target a concession only while its condition is TRUE; otherwise it points home.
- no concession exists before its venue reaches conceded tier. no purchase path. no quest-flag path.
- campaign coronation still requires the Block (royal static is not portable).

EDGE CASES:
- condition expires mid-high -> the high completes normally. the world tolerates what it already tolerated.
- save/load mid-high at a concession -> resumes identical to Block behavior.
- two conditions true at once -> BAD IDEA points to the nearer legal spot; ties go to the Block.

## 3. WAVE-4 BUDGETS (relationships, written down)

- RUNWAY RULE: no mandatory route/campaign leg may exceed 60% of a fresh shakes runway in travel time at walk speed. Constant measured by fixture at implementation (findings evidence: full crossing 74.6s vs 100s runway).
- COVERAGE RULE: with all four concessions earned, no map point sits farther than ~45s walk from a POTENTIALLY legal spot; the Block alone must cover every day-1 strip objective.
- TRANSPORT: the rideable cart stays unique. No fast travel in v20 — concessions ARE the fast travel, thematically.
- Population/prop density and minimap legibility rows: deferred to implementation fixtures — measured, not vibed.
- GATE: new permanent world-relationship gate computes runway + coverage from route/venue tables; fails on regression. "Make it bigger" can never again outrun its budgets silently.

## 4. ENCOUNTER TABLE (v20 draft, pattern-capped: 2/10 clerical)

1. inverted authority — the dog has acquired a lanyard. the lanyard has a photo. it is not of the dog.
2. bad trade — a man sells you tomorrow's weather for $3. it is accurate once. he is gone by the time it is accurate.
3. cursed aside — the fountain coughs twice. then once. that one was for you.
4. possum pattern — the possum in the construction helmet has been promoted. nothing else changed. the helmet is the same helmet.
5. clerical — the choir office issues you a visitor badge. laminated. your name is spelled almost right. it expires in b flat.
6. bad trade — the pigeon king offers secrets for bread. the secret is where the bread went.
7. inverted authority — a traffic cone has been given a small vest. traffic obeys the cone now. it always did.
8. cursed aside — @blocklog posts: he is still here. that is the whole post. (fires at first counted tier)
9. clerical — a census taker counts you twice. refuses to fix it. the second one is for the road.
10. mundane > magical — someone anointed the bus stop. the bus does not know. the bus will never know.

## 5. IMPLEMENTATION ORDER

1. HUD deconfliction + cart repro (delegation already cut — smallest, fire first)
2. THE REGULAR counters + tier text
3. concessions + BAD IDEA condition logic
4. world-relationship gate
Each lands behind green gates with its own register entry. Veto anything above by name.
