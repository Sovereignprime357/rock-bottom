# P05e — carried tools and visible clothing

Approved bounded presentation packet, captured before code. Source: actors_weather.js367–378
draws coat, route patch, shoes, hat, tool, then the independent weapon; tool art has no attack
phase. sprite_art_player_32.js281–337 defines the four coats, footwear and two tools.
catalogs.js21–46 defines actual slots. Existing P01/P05c/Cart contracts remain binding.

## Context and ownership

Extend first_person_rig.gd set_context with optional `tool`, `coat`, `shoes` fields. Each accepts
null/empty String/StringName for none or an exact ID from the relevant source slot. Omitted
fields retain context. Validate every supplied known field before applying any; malformed
type/unknown ID rejects the entire context without side effects. Reset clears these fields;
Root reapplies current equipment after new/load/death. Never retain a caller dictionary.

- tool: propane_torch, crowbar; static supported_tools returns exactly these two IDs.
- coat: trench, windbreaker, bathrobe, parka.
- shoes: airpods, crocs, walmart_sneak, vibrams. Airpods stays the default foot because the
  source shoe-slot object is actually worn at the ear. Do not fabricate an airpod-shaped shoe.

Public tool/coat/shoes report selected presentation context only. Root supplies the actual
`runtime.p.equip` slot values in FullScene's existing context snapshot. Inventory ownership or
Pete's locker must never display a carried item. No new input, action ID, tool-use animation,
Combat/catalog entry, damage, cooldown, resource, equipment mutation, event, light/emitter,
smoke procedure or gameplay clock. The source dumpster direct-tool overwrite remains as-is.

## Tools and hands

Use cached original low-poly meshes in a separate left-wrist HeldTool socket and hidden pool,
with real finger/thumb grip, stable tool_grip_marker and tool_id metadata. The source's
simultaneous tool/weapon layers become low offhand tool plus unchanged dominant weapon in
first person. Torch: squat brass reservoir, dark neck, nozzle, paper mark and small static
sodium-colored pilot shape. Crowbar: municipal rust-red shaft, hooked upper end, flattened
foot and worn cream property mark. Neither can be selected as a weapon or alter used_weapon.

The tool stows for a left-fist swing, receipt, both-hand bench/dumpster gesture or an active
cart left-hand grip. It can remain during an independent right-hand weapon/food/phone action.
During smoke it stows entirely: the abstract existing smoke gesture gains no equipment or
preparation detail. Restore the CURRENT equipped tool after interruption/recovery; no queue,
transaction delay, long equip sequence or visual-tool snapshot may govern gameplay. An accepted
punch always retains existing immediate visual motion and immutable original weapon capture.

## Visible clothing

Keep existing sleeve meshes/pivots; select immutable cached fabric materials and modest radial
fullness per coat. Source palette: trench rust with cream seam, windbreaker fluorescent purple
with yellow trim, bathrobe dirty cream with purple trim, parka mold with yellow trim. None
restores the original mold sleeves/cuffs exactly. Geometry/resource changes occur only at
construction or context change; never rebuild a mesh/material on tick. No gloves or new hands.

The existing kick foot keeps its timing/pose/collision-free behavior. Three cached alternatives
show the red single croc, dirty-cream sneakers, or copper/orange five-toe footwear. Empty/airpods
use the original worn shoe. Weapon `shoe` is Tony's separate weapon and must not change with
footwear. Hats/collar and chest route patches are off-camera in the existing arm-only viewmodel;
this packet does not invent floating headgear or relocate chest patches onto the wrists.

All new mesh leaves have shadows disabled, no collisions/process/audio/light nodes, finite
geometry and immutable cross-instance resources. Existing center/near-plane, sprint/look,
high/crash/shakes, pause/reset and cart tests remain unchanged. Tools stay low and readable;
no hidden mesh may leak from the parked pool.

## Files and evidence

Owned: first_person_rig.gd plus new test_viewmodel_gear.gd and viewmodel_gear_probe.gd. Root owns
FullScene context wiring, engine/import/gates/native/Web/git. Existing accepted tests remain
unchanged. New tests cover exact source slot IDs, null/omission/atomic failure, independent
resources and no mutation, actual finger/tool contact, simultaneous weapons, left/right
attacks, receipt/smoke/cart stow and current-tool recovery, garment/shoe source distinctions,
and actual visible geometry bounds across movement/actions. Probe captures both tools with
fists/armed/rest/actions/cart, coat sleeves and kick shoes in production lighting. Acceptance
requires native inspection in addition to passing mathematical gates.
