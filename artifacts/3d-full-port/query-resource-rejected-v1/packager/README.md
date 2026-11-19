# Rejected query-resource pair: evidence-only package

Root decision: reject promotion, retain the existing unpooled Adapter. This
packet copies existing evidence bytes only. It does not execute an engine,
export, profile, Git operation, or modify the candidate or production sources.

The finite allowlist retains the two raw reports, eight original PNGs, both
provenance records, all run logs, comparison, the compact independent audit,
one common source archive, and exact wrapper/workload/candidate overlays. The
two executables are deliberately not copied; their hashes remain in the raw
provenance and hash-only entries. The duplicate common archives are similarly
represented by their hashes. No evidence is compressed, converted or rewritten.

`package.py --check` validates every input before any copy. The root may then
run `package.py --output artifacts/3d-full-port/query-resource-rejected-v1`.
The destination must be a fresh directory inside this repository. Every file
is opened exclusively and verified again after copying. An interrupted partial
output is retained and must never be overwritten by another invocation. The
packager writes only its own new receipt after the original files have copied.

No performance, gameplay, Web, shutdown or promotion acceptance is implied by
successful evidence packaging. The original strict failures remain unchanged.
