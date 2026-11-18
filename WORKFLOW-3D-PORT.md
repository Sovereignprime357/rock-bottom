# Bounded full-port workflow

Root integrates `codex/3d-full-port` under `SPEC-3D-FULL-PORT.md`. The operator authorized sustained
implementation until complete, including computer-use inspection.

## Agent protocol

At most three workers alongside root. Every packet has one owner, exact writable files, source
references, API, acceptance and a stop boundary. Read VIBE before edits. No cross-packet edits,
contract changes, Godot/import/export runs or worker commits/pushes. Root serializes engine and
browser runs and owns shared integration. Report a needed contract change before crossing it.

Cycle: audit -> spec/API -> implement -> independent review -> production gates -> rendered
native/Web exercise -> evidence -> commit checkpoint. Failures return to the owner. No no-op
dialogue, unreachable systems or ID-only tests count as parity. Planned/partial stays explicit.

## Packet ledger

| Packet | Bound | Dependencies | State |
| --- | --- | --- | --- |
| P00 | Complete source inventory and parity manifest | baseline | 32 features/585 handlers recorded; semantic mapping ongoing |
| P01 | Natural hands/controller and contextual gestures | full-port spec | 41 checks, native poses/real-time tour, Web movement/punch/menu exits checked |
| P02 | Canonical data export, hashes, identity/world catalogs | P00 | 4116 checks pass; full geometry integration pending |
| P03 | Full state/items/equipment/resources/ranks/save migration | P00/P02 | foundation211 checks pass; economy585 checks/23 fixtures pass, scene pending |
| P04 | World geometry/roads/structures/props/service points | P02 | P04a full geometry/navigation implementing |
| P05 | Canonical cast rigs, locomotion/gaze/gestures/culling | P02/P04 | P05a API review |
| P06 | Vendor/resident dialogue and validated interactions | P02/P03/P05 | planned |
| P07 | Combat, weapons/projectiles, bosses, police/arrest | P03/P05 | planned |
| P08 | Factions/territory, quests/hustles/block routes | P03/P06/P07 | P08a 898 checks/31 source fixtures pass; scene/individual quests pending |
| P09 | Cooking/heat/activities/dumpster minigames | P03/P06 | planned |
| P10 | Recognition/concessions/discovery/soap/hitter | P03/P06/P08 | model421 checks pass against13 source fixtures; scene/menu integration pending |
| P11 | Copper heists/break-ins/robbery/tools/locker | P03/P04/P06/P07 | planned |
| P12 | Hideouts/stash/cart/bus/travel budgets | P03/P04/P08 | planned |
| P13 | Office/district claims/kingdom/endless succession | P07/P08/P12 | planned |
| P14 | Communications/incidents/weather/day events/achievements | P03/P05/P08/P13 | planned |
| P15 | Full HUD/map/panels/audio/animation integration | P01/P06..P14 | planned |
| P16 | Complete parity audit/performance/native-Web tours/delivery | all | planned |

Split into smaller subpackets when needed. Parallel packets require disjoint files/agreed APIs.
Root owns `main.gd`, gate runner, shared specs and persistence until explicitly delegated.

## Current assignments

- architecture_review: P03a state foundation complete in review; P03b economy/action-boundary API proposal next.
- slice_world: P04a `SPEC-3D-WORLD-BUILD.md`, `full_neighborhood.gd`, `test_full_world.gd`.
- slice_characters: P01 rig correction reviewed; P05a actor-rig API proposal next.
- root: goal/contracts/ledger, P08a progression, memory loop, integration and serialized validation.

## Evidence

Create a machine-readable parity manifest with source IDs, implementation/test refs and honest
status. A coverage gate catches missing/duplicate records; semantic review and gameplay prove
behavior. Store gate output, visual evidence, hardware/quality measurements and tours per
milestone. Append BRAIN/register at committed checkpoints. Complete the goal only after P16 and
all parity rows are verified.
