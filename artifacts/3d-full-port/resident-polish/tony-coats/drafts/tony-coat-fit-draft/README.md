# Isolated Tony coat-fit candidate

Status: source/static preparation only. Production is untouched. No Godot,
native/Web render, gameplay acceptance, performance pass or promotion is claimed.
Input context `fac5083` is supplied by root; `BASELINE.json` pins the observed
files independently. No Git was used for this packet.

The candidate adds one default-zero construction argument and passes 23mm only
for Tony's middle coat. Each front vertex moves by that value times its original
positive cosine (actual maximum 20.71mm). Rear vertices and all X/Y coordinates
stay exact. The other coat, lapels, seam pieces, colors, rigs and actions are
unchanged. No second mesh copy or per-frame work is added.

`selection.json` records a bounded rest-space choice, not a rendered result:
3,538 original inner/middle triangle samples select 23mm at 1.229mm minimum
clearance; the 22.5mm predecessor fails the unchanged 1mm threshold. Another
10,156 middle/outer samples give 4.691mm minimum outer clearance, including the
shoulder/collar region. A separate369-point projected triangle-boundary check
finds a tighter off-grid2.325mm clearance; that exact collar witness is also in
every posed outer-layer check. These are different finite reconstruction scopes,
not a continuous-surface guarantee. Actual weighted-pose clearance must still pass.

`EDITS.json` is the complete four-edit production recipe. `prepare.py verify`
reverses it to the exact original bytes. It also reverses the four test-reference
class/preload normalizations and pins all dependencies. References duplicate no
production authority: they are isolated test-only original mesh builders.

The focused test checks 48 pose/time/coat combinations: rest, walk, windup and
peak strike at three animation times, each with 3/2/1/0 coats. It intersects actual
weighted triangles in a chest-relative coordinate frame and requires nonempty
coverage plus the original overlap witness. The outer-shell guard includes
additional dense collar/shoulder rays. It also checks retained geometry/cache
contracts and exact arrays, materials, transforms and poses of all 71 other
identities. Four completion tails prevent an aborted test from claiming success.
This gate is authored but unrun; failures must be diagnosed rather than weakening
the clearance/count constraints.

## Root-owned validation

First verify this packet with Python only:

```powershell
python '.build/3d/tony-coat-fit-draft/prepare.py' verify
```

Root must create a fresh isolated project under `.build`, with all pinned
dependencies, no `.godot` directory and no preexisting overlay receipt. Then:

```powershell
python '.build/3d/tony-coat-fit-draft/prepare.py' overlay --project 'C:/Users/zenit/projects/Rock Bottom/.build/3d/tony-coat-validation/game3d' --write
```

The helper refuses changed inputs, prior new test files, outside paths, symlinks
or junctions. It writes only the six listed overlays and an exact overlay receipt.
It does not archive, import, launch an engine or write production. All copies are
prepared and checked before the first write; an interrupted copy is not reusable.

Root's serialized engine commands, with fresh absolute log paths:

```powershell
$engine = 'C:/Users/zenit/projects/Rock Bottom/.tools/godot-4.5.1/Godot_v4.5.1-stable_win64_console.exe'
$project = 'C:/Users/zenit/projects/Rock Bottom/.build/3d/tony-coat-validation/game3d'
$logs = 'C:/Users/zenit/projects/Rock Bottom/.build/3d/tony-coat-validation'
& $engine --headless --path $project --editor --import --quit --log-file "$logs/import.log"
& $engine --headless --path $project --script res://tests/test_tony_coat_fit.gd --log-file "$logs/focused.log"
& $engine --headless --path $project --script res://tests/test_character_roster.gd --log-file "$logs/roster.log"
& $engine --headless --path $project --script res://tests/test_art.gd --log-file "$logs/art.log"
```

Use root's finite runner/watchdog and require actual completion markers, exit0,
and no script errors. The focused gate has finite 48+71 cases but no own wall
watchdog; an engine timeout is a failure, never a test pass.

The existing base native probe includes Tony's coat-removal views along with the
other five original identities. Run that base path for the retained comparisons:

```powershell
& $engine --path $project --script res://tests/character_roster_probe.gd --log-file "$logs/native.log" -- '--output=C:/Users/zenit/projects/Rock Bottom/.build/3d/tony-coat-validation/native'
```

The current probe covers front/quarter rest, walk, strike/peak, hurt/death, 20m and
all removal counts. Root should additionally capture windup and the comparable
Web views using existing capture seams. Preserve original captures; review that
green slivers disappear, all three layers remain distinct and no new middle/outer
or lapel clipping is introduced. The focused geometry gate does not replace that
visual acceptance. No browser evidence exists for this candidate yet.
The optional `--ids=tony` selector takes a different profile path and does not
include the base probe's four coat-removal views; it is only a quick extra view.
