# Tony coat surfaces successor

This draft expands the prior23.5mm shell repair to the visible lapels and covered
shoulders. Production and every previous candidate/evidence directory remain
untouched. No engine, native, Web or Git command has run from this packet.

The existing bare shoulders were wider than the inner cloth at two authored
heights. The lapels also had reversed depth order. The candidate changes only
Tony's existing cloth rings and four middle/inner lapel Z coordinates. It retains
all original rings/triangle counts, materials, surfaces, bones and animations.
Outer lapels, bare torso/neck, cuffs, seams and the three removal states remain.
The new `_coat_shell` construction argument defaults empty, so other callers
retain their original geometry. No new frame-time code is introduced.

`SPEC-DRAFT.md` records the scope expansion and selected coordinates.
`upper-ring-selection.json` retains the .5mm height search and its narrow
predecessor. `rest-witnesses.json` is finite static evidence only: actual posed
geometry must still pass the focused Godot test and new captures.

The initial `rest-initial-unfiltered-backface-diagnostic.json` is deliberately
retained. Its whole-shell front selector included opposite lining faces through
the coat's opening, producing meaningless large negative distances. The current
selector uses the same outward/positive-front rule as the previous accepted shell
test. That correction is a measurement correction, not an art acceptance claim.
Its initialY1.430 top-shoulder result was useful: only1.155mm clearance, leading to
the recorded1.4315 selection. Missing top coverage in the middle coat's actual
neck opening is counted separately; the visible inner coat covers those rays.

The focused successor inherits `test_tony_coat_fit.gd` and its reference builders.
It retains the original1mm shell/resource/bone/71-other-identity conditions and
adds actual four-weight lapel/shoulder surface checks. The only superseded old
assertion is the raw source restriction to a single changed shell: the expanded
allowed Tony parts/rings are now explicit and bounded.

Root stages this candidate Art and new test over the exact previous23.5mm test
composition; no other production changes are implied. Then root serially imports,
runs `test_tony_coat_surfaces.gd`, the retained roster/art gates, and the existing
17-view native/Web proof. Review the original rest/peak-strike and coats2/1 PNGs.
Earlier native/Web17 sets remain successful captures with acknowledged visual
defects, not whole-art acceptance. A passing headless test cannot replace that
new actual visual review.

The focused successor requires four inherited plus two new completion groups,
48 shell poses,48 surface poses and71 other identities. Its exact assertion
count is intentionally unclaimed until the real run. Keep the old fit test as
an inherited reference rather than running its superseded single-part scope
assertion independently. `REVIEW.md` records the bounded static peer review.

Root validation order after isolated import:

1. `--headless --path <isolated-game3d> --script res://tests/test_tony_coat_surfaces.gd`
2. `--headless --path <isolated-game3d> --script res://tests/test_character_roster.gd`
3. `--headless --path <isolated-game3d> --script res://tests/test_art.gd`
4. Existing17-frame native and Web capture/review, with all prior originals retained.

`python -B .build/3d/tony-coat-surfaces-next-draft/verify.py` checks only hashes,
exact source reverse splices and retained evidence. It never launches Godot.
