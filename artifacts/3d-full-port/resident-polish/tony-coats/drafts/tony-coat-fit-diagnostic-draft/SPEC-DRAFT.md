# Tony coat focused-gate diagnostic successor

Root's actual v1 import passed; focused execution exited1 after all4 groups,
with2 failures/738 checks. The inherited `_check` collected failed messages but
the focused runner printed only a count. Preserve the original candidate,
test, native logs and failed result. Do not infer which conditions failed.

This successor changes only the focused test's final reporting. Emit the exact
collected failure array as JSON, plus the existing group/case/identity counts,
inner/outer ray totals and measured current/original/outer minima. No assertion,
threshold, tested action, geometry, helper or completion counter changes.
Keep the original quit exit-code expression. Nonfinite diagnostic minima are
represented as null, so the evidence remains valid JSON rather than inventing a
finite measurement.

The sole overlay is `game3d/tests/test_tony_coat_fit.gd`, admitted only over its
exact original1f5b732b... hash. Candidate Art remains a4a935c2...; the accepted
original packet remains immutable. Root stages this in a separate isolated
project/output and runs the same focused test. A useful diagnostic is not a
geometry pass. No engine, production edit, Git or acceptance promotion here.
