# Tony surface repair: isolated central staging

This is a file-only staging packet. No engine, Git, browser, export or production
write is authorized for its author. Root owns all subsequent engine runs.

The immutable input project is `.build/3d/tony-coat-central-v3-fit/game3d`.
Validate its complete source inventory against that stage's `provenance.json`
(`original` plus `overlays`) before copying. Exclude `.godot`, logs and userdata;
record every excluded path. Reject links/reparse points, unsafe relative names,
unexpected source files, changed input bytes and an existing destination.

Create only `.build/3d/tony-coat-central-v4-surfaces`. Copy the prior source bytes
exactly, then apply exactly two pinned overlays from the surfaces-next draft:

- `scripts/character_art.gd` replaces the prior Art with
  `b8b4b58bd9b5cb8493b0bf56683cb01271df7ed97691c0f70c855d27b0bef5a8`.
- `tests/test_tony_coat_surfaces.gd` is added with
  `dcdc54b8f6bb8dcd3e8c30d1f0c24940cbbcf80785e169f7022335c80db8db86`.

Retain the inherited fit test `0c353558...` and all four original-reference
scripts byte-for-byte. Record source, final and overlay SHA256 inventories,
prior provenance hash, exclusions and fixed engine hashes. No source file is
edited in either the input project or the surfaces-next draft.

Supply a root-owned PowerShell runner for serialized import, the new focused
surface gate, roster and art. All project/log/engine paths are absolute. Every
child has a deadline, bounded output drain and exact-child cleanup; all outputs
and errors are retained without overwrite. Require exit zero, expected PASS
receipts, no script/error/leak diagnostics and complete surface counters:
four inherited plus two surface groups, 48 shell plus 48 surface poses and
71 other identities. Do not invent a total assertion count.

The runner verifies the staged source before and after each child. Only Godot's
cache directory and the new focused test's generated UID are allowed additions;
existing source bytes remain immutable. Give each runner invocation a new output
directory and child-only APPDATA/LOCALAPPDATA roots. The stage is evidence of
exact bytes prepared, not proof that the parser, geometry gate or rendered art
passes. No native or Web acceptance is implied.
