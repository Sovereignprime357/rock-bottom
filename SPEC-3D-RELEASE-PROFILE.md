# SPEC — reproducible native release measurement

Captured before implementation,2026-11-18. The existing actual60 probe measures the real full
scene, source AI, rigs, quality and frame work. Running it with the editor executable is a useful
diagnostic but is not a release-template measurement. The player build must be measured too.

`game3d/tools/profile-release.ps1` accepts a committed revision, bounded120..1200 frame count,
and an explicit diagnostic switch. It archives that exact repository revision's game3d files
into a newly named directory under `.build`, imports the isolated copy, and uses the official
pinned4.5.1 Windows release template. Only the isolated export configuration changes: retain
the production full_port feature, Compatibility rendering and source assets, while including
the actual existing performance probe script. Production export presets and the live workspace
are never temporarily rewritten. No branch/worktree changes, cleanup deletions or network.

Run the release executable with the same probe script, source controls, quality,60 real actors,
warmup, timing thresholds and isolated QA storage. No disabled AI, alternate dt, special damage
rules, visibility setting, injected clones or outlier removal. Diagnostic mode records failures;
it cannot turn a failing measurement into acceptance. Actual final performance still requires
the representative full-duration probe, Web evidence and all existing count/physical checks.

Record the resolved commit, engine/template versions and hashes, executable hash, individual
source hashes from the archived files, and all output paths in a provenance JSON next to the
probe report. Compiled PCK resource hashing may be unavailable at runtime; external archived
source hashes remain authoritative. Reject archive/import/export failures and logs containing
engine errors. Start the helper hidden, report liveness within30 seconds, wait for its exit and
propagate a nonzero exit or missing report. Keep every snapshot for inspection; no auto-delete.

The next native measurement must say whether it used the editor or release template. Do not
compare results from changing working trees as if they measured the same source.
