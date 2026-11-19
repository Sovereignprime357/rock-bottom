extends SceneTree
## Root runs this serially: --headless --path game3d --script res://tests/test_interactive_prop_view.gd
const World = preload("res://scripts/full_neighborhood.gd")
const Adapter = preload("res://scripts/world_adapter.gd")
const Content = preload("res://scripts/content_catalog.gd")
const Props = preload("res://scripts/prop_state.gd")
const Actions = preload("res://scripts/interactive_prop_actions.gd")
const Combat = preload("res://scripts/combat_system.gd")
const View = preload("res://scripts/interactive_prop_view.gd")
var checks: int = 0
var groups: int = 0
var failures: Array[String] = []

class FixedState extends "res://scripts/game_state.gd":
	var rolls: Array[float] = []
	var cursor: int = 0
	func random_float() -> float:
		var value: float = rolls[cursor] if cursor < rolls.size() else 0.75
		cursor += 1
		return value
class PhysicsWorld extends Node3D:
	var service_points: Dictionary = {}
	func obstacle_records() -> Array: return []
class WatchingAdapter extends "res://scripts/world_adapter.gd":
	var probe_view: Node3D
	var begins: Array[Dictionary] = []
	var stages: Array[Dictionary] = []
	func _init(world_node: Node3D,game_state: RefCounted) -> void: super(world_node,game_state)
	func _live_counts() -> Dictionary:
		var bodies: int = 0; var services: int = 0; var obstacles: int = 0
		if probe_view != null:
			for index: int in range(14):
				var body: StaticBody3D = probe_view.collider("interactive:%d" % index)
				if body != null and body.collision_layer != 0: bodies += 1
		for key: String in _world().service_points:
			if key.begins_with("interactive:"): services += 1
		for row: Dictionary in _navigation._records:
			if str(row.owner).begins_with("interactiveProps:"): obstacles += 1
		return {"bodies":bodies,"services":services,"obstacles":obstacles}
	func begin_interactive_epoch() -> bool:
		var previous: Dictionary = _live_counts()
		var result: bool = super.begin_interactive_epoch()
		begins.append({"cursor":_host().cursor,"before":previous,"after":_live_counts(),"certificates":_interactive_approaches.size()})
		return result
	func stage_interactive_prop(id: String,kind: String,desired: Vector2,maximum_px: float = 100.0) -> Variant:
		stages.append({"id":id,"cursor":_host().cursor,"live":_live_counts()})
		return super.stage_interactive_prop(id,kind,desired,maximum_px)

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _owner(index: int) -> String: return "interactiveProps:%d" % index
func _id(index: int) -> String: return "interactive:%d" % index
func _tagged(world: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child: Node in world.find_children("*","MeshInstance3D",true,false):
		if str(child.get_meta("source_owner","")).begins_with("interactiveProps:"): result.append(child as MeshInstance3D)
	return result
func _nav_rows(adapter: RefCounted,owner: String = "") -> Array:
	var result: Array = []
	for row: Dictionary in adapter._navigation._records:
		if owner.is_empty() or row.owner == owner: result.append(row.duplicate(true))
	return result
func _revision(adapter: RefCounted) -> int: return int(adapter.navigation_metrics().revision)
func _visual_live(slot: Node3D) -> bool:
	if slot == null: return false
	for mesh: MeshInstance3D in _tagged(slot):
		if mesh.is_visible_in_tree(): return true
	return false
func _source_position(game: RefCounted,center: Vector2) -> void:
	game.p.x = center.x-float(game.p.w)*0.5; game.p.y = center.y-float(game.p.h)*0.5
func _model(rig: Dictionary) -> Dictionary:
	return {"p":rig.game.p.duplicate(true),"s":rig.game.s.duplicate(true),"props":rig.props.interactive_records(),"events":rig.game.events.duplicate(true),"rng":rig.game.cursor}
func _sync(rig: Dictionary) -> bool:
	var before: Dictionary = _model(rig)
	var records: Array = rig.actions.render_records()
	var untouched: Array = records.duplicate(true)
	var accepted: bool = rig.view.sync(records)
	_check(_model(rig) == before and records == untouched,"view sync neither changes model/RNG/events nor its detached input")
	return accepted
func _ray_owner(world: Node3D,point: Vector2,height: float) -> String:
	var center: Vector3 = Content.to_world(point,height)
	var query := PhysicsRayQueryParameters3D.create(center+Vector3(0.45,0,0),center-Vector3(0.45,0,0),1)
	query.hit_from_inside = true
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	return str(hit.collider.get_meta("source_owner","")) if hit.get("collider") is CollisionObject3D else ""
func _capsule_clear(world: Node3D,at: Vector3) -> bool:
	var capsule := CapsuleShape3D.new(); capsule.radius = 0.48; capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new(); query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY,Vector3(at.x,Adapter.FEET+0.9,at.z)); query.collision_mask = 1; query.margin = 0.002
	return world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func _solid(world: Node3D,at: Vector3,size: Vector3,owner: String) -> StaticBody3D:
	var body := StaticBody3D.new(); body.collision_layer = 1; body.collision_mask = 0; body.set_meta("source_owner",owner)
	var shape := BoxShape3D.new(); shape.size = size
	var collision := CollisionShape3D.new(); collision.shape = shape; body.add_child(collision)
	world.add_child(body); body.global_position = at
	return body
