# Draft delivery supplement for IMPL-3D-FULL-37

Use a separate supplement or delivery report. Do not append this text to
`SPEC-3D-PARITY-METADATA.md` or `SPEC-3D-FULL-PORT.md`: both are raw-pinned
`metadata-v1` inputs, and changing either would require an explicit reviewed pin
revision. No such revision is proposed.

Preserve the exact reviewed 17-file metadata overlay and 247 input pins. The
finite checkout policy covers 259 explicit paths: 152 LF, 63 CRLF and 44 raw,
including all 33 source evidence files. No evidence normalization or canonical
digest is permitted. Root's recorded checkout with `core.autocrlf=true` must
reproduce all 259 accepted byte hashes; retain its raw report and log. Five raw
index restages are documented separately and do not authorize working-file edits.
Archive focused gate output, including the expected exit-1 `--complete` result
with all 617 refusals. The 30 dispositions and 96 narrow references add scope and
evidence attribution only; all original statuses and platform lists remain
unchanged. Full runners, gameplay/platform acceptance, performance and delivery
remain separate obligations.

The new retained artifact directory must also use the exact rule
`artifacts/3d-full-port/parity-metadata/** -text` before staging raw copies. This
protects new audit bytes without changing any existing evidence pin or source rule.
