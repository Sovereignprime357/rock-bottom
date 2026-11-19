# Tony23.5mm refinement

Isolated successor after actual23mm gait failure. Original packet, v1 failure,
v2 diagnostic and all production remain unchanged. This is ready for a single
central refinement run after review; no engine or render acceptance here.

Two overlays only, over the exact prior isolated candidate+diagnostic:

- `game3d/scripts/character_art.gd`: Tony argument0.023→0.0235 only.
- `game3d/tests/test_tony_coat_fit.gd`: the previously authorized candidate-specific
  raw-displacement bound follows the23.5mm cosine profile with exactly the old
  float margin; its message changes accordingly. Every1mm clearance/count/pose
  guard and the final diagnostic print remain exact.

Keep all four original reference test files, roster, animation and other inputs
at the original packet's pins. This packet is not a second production art system.

`python -B .build/3d/tony-coat-fit-refinement-draft/verify.py` checks all hashes,
reverses both overlays to the prior exact candidate/diagnostic, reproduces the
finite static witnesses and pins the actual gait-failure log. It does not copy
files, execute an engine, change evidence or touch production.

Root should stage the prior isolated composition into a fresh project and apply
only these two overlays after verifying their old hashes, then import/run the
same `res://tests/test_tony_coat_fit.gd` with a new absolute log and a finite
watchdog. Require738 checks,4/4 groups,48 cases,71 other identities, exit0, no
script errors and all original assertions. Do not overwrite either failed run.
Only if that passes, continue the retained roster/art gates and original
native/Web views as specified in the parent README. Native/Web remain pending.

Static witnesses, compared with the retained failed23mm candidate:

| Witness |23mm|23.5mm|
|---|---:|---:|
| Rest inner grid |1.229362mm|1.505182mm|
| Rest outer grid |4.690658mm|4.248331mm|
| Off-grid outer collar |2.325197mm|1.881741mm|
| Actual late-walk inner |0.899911mm **FAIL**|unrun|

The original static minimum did not predict the late-gait failure. This table
retains that limit and does not substitute static values for actual weighted
triangles or visual inspection.