func _inactive(rig: Dictionary,label: String) -> void:
	for index: int in range(14):
		var slot: Node3D = rig.view.slot(_id(index)); var body: StaticBody3D = rig.view.collider(_id(index))
		_check(slot != null and not _visual_live(slot),label+" hides original mesh descendants "+_id(index))
		_check(body != null and body.collision_layer == 0,label+" disables actual collider "+_id(index))
		_check(not rig.world.service_points.has(_id(index)) and _nav_rows(rig.adapter,_owner(index)).is_empty(),label+" removes service/nav "+_id(index))

func _full_world() -> void:
	var world := World.new(); world.dynamic_interactive = true; root.add_child(world); world.build()
	await physics_frame; await physics_frame
	var meshes: Array[MeshInstance3D] = _tagged(world)
	_check(meshes.size() == 28 and world.source_records.get("interactiveProps",{}).size() == 14,"dynamic world retains all28 original meshes and14 coverage records")
	if meshes.size() != 28: world.free(); return
	var originals: Dictionary = {}
	for mesh: MeshInstance3D in meshes:
		originals[mesh.get_instance_id()] = {"node":mesh,"mesh":mesh.mesh,"material":mesh.material_override,"name":mesh.name,"owner":mesh.get_meta("source_owner"),"aabb":mesh.get_aabb()}
		_check(not mesh.visible,"dynamic seed mesh is hidden before model placement")
	for body: Node in world.find_children("*","StaticBody3D",true,false):
		_check(not str(body.get_meta("source_owner","")).begins_with("interactiveProps:"),"dynamic mode creates no seed interactive physics body")
	for obstacle: Dictionary in world.obstacle_records():
		_check(not str(obstacle.owner).begins_with("interactiveProps:"),"dynamic mode contributes no seed interactive navigation footprint")
	var game := FixedState.new(); game.npcs.clear(); game.s.mode = "playing"
	var adapter := WatchingAdapter.new(world,game); var props := Props.new(game); var combat := Combat.new(game,adapter)
	var actions := Actions.new(game,adapter,props,combat)
	var view := View.new(); world.add_child(view)
	var rig: Dictionary = {"world":world,"game":game,"adapter":adapter,"props":props,"combat":combat,"actions":actions,"view":view}
	_check(actions.ready(),"actual model stages before a view exists")
	# Malformed ownership must not partially adopt an otherwise complete world.
	var missing: MeshInstance3D = meshes[0]; var previous_parent: Node = missing.get_parent(); var previous_index: int = missing.get_index()
	previous_parent.remove_child(missing)
	_check(not view.bind(world,adapter,actions),"missing tagged mesh refuses binding")
	previous_parent.add_child(missing)
	previous_parent.move_child(missing,previous_index)
	var duplicate := MeshInstance3D.new(); duplicate.mesh = missing.mesh; duplicate.material_override = missing.material_override
	duplicate.set_meta("source_owner",missing.get_meta("source_owner")); world.add_child(duplicate)
	_check(not view.bind(world,adapter,actions),"duplicate tagged geometry refuses binding")
	duplicate.free()
	var unknown := MeshInstance3D.new(); unknown.mesh = missing.mesh; unknown.set_meta("source_owner","interactiveProps:14"); world.add_child(unknown)
	_check(not view.bind(world,adapter,actions),"unknown interactive source owner refuses binding")
	unknown.free()
	_check(meshes.all(func(mesh: MeshInstance3D): return mesh.get_parent() == world),"failed bindings leave original geometry unadopted")
	_check(view.bind(world,adapter,actions),"complete original geometry binds once")
	adapter.probe_view = view
	adapter.bind_interactive_props(actions,view)
	_check(view.bind(world,adapter,actions),"same owners can bind idempotently")
	_check(_sync(rig),"first committed14-row snapshot accepted")
	await physics_frame; await physics_frame
	var live_cans: Array[String] = []; var live_bottles: Array[String] = []
	for index: int in range(14):
		var id: String = _id(index); var row: Dictionary = actions.render_records()[index]
		var slot: Node3D = view.slot(id); var body: StaticBody3D = view.collider(id)
		_check(slot != null and body != null and view.collision_rid(id) == body.get_rid(),"stable cached slot and collider RID "+id)
		if slot == null or body == null: continue
		_check(body.get_meta("source_owner","") == _owner(index),"live collider retains source identity "+id)
		var pieces: Array[MeshInstance3D] = _tagged(slot)
		_check(pieces.size() == 2,"exactly two adopted original parts "+id)
		for piece: MeshInstance3D in pieces:
			var old: Dictionary = originals.get(piece.get_instance_id(),{})
			_check(not old.is_empty(),"view adopts existing MeshInstance rather than replacing it "+id)
			if old.is_empty(): continue
			_check(is_same(piece.mesh,old.mesh) and is_same(piece.material_override,old.material) and piece.name == old.name and piece.get_meta("source_owner") == old.owner and piece.get_aabb() == old.aabb,"original mesh/material/name/geometry identity preserved "+id)
		var shapes: Array[Node] = body.find_children("*","CollisionShape3D",true,false)
		var shape_node: CollisionShape3D = shapes[0] as CollisionShape3D if shapes.size() == 1 else null
		_check(shape_node != null and shape_node.shape is CylinderShape3D,"upright collider remains one cylinder "+id)
		if shape_node != null and shape_node.shape is CylinderShape3D:
			var cylinder: CylinderShape3D = shape_node.shape as CylinderShape3D
			_check(is_equal_approx(cylinder.radius,0.30 if index < 6 else 0.065) and is_equal_approx(cylinder.height,0.76 if index < 6 else 0.25),"original physical cylinder dimensions "+id)
		if not row.placed or row.pending: continue
		if index < 6: live_cans.append(id)
		else: live_bottles.append(id)
		_check(_visual_live(slot) and body.collision_layer == 1,"placed upright record visible and physically enabled "+id)
		var point := Vector2(row.x,row.y)
		_check(_ray_owner(world,point,0.38 if index < 6 else 0.125) == _owner(index),"actual ray finds current prop body "+id)
		_check(world.service_points.has(id) and world.service_points[id].source_point.is_equal_approx(point),"service uses accepted live source point "+id)
		var approach: Vector3 = adapter.interactive_approach(id,point)
		_check(approach.is_finite() and _capsule_clear(world,approach),"actual full player capsule fits approach "+id)
		if not approach.is_finite(): continue
		_source_position(game,Content.to_source(approach))
		if index < 6: _check(adapter.can_reach_target(id),"own can collider is allowed by actual eye LOS "+id)
		else: _check(adapter.can_hit(game.player_center(),point,"player",id),"own bottle collider is allowed at bottle target height "+id)
	_check(not live_cans.is_empty() and not live_bottles.is_empty(),"full world supplies real can and bottle witnesses")
	if not live_cans.is_empty(): await _can_pose_and_reach(rig,live_cans[0])
	if not live_bottles.is_empty(): await _bottle_lifecycle(rig,live_bottles[0])
	await _epoch_restage(rig)
	await _invalid_and_cleanup(rig)
	world.free(); await physics_frame; await physics_frame
	groups += 1

