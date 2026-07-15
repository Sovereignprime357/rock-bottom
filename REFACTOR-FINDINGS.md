# Refactor findings — v19 modularization

This list records things noticed while moving the frozen v19 build. It is deliberately not a fix list: the modularization wave preserves v19 behavior.

- The 83 dashed comments include 74 top-level seams and 9 nested labels. Six nested labels are branches inside the NPC-AI loop, two are labels inside `spawnNpcs`, and one is inside mobile setup. They cannot be independent modules without changing their containing control flow.
- The original UPDATE section and the v10 building-render section exceed 1,000 lines. UPDATE needs its complete NPC loop extracted as one helper; rendering can split at existing top-level function/comment seams.
- `npcs`, `cashPiles`, and `projectiles` are rebound from multiple systems. They require one shared runtime owner so module imports remain live and writable without a global shim.
- Campaign state, persistence, and startup form function-only import cycles. No module may read those imports during module evaluation; original top-level execution order stays centralized in `src/main.js`.
- `qa_v19_temp.js` contains an outdated normalization expectation (`marks === 0` after advancing to `cart_marks`). It is not a green refactor gate and remains untouched during this wave.
- The browser available in this workspace blocks local `file:///` navigation, while native ES modules require HTTP. Static linking and deterministic VM parity are automated; live visual/audio/keyboard feel still needs a served manual pass.
- The frozen file contains known legacy mojibake, registry omissions, and legibility defects documented in the ratified audits. Those remain byte-for-byte in v19 and are handled only after the behavior-identical refactor lands.
