# SPEC — source startup publications and conditional cash

Captured before implementation on 2026-11-18. This bounded correction composes existing
GameState, Runtime and Communications owners. Source authority is `src/core/start.js:143–153`
and `src/data/npc_spawns.js:368–390`. It does not change original source or save schema.

After a successful fresh/load reconciliation, mode is playing. Before Runtime returns, emit
the original wake toast: fresh unfinished intro uses the four-line4200ms text; loaded uses
the three-line3500ms text. Then publish the exact `@crackheadcent` wake post, the exact
`@tony_observer` morning post, and current source rank-name news, in that order. Existing
queued feed/news from earlier startup work must precede these publications. Use the real
Communications queue flush so its current silence predicate applies at call time. No second
feed, ticker, RNG or timer owner. Feed remains session-global, newest-first and capped at8;
repeat fresh/load appends another source pair, and active silence suppresses feed/news but
never the wake toast. Invalid/rejected load cannot publish. Cold title construction does not
publish. The existing3D load modal remains a separate presentation choice.

The publication suffix consumes zero gameplay RNG: both handles are explicit, rank lookup
is deterministic, and source toast/news do not randomize. Characterize this with unchanged
`startGame` and real source Communications, including all rank names, exact silence boundary,
repeat start and current-day posts. This packet does not claim whole-start RNG equivalence.
Missing/non-array hustle fallback is a separately identified integration obligation.

Fresh cash roster uses source fixed positions. On restore, regenerate conditional intro
membership as source `spawnCashPiles`: omit `cp_intro_remember` when introDone or already
collected; retain all ordinary piles with collected flags. Schema1 migration already sets
introDone and must omit the intro pile too. No resource/reward/collected-ID mutation accompanies
this reconciliation. The current cash-pile array is the sole pickup authority: existing
Runtime ID lookup must reject a stale removed intro ID before cost/reward/receipt changes.

Preserve the source lifecycle quirk: completing intro in an already-running session does
**not** remove its existing uncollected intro pile. Do not add a blanket `introDone` guard to
every pickup. Its eligibility ends at the next source start/load roster construction. Fresh
starts create it again; repeated restore neither adds duplicates nor pays a reward.

Evidence: new unchanged-source startup oracle/fixture and focused `test_startup_parity.gd`,
plus the existing State/Runtime/Communications suites. Test cold/no publications, source suffix
RNG independence, fresh/load/repeat/silence, invalid load, collected/uncollected intro variants,
same-session late pickup, stale removed pickup and schema1 migration. Parent serializes engine
checks and actual Scene/native/Web validation; this spec is not a completion claim.

## Missing/non-array saved hustles — separate approved correction

Source `audio_save.js:135` maps absent/non-array hustles to null; `start.js:124–140` performs
cash/interactive initialization, wall layouts, equipment stats, conditional `rollHustles`,
`ensureBlockRoute`, then Office/Kingdom reconciliation and forces. Preserve the **raw array
shape decision** before core normalization: absent, null, scalar and object request one roll;
an explicit empty or populated array never requests a replacement roll. Existing safe hustle
normalization still drops invalid IDs and replaces saved descriptions/rewards with canonical
definitions. No raw reward data is copied back after normalization.

Runtime invokes the existing progression owner after wall preparation and before route rolling.
The existing merged Campaign reconciliation includes source `audio_save.js:199–219` loaded
defeat/flag witness repairs; it must retain its position before route unlock filtering. This
packet does not move that accepted reconciliation or claim full load/start phase equivalence.
Core already applies equipment stats during validated player restore;
this earlier pure normalization consumes no RNG and cannot influence wall layout. Equipment
must be applied by the first hustle draw. Completed/dead actor eligibility uses the restored
roster. Intro-incomplete fallback produces no jobs/draws; schema1 migration completes intro
and has no saved hustle field, so it requests the same fallback explicitly.

Actual Scene loading first builds a safely placed normalized candidate. Root's Scene seam must
preserve only this raw shape distinction: absent/non-array/schema1 becomes a null or absent
hustles field in the candidate envelope; an array keeps its normalized contents. It must never
reinsert raw arrays or rewards. Runtime does not add a new persistent marker or schema field.

Before changing production, extend the unchanged-source startup oracle with seeded actual
`startGame(true)` observations. Trace RNG stage order (interactive bottle, graffiti/poster,
hustles, route), exact resulting seed/jobs/route, equipment at first hustle draw, valid versus
regenerated walls, missing versus valid route, dead-vendor eligibility, intro suppression and
raw hustle shape. Real captured Courier metrics must supply wall widths. Focused tests compare
the same source seeds and outputs; existing explicit-array saves must retain their former RNG
and no refreshed jobs. This correction intentionally changes only source-missing fallback paths.

Seed characterization from the unchanged-source oracle (`0x19c0ffee` =432078830):

| Restored shape / setup | RNG stages | Correct final seed |
| --- | --- | --- |
| Missing/null/scalar/object; valid walls and route |24 bottles →13 hustles |1519427481 |
| Explicit empty or valid jobs; valid walls and route |24 bottles |1123532582 |
| Missing jobs and route; valid walls |24 bottles →13 hustles →10 route |1817249595 |
| Missing jobs/walls/route, seed432078830 |24 bottles →85 graffiti →31 posters →13 hustles →10 route |174564623 |
| Same rebuild, seed1 |24 bottles →85 graffiti →36 posters →13 hustles →10 route |357326185 |
| Same rebuild, seed4294967295 |24 bottles →127 graffiti →36 posters →13 hustles →10 route |345046489 |
| Missing jobs/route, three dead fighters; valid walls |24 bottles →12 hustles →10 route |944564300 |
| Intro unfinished; missing jobs/walls/route |24 bottles →85 graffiti →31 posters |987771242 |

These are whole observed-start seeds with real interactive initialization enabled. Models
without that owner have a different starting stream; do not use this table to loosen arbitrary
seed assertions. Explicit-array saves retain prior seeds. Equipment stats at the first hustle
draw are observed in the fixture, and publication suffix still adds zero draws.