func _epoch_restage(rig: Dictionary) -> void:
	var rolls: Array[float] = []
	for index: int in range(8):
		rolls.append((float(index)+0.25)/16.0); rolls.append(0.5); rolls.append(0.5)
	var expected: Array = []
	for pass_index: int in range(2):
		var previous_transforms: Array[Transform3D] = []
		if pass_index == 1:
			# Deliberately obstruct the next first bottle with OLD other-slot bodies.
			# Reset must disable these before querying any new desired point.
			for index: int in range(14):
				var body: StaticBody3D = rig.view.collider(_id(index)); previous_transforms.append(body.transform)
				body.global_position = Content.to_world(Props.BOTTLE_INITIAL_POINTS[0],0.38 if index < 6 else 0.125)
			await physics_frame; await physics_frame
		rig.game.p = rig.game.p.duplicate(true); rig.game.rolls.assign(rolls); rig.game.cursor = 0
		rig.adapter.begins.clear(); rig.adapter.stages.clear()
		_check(rig.actions.reset_session("restore"),"explicit new epoch stages successfully")
		_check(rig.game.cursor == 24 and rig.adapter.begins.size() == 1,"new epoch clears once before exactly24 source bottle draws")
		if not rig.adapter.begins.is_empty():
			var begin: Dictionary = rig.adapter.begins[0]
			_check(begin.before.bodies > 0,"epoch-clear witness starts with live old prop bodies")
			_check(begin.cursor == 0 and begin.certificates == 0 and begin.after == {"bodies":0,"services":0,"obstacles":0},"begin clears all old bodies/services/navigation/certificates before RNG")
		_check(rig.adapter.stages.size() == 14,"all14 slots stage once in the new epoch")
		if not rig.adapter.stages.is_empty():
			_check(rig.adapter.stages[0].cursor == 24 and rig.adapter.stages[0].live == {"bodies":0,"services":0,"obstacles":0},"first physical query occurs after draw24 with no old prop blockers")
		var rows: Array = rig.actions.render_records()
		if pass_index == 0: expected = rows.duplicate(true)
		else:
			_check(rows == expected,"old other-prop collider locations cannot perturb identical new-epoch placement")
			for index: int in range(14): rig.view.collider(_id(index)).transform = previous_transforms[index]
		_check(_sync(rig),"new epoch view adopts accepted current placements")
		await physics_frame; await physics_frame
		var revision: int = _revision(rig.adapter); var counts: Dictionary = rig.adapter._live_counts()
		rig.adapter.begins.clear(); rig.adapter.stages.clear()
		_check(rig.actions.reset_session("restore") and rig.game.cursor == 24,"same-epoch reset consumes no new draws")
		_check(rig.adapter.begins.is_empty() and rig.adapter.stages.is_empty() and _revision(rig.adapter) == revision and rig.adapter._live_counts() == counts,"same-epoch reset does not clear or restage live props")
		var certificates: int = rig.adapter._interactive_approaches.size()
		_check(rig.adapter.begin_interactive_epoch() and _revision(rig.adapter) == revision and rig.adapter._live_counts() == counts and rig.adapter._interactive_approaches.size() == certificates,"direct same-epoch begin preserves live geometry and certificates")

