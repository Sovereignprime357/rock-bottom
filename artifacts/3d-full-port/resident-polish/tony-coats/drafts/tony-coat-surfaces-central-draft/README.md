# Prepared Tony surface validation stage

File-only handoff; no engine has been run by this packet's author. The stage is
`.build/3d/tony-coat-central-v4-surfaces/game3d`.

`prepare.py` reconstructs the prior v3 inventory by applying its two `[old,new]`
overlay pairs to `original`, then checks the actual 509 source files. It copies
those exact bytes with one Art replacement and one new focused test, producing
510 source files. It preserves `test_tony_coat_fit.gd` (`0c353558...`) and all four
reference scripts. The old fit test is inherited, not invoked separately with
its superseded one-part raw-scope assertion.

The resulting provenance records the original/final SHA256 maps, two overlays,
excluded cache/log/userdata paths and both official Windows executable pins.
The Art hash is `b8b4b58bd9b5cb8493b0bf56683cb01271df7ed97691c0f70c855d27b0bef5a8`.
The new test hash is `dcdc54b8f6bb8dcd3e8c30d1f0c24940cbbcf80785e169f7022335c80db8db86`.
The unchanged legacy comment about the middle coat's back describes the lower
front-fit step; the approved upper-ring changes also affect the upper back.

File-only verification, from the repository root:

```powershell
python -B '.build/3d/tony-coat-surfaces-central-draft/prepare.py' verify-inputs
python -B '.build/3d/tony-coat-surfaces-central-draft/prepare.py' verify-stage
```

The stage command has already been used once. It rejects an existing destination
and must not be repeated or used to replace retained evidence.

Root-owned engine invocation, only when the serialized queue is available:

```powershell
& 'C:/Users/zenit/projects/Rock Bottom/.build/3d/tony-coat-surfaces-central-draft/run-validation.ps1'
```

The runner creates a fresh `validation-v1` output directory inside the v4 stage;
an existing directory is refused. An explicitly supplied `-OutputDirectory` must
be a fresh absolute subdirectory of that same stage, outside `game3d`.
It uses `ProcessStartInfo.ArgumentList` (no string-built shell arguments), hidden
children, absolute engine/project/log paths and child-only APPDATA/LOCALAPPDATA.
Four serialized commands are constructed as follows, each prefixed by the pinned
console executable and `--headless --path <absolute-v4-game3d> --log-file
<absolute-output/name.godot.log>`:

| Name | Remaining arguments | Deadline |
|---|---|---:|
| import | `--editor --import --quit` | 180 seconds |
| surfaces | `--script res://tests/test_tony_coat_surfaces.gd` | 600 seconds |
| roster | `--script res://tests/test_character_roster.gd` | 300 seconds |
| art | `--script res://tests/test_art.gd` | 180 seconds |

Each child has a bounded 10-second stream drain and, if needed, a separate
10-second exact-child cleanup wait. Completed stdout/stderr are retained on
failure; incomplete streams and cleanup failures remain explicit in the result.
Source hashes are checked before/after every command and again on failure.
Only `.godot` cache files and the new test's generated UID may be added inside
the project. All existing source bytes must stay exact.

Exit zero alone is insufficient: the runner requires clean error/leak logs,
the official engine receipt and each gate's PASS marker. The focused diagnostic
must report zero failures, 4 inherited + 2 surface groups, 48 shell + 48 surface
poses and 71 other identities. The assertion total is deliberately not predicted.
No native or Web appearance, performance or shipping acceptance follows from
preparing this stage or from passing its headless gates.
