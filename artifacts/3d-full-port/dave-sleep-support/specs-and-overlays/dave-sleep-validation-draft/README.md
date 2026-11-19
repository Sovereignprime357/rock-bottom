# Root-owned Dave validation helpers

Separate from the immutable art packet. These helpers have not executed Godot,
export, native rendering, browser or Git. The selected source is the retained
exact 495-file resident archive, not a newly inferred checkpoint snapshot.

Root can start the serial focused import + five gates:

```powershell
pwsh -NoProfile -File .build/3d/dave-sleep-validation-draft/run-focused.ps1 -RunName focused-v1
```

The helper creates a fresh `.build/full-port/dave-sleep-validation/focused-v1/`,
never reuses one, and records `staging.json`, raw per-stage logs and
`focused-result.json`. Tests use absolute script and project paths. Native/Web
acceptance remains false after all five headless tests pass.

After those gates, root can prepare separate visual projects without starting
any engine:

```powershell
python .build/3d/dave-sleep-validation-draft/stage.py --run native-v1 --mode Native
python .build/3d/dave-sleep-validation-draft/stage.py --run web-v1 --mode Web
```

Each `staging.json.commands` contains the exact executable/argument arrays for
root's existing serial engine launcher. Native supplies an output path that is
deliberately not created (the existing probe requires a fresh evidence directory).
Web supplies import/export commands and prepares its two byte-pinned sidecars in
`web/`. Export creates `index.html`; root must retain complete export hashes and
serve it with the established local Web harness. No automatic browser or extra
attempt is scheduled by this packet. Keep its same three original captures,
ordinary Start/wake/Leave/movement, 960x540 Web frame and 120-second watchdog.

Both visual modes overlay the one Animator owner plus the unchanged ground-v2
test wrapper/helper. Web additionally needs only the unchanged shell/bridge and
test export preset. No other old-project production files are copied. The wrapper
is checked byte-exact against the archive with only its passive measurement line
removed. Validate retained prepared source before/after root commands:

```powershell
python .build/3d/dave-sleep-validation-draft/stage.py --verify C:/absolute/repo/.build/full-port/dave-sleep-validation/native-v1
```

`static-check.py` validates pins, all archive source bytes, the actual wrapper
reversal, original input inventories, and helper scope without staging or engine
execution. Independent World review of the immutable Animator/test packet found
no actionable blocker; actual geometry/contact, engine and rendered outcomes
remain unclaimed. Original ground-v1/v2, wake/laundry and index evidence stay raw.