func _can_pose_and_reach(rig: Dictionary,id: String) -> void:
	var row: Dictionary = rig.props.interactive_record(id); var slot: Node3D = rig.view.slot(id)
	var body: StaticBody3D = rig.view.collider(id); var point := Vector2(row.x,row.y)
	var revision: int = _revision(rig.adapter); var collider_transform: Transform3D = body.global_transform
	var before: Dictionary = _model(rig)
	for repeat: int in range(4): _check(rig.view.sync(rig.actions.render_records()),"identical source pose accepted")
	_check(rig.view.sync_current(),"single-pull authoritative snapshot accepted")
	_check(_revision(rig.adapter) == revision and _model(rig) == before,"identical snapshots never rebuild topology or mutate model")
	var art: Node3D = slot.get_node("Art"); var resting: Transform3D = art.transform
	row.tipT = 200.0; row.rotPulse = 200.0; _check(_sync(rig),"source kick pose accepted")
	var supplied_pose: Transform3D = art.transform
	_check(rig.view.sync_current() and art.transform == supplied_pose,"single-pull path applies identical live source pose")
	_check(not art.transform.is_equal_approx(resting),"actual original meshes respond to source kick timers")
	var paused_pose: Transform3D = art.transform
	await process_frame; await physics_frame
	_check(art.transform.is_equal_approx(paused_pose),"view owns no elapsed-time animation")
	for ignored: int in range(4):
		rig.actions.tick(50.0); _check(_sync(rig),"active source timer progression accepted")
		_check(_revision(rig.adapter) == revision and body.global_transform == collider_transform,"200ms wobble keeps stable actual footprint and nav index")
	_check(art.transform.is_equal_approx(resting),"zero source timers restore exact upright pose")
	var direction := Vector2.ZERO
	for candidate: Vector2 in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
		var near: Vector2 = point+candidate*49.99
		if not _capsule_clear(rig.world,Content.to_world(near)): continue
		_source_position(rig.game,near)
		if rig.adapter.can_reach_target(id): direction = candidate; break
	_check(direction != Vector2.ZERO,"real can has a strict-radius cardinal witness")
	if direction == Vector2.ZERO: return
	_source_position(rig.game,point+direction*50.0)
	_check(not rig.adapter.can_reach_target(id) and rig.actions.kick(id).get("reason") == "out_of_reach","exact50px rejects in adapter and action owner")
	_source_position(rig.game,point+direction*49.99)
	var service: Dictionary = rig.world.service_points[id]
	var eye: Vector3 = Content.to_world(rig.game.player_center(),Adapter.FEET+1.63)
	var blocker: StaticBody3D = _solid(rig.world,eye.lerp(service.target,0.5),Vector3(0.3,0.4,0.3),"view_test_los")
	await physics_frame; await physics_frame
	before = _model(rig)
	_check(not rig.adapter.can_reach_target(id) and not rig.actions.kick(id).ok,"fresh eye ray rejects unrelated solid")
	_check(_model(rig) == before,"blocked kick has no timer/RNG/resource/events")
	blocker.free(); await physics_frame
	_check(rig.adapter.can_reach_target(id),"removing actual blocker restores access")

