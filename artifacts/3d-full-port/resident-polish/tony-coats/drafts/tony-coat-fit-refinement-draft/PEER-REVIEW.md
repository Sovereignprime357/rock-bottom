# Tony coat fit refinement: bounded peer review

Reviewed on 2026-11-19. No blocker found for the proposed central refinement
run. This is source and static-evidence review, not Godot, rendered or gameplay
acceptance. No production files were edited and no engine or Git command ran.

The reviewed manifest is
`2f04064cc0ffaf087703616119f665a84d7a45b6a6831c3da4091e13c20fcbf0`.
The production candidate is
`9cc532faae1bce276c0dd7843e98c65795b52f7e58c10a6976ca854c1afddd2c`;
the focused diagnostic-test successor is
`0c35355866713e7ea5088bba7b0c8d993097b49ba9ac9cc6fbed817d4c39a13f`.
This review file was written afterward and is not part of that manifest hash.

Independent byte diffs confirm exactly two overlays. The production successor
changes only Tony's middle-coat argument from `0.023` to `0.0235`. Reversing it
restores the prior candidate byte-for-byte. The test successor changes only its
candidate-specific displacement expression and matching assertion message.
Reversing those changes restores the retained diagnostic test byte-for-byte.
No clearance threshold, pose selection, coverage condition, identity comparison,
completion tail, geometry helper, resource or authority owner changed.

The revised displacement expression is
`0.0235*cos(0.45)+(0.02072-0.023*cos(0.45))`, preserving precisely the previous
rounding margin. Its value is `0.021170223551176336` metres; the construction
argument of 23.5mm is not being substituted for the actual raw-vertex bound.
The 1mm inner and outer clearance requirements remain exact, alongside rear/XY
equality, counts, cached-resource checks and the four completion groups. The
48 state/time/coat cases and recursive pose/geometry comparisons for the other
71 identities are unchanged. The new expression introduces no apparent
GDScript syntax or type risk; engine validation remains required.

`python -B .build/3d/tony-coat-fit-refinement-draft/verify.py` completed
successfully. It verified all listed packet and retained-input hashes, exact
reverse overlays and Python syntax, then reproduced the stored finite static
selection. The resulting minima were 1.505182325mm for the inner rest grid,
4.248331484mm for the outer rest grid and 1.881740932mm for the projected
outer-boundary witnesses. The limiting off-grid collar coordinates remain
`x=±0.14527852218710688`, `y=1.3667999505996704`; both are already present in
the unchanged actual-posed test samples.

The selection explicitly identifies 23.5mm as the next authorized 0.5mm step
after the retained 23mm gait failure, rather than claiming it is the minimum
static-rest solution. The prior v1/v2 evidence stays hash-pinned and failed:
walk at time 4.75 with two or three coats had only
`0.000899910926818848` metres of actual inner clearance. The successful static
calculation does not turn that predecessor into a pass or establish successor
pose clearance. The reduced outer clearance also remains visible in the report.

Root must still run the unchanged posed gate against the successor and retain
its actual result, followed by the stipulated roster/art and native/Web visual
checks if it passes. Finite ray and projected-boundary coverage is not a proof
of every continuous-time pose or every garment surface.
