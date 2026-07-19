# Graphics Phase 1 visual acceptance

`phase1-before-after.png` is the operator eye gate for the lighting and grade layer.

- Left: exact branch baseline `6108724b23e113b35d7b7f03be44b3743e48bd3d`.
- Right: Phase 1 candidate from `codex/graphics-phase1-light-grade`.
- Rows: Block; Laundromat / Church; Skid Row.
- Each source capture used the same 800×600 viewport, camera, clock, player state, and staged cop.
- The six individual PNGs are retained so source strength, AO, and emissive details can be inspected
  without the comparison labels.

The measured browser stress fixture used the same 800×600 world canvas with 64 visible cop actors,
64 dynamic cop lights, authored visible props, and Phase 1 AO. After 15 warm-up frames, 120 measured
draws averaged 1.548ms/frame. The temporary fixture was removed after capture; no capture-only code
is present in `index.html` or `src/`.