func _bottle_lifecycle(rig: Dictionary,id: String) -> void:
	var row: Dictionary = rig.props.interactive_record(id); var old := Vector2(row.x,row.y)
	var index: int = int(id.trim_prefix("interactive:")); var slot: Node3D = rig.view.slot(id); var rid: RID = rig.view.collision_rid(id)
	var approach: Vector3 = rig.adapter.interactive_approach(id,old)
	if not approach.is_finite(): return
	_source_position(rig.game,Content.to_source(approach)); rig.game.p.weapon = "fists"; rig.game.p.attackCd = 0.0
	rig.game.rolls.assign([0.5,0.75]); rig.game.cursor = 0
	var before_revision: int = _revision(rig.adapter)
	var result: Dictionary = rig.combat.attack_player((old-rig.game.player_center()).normalized())
	_check(result.ok and row.get("broken",false),"real Combat capability shatters reachable bottle")
	_check(_sync(rig),"broken source snapshot accepted"); await physics_frame; await physics_frame
	_check(not _visual_live(slot) and rig.view.collider(id).collision_layer == 0 and not rig.world.service_points.has(id),"broken bottle loses upright geometry collider and service")
	_check(_ray_owner(rig.world,old,0.125) != _owner(index) and _nav_rows(rig.adapter,_owner(index)).is_empty(),"old bottle location has no ghost body or nav entry")
	_check(_revision(rig.adapter) > before_revision,"actual broken state invalidates navigation")
	var selected: int = -1
	for candidate: int in range(12):
		var desired: Vector2 = Props.BOTTLE_INITIAL_POINTS[candidate]
		if desired.distance_to(old) < 100.0: continue
		var staged: Variant = rig.adapter.stage_interactive_prop(id,"b_bottle",desired,100.0)
		if staged is Vector2: selected = candidate; break
	_check(selected >= 0,"source respawn pool has a separate usable physical destination")
	if selected < 0: return
	var desired: Vector2 = Props.BOTTLE_INITIAL_POINTS[selected]
	# A real opaque volume covers every permitted recovery point, including full approach clearance.
	var blocker: StaticBody3D = _solid(rig.world,Content.to_world(desired,1.5),Vector3(10,3,10),"view_test_respawn_blocker")
	await physics_frame; await physics_frame
	rig.game.rolls.assign([(float(selected)+0.25)/12.0,0.5,0.5]); rig.game.cursor = 0; row.respawnT = 1.0
	_check(rig.actions.tick(1.0) and rig.game.cursor == 3,"expiry rolls exactly one source candidate and jitter pair")
	_check(_sync(rig),"physically pending respawn accepted"); await physics_frame
	var pending: Dictionary = rig.actions.render_records()[index]
	_check(pending.pending and not pending.placed and row.broken and not _visual_live(slot),"blocked respawn stays pending and absent")
	_check(rig.view.collider(id).collision_layer == 0 and not rig.world.service_points.has(id) and _nav_rows(rig.adapter,_owner(index)).is_empty(),"pending placement creates no invisible target service or obstacle")
	for ignored: int in range(5): rig.actions.tick(50.0)
	_check(rig.game.cursor == 3 and rig.actions.render_records()[index].pending,"blocked retries preserve the already rolled intent without RNG")
	blocker.free(); await physics_frame; await physics_frame
	for ignored: int in range(5): rig.actions.tick(50.0)
	_check(not row.broken and rig.game.cursor == 3,"clear retry commits the same intent without reroll")
	_check(_sync(rig),"accepted moved bottle snapshot syncs"); await physics_frame; await physics_frame
	var now := Vector2(row.x,row.y)
	_check(now.distance_to(desired) <= 100.0001 and now.distance_to(old) > 1.0,"respawn remains bounded to its rolled source candidate")
	_check(rig.view.slot(id) == slot and rig.view.collision_rid(id) == rid,"break and respawn reuse exact slot and collision body")
	_check(_ray_owner(rig.world,old,0.125) != _owner(index) and _ray_owner(rig.world,now,0.125) == _owner(index),"actual ray sees relocated body only at its new point")
	_check(rig.world.service_points.has(id) and rig.world.service_points[id].source_point.is_equal_approx(now) and _nav_rows(rig.adapter,_owner(index)).size() == 1,"service and one owner nav entry follow new accepted position")
	_check(not rig.adapter.interactive_approach(id,old).is_finite(),"old coordinate cannot reuse a newer approach certificate")

