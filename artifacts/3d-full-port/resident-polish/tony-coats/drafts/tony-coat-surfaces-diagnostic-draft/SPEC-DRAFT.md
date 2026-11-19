# Diagnostic successor for the first expanded-surface gate

The retained actual v4 gate completed all1357 assertions and all4+2 groups,
48+48 poses and71 other identities, but failed48 assertions. Exactly three are
raw attribute comparisons on parts14/15/16;45 are sample-count completeness
checks. All reported geometric gaps exceed1mm, no cloth coverage is missing,
and the adverse-gap witness list is empty. This is evidence of where to inspect,
not proof that the candidate is acceptable.

Prepare a test-only diagnostic successor of held focused testdcdc54b8. Keep
Artb8b4, every test condition, threshold, pose, bound and completion tail exact.
No geometry, engine, production or earlier evidence changes. Emit actual raw
channel differences (channel/type/size and bounded first differing elements),
and bounded first failed body self-ray samples with their authored barycentric
weights, posed triangle, projection determinant and recomputed barycentric
values. Count every skipped self-ray even when only a bounded sample is printed.
Do not replace an absent cloth ray with a plane or relax any1mm condition.

These diagnostics establish whether the derived attribute and boundary-ray
assumptions are legitimate. Only after actual results may a separate successor
correct the test, or the Art candidate if the measured contract is violated.
Root owns the finite engine run; current failedv4 remains immutable.

The diagnostic stage is freshly copied from the same immutable v3 fit project,
with the exact b8b4 Art and this diagnostic test. Relative to failedv4's prepared
source, only the focused test changes. Preserve the0c35 inherited fit/reference
builders and all existing finite runner limits. The run is expected to FAIL the
same conditions; this is deliberate diagnostic evidence, never a passing gate.