func _invalid_and_cleanup(rig: Dictionary) -> void:
	var stable_slots: Array[Node3D] = []
	for index: int in range(14): stable_slots.append(rig.view.slot(_id(index)))
	for fault: String in ["missing","duplicate","unknown","type","nan","placed","timer","stale"]:
		var rows: Array = rig.actions.render_records()
		match fault:
			"missing": rows.pop_back()
			"duplicate": rows[13] = rows[12].duplicate(true)
			"unknown": rows[0].id = "interactive:14"
			"type": rows[0].type = "b_bottle"
			"nan": rows[0].x = NAN
			"placed": rows[0].placed = 1
			"timer": rows[0].tipT = INF
			"stale": rig.props.interactive_record("interactive:0").tipT = 12.0
		var before: Dictionary = _model(rig)
		_check(not rig.view.sync(rows),"malformed or stale rows fail closed: "+fault)
		_check(_model(rig) == before,"rejected view input cannot alter source: "+fault)
		_inactive(rig,fault)
		_check(_sync(rig),"current authoritative snapshot recovers after "+fault)
		for index: int in range(14): _check(rig.view.slot(_id(index)) == stable_slots[index],"recovery reuses cached slot")
	var old: Array = rig.actions.render_records()
	rig.game.p = rig.game.p.duplicate(true)
	_check(not rig.view.sync(old),"previous player epoch snapshot cannot revive presentation")
	_check(not rig.view.sync_current(),"single-pull path also rejects expired owner epoch")
	_inactive(rig,"old epoch")
	_check(rig.actions.reset_session("restore") and _sync(rig),"explicit owner rebind restores current epoch")
	var sentinel: Dictionary = {"owner":"view_test_unrelated","bounds":AABB(Vector3(250,0,150),Vector3(1,2,1))}
	rig.adapter.update_navigation_obstacles("view_test_unrelated",[sentinel])
	var unrelated: Array = []
	for item: Dictionary in _nav_rows(rig.adapter):
		if not str(item.owner).begins_with("interactiveProps:"): unrelated.append(item)
	var before: Dictionary = _model(rig)
	rig.view.dispose(); _inactive(rig,"dispose")
	_check(_model(rig) == before,"dispose owns presentation only")
	var after: Array = []
	for item: Dictionary in _nav_rows(rig.adapter):
		if not str(item.owner).begins_with("interactiveProps:"): after.append(item)
	_check(after == unrelated,"dispose retains every unrelated navigation owner")
	var revision: int = _revision(rig.adapter); rig.view.dispose()
	_check(_revision(rig.adapter) == revision,"repeated dispose is topology-idempotent")
	groups += 1

func _placement_counterexamples() -> void:
	var world := PhysicsWorld.new(); root.add_child(world)
	_solid(world,Vector3(0,-0.1,0),Vector3(100,0.2,100),"view_test_ground")
	var game := FixedState.new(); game.npcs.clear(); game.s.mode = "playing"
	var adapter := Adapter.new(world,game)
	await physics_frame; await physics_frame
	var point := Vector2(1050,840); var before: Dictionary = game.snapshot(); var cursor: int = game.cursor
	_check(adapter.stage_interactive_prop("interactive:6","b_bottle",point,0.0) == point,"clear desired point is accepted without offset")
	var approach: Vector3 = adapter.interactive_approach("interactive:6",point)
	_check(approach.is_finite() and _capsule_clear(world,approach),"isolated certificate is backed by real capsule clearance")
	if approach.is_finite():
		var blocked_second: Vector2 = Content.to_source(approach)
		_check(adapter.stage_interactive_prop("interactive:0","trashcan",blocked_second,0.0) == null,"second prop cannot occupy first reserved actual capsule approach before either collider exists")
		_check(adapter.interactive_approach("interactive:6",point) == approach,"rejected second prop preserves first approach certificate")
		var second: Vector2 = point-Vector2(0,22)
		_check(adapter.stage_interactive_prop("interactive:7","b_bottle",second,0.0) == second,"second bottle can retain point by choosing a clear alternate approach")
		var second_approach: Vector3 = adapter.interactive_approach("interactive:7",second)
		var physical: Array[StaticBody3D] = []
		for source: Vector2 in [point,second]:
			var body := StaticBody3D.new(); body.collision_layer = 1; body.collision_mask = 0
			var cylinder := CylinderShape3D.new(); cylinder.radius = 0.065; cylinder.height = 0.25
			var shape := CollisionShape3D.new(); shape.shape = cylinder; body.add_child(shape)
			world.add_child(body); body.global_position = Content.to_world(source,0.125); physical.append(body)
		await physics_frame; await physics_frame
		_check(_capsule_clear(world,approach) and second_approach.is_finite() and _capsule_clear(world,second_approach),"both reserved approaches still fit actual player capsules after both bodies instantiate")
		for body: StaticBody3D in physical: body.free()
		await physics_frame
		game.p = game.p.duplicate(true); adapter.begin_interactive_epoch()
	for request: Array in [["interactive:14","b_bottle",point,100.0],["interactive:06","b_bottle",point,100.0],["interactive:0","b_bottle",point,100.0],["interactive:6","trashcan",point,100.0],["interactive:6","b_bottle",Vector2(NAN,840),100.0],["interactive:6","b_bottle",point,-1.0],["interactive:6","b_bottle",point,100.01]]:
		_check(adapter.stage_interactive_prop(request[0],request[1],request[2],request[3]) == null,"invalid staging request refuses before side effects")
	# A bottle fits at the middle of this narrow enclosure; a standing player does not.
	var walls: Array[StaticBody3D] = []
	for side: float in [-1.0,1.0]:
		walls.append(_solid(world,Vector3(side*0.30,1.0,0),Vector3(0.10,2.0,0.7),"view_test_enclosure"))
		walls.append(_solid(world,Vector3(0,1.0,side*0.30),Vector3(0.7,2.0,0.10),"view_test_enclosure"))
	await physics_frame; await physics_frame
	_check(adapter.stage_interactive_prop("interactive:6","b_bottle",point,0.0) == null,"small prop clearance alone cannot certify unusable enclosed approach")
	_check(adapter.stage_interactive_prop("interactive:6","b_bottle",point,100.0) == null,"recovery cannot teleport a prop through intervening enclosure walls")
	for wall: StaticBody3D in walls: wall.free()
	await physics_frame
	var roof := _solid(world,Vector3(0,0.79,0),Vector3(0.8,0.08,0.8),"view_test_lid_contact")
	await physics_frame; await physics_frame
	_check(adapter.stage_interactive_prop("interactive:0","trashcan",point,0.0) == null,"can placement checks full visual lid envelope, not only body cylinder")
	roof.free()
	_check(game.snapshot() == before and game.cursor == cursor,"all placement searches are model/RNG pure")
	world.free(); await physics_frame
	groups += 1

func _static_world_regression() -> void:
	var world := World.new(); root.add_child(world); world.build()
	await physics_frame; await physics_frame
	_check(not world.dynamic_interactive,"default world keeps standalone static prop contract")
	var game := FixedState.new(); game.npcs.clear(); game.s.mode = "playing"
	var adapter := Adapter.new(world,game)
	var bodies: int = 0; var reachable: int = 0; var clear_hits: int = 0
	for node: Node in world.find_children("*","StaticBody3D",true,false):
		if str(node.get_meta("source_owner","")).begins_with("interactiveProps:"): bodies += 1
	_check(bodies == 14,"default world retains14 original seed colliders")
	for index: int in range(14):
		var id: String = _id(index)
		_check(world.service_points.has(id),"static world retains canonical interactive service "+id)
		if not world.service_points.has(id): continue
		var service: Dictionary = world.service_points[id]
		_check(service.approach.is_finite(),"static canonical approach exists "+id)
		if not service.approach.is_finite(): continue
		_source_position(game,Content.to_source(service.approach))
		var can_reach: bool = adapter.can_reach_target(id)
		_check(can_reach,"default static interactive service keeps legacy reach "+id)
		if can_reach: reachable += 1
		var target: Vector2 = Content.to_source(service.target)
		var from: Vector3 = Content.to_world(game.player_center(),Adapter.FEET+1.8*0.6)
		var to: Vector3 = Content.to_world(target,Adapter.FEET+1.8*0.6)
		var query := PhysicsRayQueryParameters3D.create(from,to,1); query.hit_from_inside = true
		var expected: bool = world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
		_check(adapter.can_hit(game.player_center(),target,"player",id) == expected,"static can_hit keeps original actor-height ray contract "+id)
		if expected: clear_hits += 1
	_check(reachable == 14 and clear_hits > 0,"all14 legacy services and actual clear static hit witnesses exercised without Actions binding")
	world.free(); await physics_frame; await physics_frame
	groups += 1

func _actor_placement_counterexamples() -> void:
	var world := PhysicsWorld.new(); root.add_child(world)
	_solid(world,Vector3(0,-0.1,0),Vector3(100,0.2,100),"actor_prop_test_ground")
	var game := FixedState.new(); game.npcs.clear(); game.s.mode = "playing"; game.s.dayTime = 0.5
	var actor: Dictionary = {"id":"karaoke","name":"KARAOKE MIKE","sprite":"karaoke","x":1038.0,"y":826.0,"w":24.0,"h":28.0,"dead":false,"departed":false}
	game.npcs.append(actor)
	var adapter := Adapter.new(world,game)
	var registered := Node3D.new(); world.add_child(registered); adapter.register_body("karaoke",registered,2.1)
	await physics_frame; await physics_frame
	var point := Vector2(1050,840); var before: Dictionary = game.snapshot(); var actors: Array = game.npcs.duplicate(true); var draws: int = game.cursor
	_check(adapter.stage_interactive_prop("interactive:6","b_bottle",point,0.0) == null,"uninstantiated live NPC body blocks bottle at its source center")
	_check(adapter.stage_interactive_prop("interactive:0","trashcan",point,0.0) == null,"uninstantiated live NPC body blocks can at its source center")
	var staged: Variant = adapter.stage_interactive_prop("interactive:6","b_bottle",point,100.0)
	_check(staged is Vector2 and staged.distance_to(point) > 0 and staged.distance_to(point) <= 100.0001,"live NPC overlap resolves only through bounded prop relocation")
	_check(game.snapshot() == before and game.npcs == actors and game.cursor == draws,"NPC-aware staging never moves actors/player or consumes gameplay RNG")
	if staged is Vector2:
		# Materialize the actual registered-height source AABB only AFTER staging:
		# the initial overlap rejection therefore cannot have come from static physics.
		var body: StaticBody3D = _solid(world,Content.body_position(actor,Adapter.FEET+1.05),Vector3(0.96,2.1,1.12),"actor_prop_test_karaoke")
		await physics_frame; await physics_frame
		var cylinder := CylinderShape3D.new(); cylinder.radius = 0.065; cylinder.height = 0.34
		var query := PhysicsShapeQueryParameters3D.new(); query.shape = cylinder; query.collision_mask = 1
		query.transform = Transform3D(Basis.IDENTITY,Content.to_world(staged,0.18)); query.margin = 0.0
		_check(world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"accepted candidate clears independently materialized actual NPC body")
		body.free(); await physics_frame
	for flag: String in ["dead","departed"]:
		actor[flag] = true
		_check(adapter.stage_interactive_prop("interactive:6","b_bottle",point,0.0) == point,flag+" NPC leaves no invisible placement blocker")
		actor[flag] = false
	actor.daytimeOnly = true
	for clock: float in [0.249,0.25,0.75,0.751]:
		game.s.dayTime = clock
		var answer: Variant = adapter.stage_interactive_prop("interactive:6","b_bottle",point,0.0)
		_check((answer == point) if clock < 0.25 or clock > 0.75 else (answer == null),"NPC staging follows exact visible day/night boundaries")
	actor.daytimeOnly = false; game.s.dayTime = 0.9
	_check(adapter.stage_interactive_prop("interactive:6","b_bottle",point,0.0) == null,"ordinary resident still blocks a prop at night")
	for sleeping: String in ["mom","pete"]:
		actor.id = sleeping
		_check(adapter.stage_interactive_prop("interactive:6","b_bottle",point,0.0) == point,"source sleeping service leaves no invisible blocker: "+sleeping)
	actor.id = "karaoke"; game.s.dayTime = 0.5
	actor.x = point.x-110.0; actor.y = point.y-110.0; actor.w = 220.0; actor.h = 220.0
	before = game.snapshot(); actors = game.npcs.duplicate(true)
	_check(adapter.stage_interactive_prop("interactive:6","b_bottle",point,100.0) == null,"complete live-body obstruction remains pending rather than exceeding100px")
	_check(game.snapshot() == before and game.npcs == actors and game.cursor == draws,"blocked NPC searches stay pure with no hidden recovery or RNG")
	world.free(); await physics_frame; groups += 1

func _run() -> void:
	await _full_world()
	await _static_world_regression()
	await _placement_counterexamples()
	await _actor_placement_counterexamples()
	_check(groups == 5,"all adoption/live-view/static-regression/isolated-physics/live-NPC groups complete")
	if failures.is_empty():
		print("3D INTERACTIVE PROP VIEW GATE: PASS (%d checks; original28meshes/14slots, actual rays/capsules, live owner topology, source-only clocks, pending/stale/cleanup)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D INTERACTIVE PROP VIEW GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks]); quit(1)
