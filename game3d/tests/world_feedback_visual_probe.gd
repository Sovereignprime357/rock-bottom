extends SceneTree
## Staged real-domain/render evidence. Never a fight, input or campaign acceptance.
const Content = preload("res://scripts/content_catalog.gd")
const Combat = preload("res://scripts/combat_system.gd")
const Contact = preload("res://scripts/actor_contact.gd")
const STEP := 1000.0/60.0
const CASES := {"core":["essential","melee","bottle","trash_cash","trash_rats","dumpster","possum"],"authority":["ranged","fallen","tony2","tony3","older2","older3","ally","radio","taser","taser_fatal","death_then_taser"]}
const COUNTS := {"essential":1,"melee_sparks":8,"melee_rust":3,"melee_flash":1,"bottle_break":12,"bottle_impact":10,"holy_impact":12,"tony_coat":24,"older_phase":20,"dumpster_rats":10,"trash_cash":6,"trash_rats":8,"possum_reveal":6,"ally_hit":4,"ranged_aim":1,"fallen_aim":4,"radio":1,"taser":10}
const CONTEXTS := {"core":7,"authority":13}
const MAX_WALL_MS := 300000
const MAX_CAPTURES := 96
const GROUND_MIDLIFE: Array[String] = ["trash_cash","trash_rats","dumpster","possum"]
const MAX_CONTEXTS := 24
class ObservedScene:
	extends "res://scripts/full_scene.gd"
	var observed: Array[Dictionary] = []
	func _consume_events() -> void:
		if runtime != null:
			for event: Dictionary in runtime._outbox: observed.append(event.duplicate(true))
		super._consume_events()

var game: Node3D
var packet := "core"
var width := 1280
var output := ""
var checks := 0
var failures: Array[String] = []
var completed_cases: Array[String] = []
var contexts: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var fixtures: Array[Dictionary] = []
var active_fixture: Dictionary = {}
var started := 0
var finishing := false
var wall_clock := 0.0
var visual_ms := 713.0
var probe_frame := 1000000
var camera_pose := Transform3D.IDENTITY
var source_eye: SphereShape3D
var trigger_events: Array[Dictionary] = []
var rig_census: Dictionary = {}
var skipped_visual_claims: Array[String] = []
var pose_targets: Array[String] = []
var pose_syncs := 0
var pose_admitted_ms := 0.0

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> bool:
	checks += 1
	if not ok: failures.append(label); push_error("Feedback visual: "+label)
	return ok
func _json(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i: return [value.x,value.y]
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Color: return [value.r,value.g,value.b,value.a]
	if value is Transform3D: return {"origin":_json(value.origin),"basis":[_json(value.basis.x),_json(value.basis.y),_json(value.basis.z)]}
	if value is Transform2D: return {"origin":_json(value.origin),"basis":[_json(value.x),_json(value.y)]}
	if value is Rect2 or value is Rect2i: return {"position":_json(value.position),"size":_json(value.size)}
	if value is AABB: return {"position":_json(value.position),"size":_json(value.size)}
	if value is Array or value is PackedStringArray or value is PackedVector2Array:
		var result: Array = []
		for item: Variant in value: result.append(_json(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[str(key)] = _json(value[key])
		return result
	if value is Object: return "object:"+value.get_class()
	return value
static func _hash_bytes(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes); return hash.finish().hex_encode()
func _args() -> bool:
	if not _check("--qa-full" in OS.get_cmdline_user_args(),"--qa-full is required before FullScene construction"): return false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--packet="): packet = arg.trim_prefix("--packet=")
		elif arg.begins_with("--width="): width = int(arg.trim_prefix("--width="))
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if not _check(CASES.has(packet) and width in [1280,960],"finite known packet and1280/960 width"): return false
	if output.is_empty(): output = ProjectSettings.globalize_path("res://../feedback-visual-"+packet+"-"+str(width))
	if output.begins_with("res://") or output.begins_with("user://"): output = ProjectSettings.globalize_path(output)
	if not _check(not FileAccess.file_exists(output.path_join("feedback-visual.json")),"fresh report path preserves older evidence"): return false
	return _check(DirAccess.make_dir_recursive_absolute(output) == OK,"create isolated evidence directory")
static func suspend_callbacks(scene: Node,hud: Node) -> void:
	# Disabled tree mode removes inherited collision bodies. Hold callbacks only.
	for node: Node in [scene,hud]:
		if node == null: continue
		node.set_process(false); node.set_physics_process(false)
		node.set_process_input(false); node.set_process_unhandled_input(false)

func _physics_sentinel() -> Dictionary:
	var selected: Dictionary = {}
	for obstacle: Dictionary in game.world._obstacles:
		if str(obstacle.owner) != "structures:building_01": continue
		var box: AABB = obstacle.bounds
		var body: Variant = obstacle.get("body")
		if not body is StaticBody3D or not is_instance_valid(body): continue
		if box.size.y < 2.0 or minf(box.size.x,box.size.z) > 0.55 or maxf(box.size.x,box.size.z) < 2.0: continue
		if not body.global_basis.is_equal_approx(Basis.IDENTITY): continue
		selected = obstacle; break
	if selected.is_empty(): return {"ok":false,"reason":"existing_standing_wall_missing"}
	var body: StaticBody3D = selected.body
	var box: AABB = selected.bounds
	var axis: int = 0 if box.size.x < box.size.z else 2
	var ray_start: Vector3 = box.get_center(); var ray_end: Vector3 = ray_start
	ray_start[axis] = box.position[axis]-0.25; ray_end[axis] = box.end[axis]+0.25
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = source_eye; query.transform = Transform3D(Basis.IDENTITY,box.get_center()); query.margin = 0.002; query.collision_mask = 1
	var overlaps: Array[Dictionary] = game.world.get_world_3d().direct_space_state.intersect_shape(query,8)
	var owners: Array[String] = []; var found := false
	for overlap: Dictionary in overlaps:
		found = found or overlap.get("collider") == body
		var other: Variant = overlap.get("collider")
		owners.append(str(other.get_meta("source_owner","")) if other is Node else str(other))
	var hit: Dictionary = _ray(ray_start,ray_end)
	var hit_body: Variant = hit.get("collider")
	var ray_owner: String = str(hit_body.get_meta("source_owner","")) if hit_body is Node else ""
	return {"ok":body.can_process() and (body.collision_layer & 1) != 0 and found and hit_body == body,
		"owner":selected.owner,"body":str(body),"bounds":box,"body_transform":body.global_transform,"processable":body.can_process(),"body_process_mode":body.process_mode,"disable_mode":body.disable_mode,"collision_layer":body.collision_layer,
		"scene_process_mode":game.process_mode,"scene_callback":game.is_processing(),"hud_callback":game.hud.is_processing(),"overlap_owners":owners,"expected_overlap":found,
		"ray_from":ray_start,"ray_to":ray_end,"ray_owner":ray_owner,"ray_hit":hit.get("position"),"ray_normal":hit.get("normal"),"expected_ray_body":hit_body == body,"physics_frame":Engine.get_physics_frames()}
func _resolve() -> void:
	game.runtime._resolve_events()
	game._consume_events()
func _actor(id: String) -> Dictionary: return game.runtime.combat.actor(id)
func _body_point(body: Dictionary) -> Vector2: return Vector2(body.x,body.y)
func _player_body(point: Vector2) -> Dictionary:
	return {"id":"player","x":point.x,"y":point.y,"w":game.runtime.p.w,"h":game.runtime.p.h,"sprite":"player"}
func _place_player(center: Vector2) -> bool:
	var original: Vector2 = center-Vector2(game.runtime.p.w,game.runtime.p.h)*0.5
	var body: Dictionary = _player_body(original)
	var placed: Variant = game.physics.clear_placement(body)
	if not placed is Vector2 or placed.distance_to(original) > 0.001: return false
	game.runtime.p.x = placed.x; game.runtime.p.y = placed.y
	active_fixture.placements.append({"id":"player","requested_center":center,"actual_top_left":placed,"proof":"actual Adapter.clear_placement exact"})
	return true
func _approach(body: Dictionary,distance: float) -> bool:
	var center: Vector2 = Combat.center(body)
	for index: int in range(16):
		var point: Vector2 = center+Vector2.from_angle(float(index)*TAU/16.0)*distance
		var detached: Vector2 = point-Vector2(game.runtime.p.w,game.runtime.p.h)*0.5
		var proposed: Variant = game.physics.clear_placement(_player_body(detached))
		if not proposed is Vector2 or proposed.distance_to(detached) > 0.001: continue
		if not game.runtime.combat.can_hit(point,center,"player",str(body.id)): continue
		if _place_player(point): return true
	return false
func _approach_prop(id: String,point: Vector2,distance: float) -> bool:
	for index: int in range(16):
		if not _place_player(point+Vector2.from_angle(float(index)*TAU/16.0)*distance): continue
		if game.physics.can_reach_target(id): return true
	return false
func _approach_bottle(id: String,point: Vector2) -> bool:
	for index: int in range(16):
		var proposed: Vector2 = point+Vector2.from_angle(float(index)*TAU/16.0)*30.0
		if not _place_player(proposed): continue
		if not game.runtime.combat.can_hit(proposed,point,"player",id): continue
		var forward: Vector2 = (point-proposed).normalized()
		var front: float = absf(forward.x)*game.runtime.p.w*0.5+absf(forward.y)*game.runtime.p.h*0.5
		var hit_count := 0
		for candidate: Dictionary in game.runtime.interactive_props.render_records():
			if candidate.get("type") != "b_bottle" or not candidate.get("placed",false) or candidate.get("broken",false): continue
			var rect := {"x":candidate.x-4.0,"y":candidate.y-12.0,"w":8.0,"h":16.0}
			if game.runtime.combat._swing_overlaps(rect,proposed+forward*front,forward,36.0): hit_count += 1
		if hit_count == 1: return true
	return false
func _eye_proof(eye: Vector3) -> Dictionary:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = source_eye; query.transform = Transform3D(Basis.IDENTITY,eye); query.margin = 0.002; query.collision_mask = 1
	var hits: Array[Dictionary] = game.world.get_world_3d().direct_space_state.intersect_shape(query,4)
	if not hits.is_empty():
		var blockers: Array[Dictionary] = []
		for hit: Dictionary in hits:
			var body: Object = hit.get("collider")
			blockers.append({"collider":str(body),"owner":str(body.get_meta("source_owner","")) if body is Node else ""})
		return {"clear":false,"reason":"actual_eye_sphere_overlap","blockers":blockers}
	for node: Node3D in game.actors.values():
		if node.is_visible_in_tree() and eye.distance_to(node.global_position+Vector3.UP*0.95) < 0.65: return {"clear":false,"reason":"actual_visible_rig_envelope","actor":str(node.name),"position":node.global_position}
	return {"clear":true}
func _eye_clear(eye: Vector3) -> bool: return _eye_proof(eye).clear
func _ray(eye: Vector3,point: Vector3) -> Dictionary:
	return game.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,point,1))
func _occlusion_trial(eye: Vector3,point: Vector3,metadata: Dictionary) -> Dictionary:
	var row: Dictionary = metadata.duplicate(true)
	row.eye = eye; row.target = point; row.eye_proof = _eye_proof(eye)
	if not row.eye_proof.clear: row.ok = false; return row
	var hit: Dictionary = _ray(eye,point)
	var owner: String = str(hit.collider.get_meta("source_owner","")) if hit.get("collider") is Node else ""
	row.collider = str(hit.get("collider","")); row.source_owner = owner; row.hit_position = hit.get("position"); row.normal = hit.get("normal")
	row.ok = not hit.is_empty() and owner.begins_with("structures:") and absf(float(hit.get("normal",Vector3.UP).y)) <= 0.2
	row.reason = "accepted_actual_wall" if row.ok else "clear_ray" if hit.is_empty() else "nonwall_first_hit"
	return row
func _occluded_frame(point: Vector3) -> Dictionary:
	var nearby: Array[Dictionary] = []
	for obstacle: Dictionary in game.world._obstacles:
		if not str(obstacle.owner).begins_with("structures:"): continue
		var bounds: AABB = obstacle.bounds
		if bounds.size.y < 2.0 or minf(bounds.size.x,bounds.size.z) > 0.55 or maxf(bounds.size.x,bounds.size.z) < 0.8: continue
		if point.y < bounds.position.y or point.y > bounds.end.y: continue
		var nearest := Vector3(clampf(point.x,bounds.position.x,bounds.end.x),point.y,clampf(point.z,bounds.position.z,bounds.end.z))
		var distance: float = nearest.distance_to(point)
		if distance <= 12.0: nearby.append({"owner":obstacle.owner,"bounds":bounds,"distance":distance,"body":str(obstacle.get("body"))})
	nearby.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.distance) < float(b.distance))
	var attempts: Array[Dictionary] = []
	for wall: Dictionary in nearby.slice(0,16):
		var bounds: AABB = wall.bounds
		var axis: int = 0 if bounds.size.x < bounds.size.z else 2
		var along: int = 2 if axis == 0 else 0
		var away: float = -1.0 if point[axis] >= bounds.get_center()[axis] else 1.0
		for clearance: float in [0.3,0.7]:
			var eye: Vector3 = point
			eye[axis] = (bounds.position[axis] if away < 0 else bounds.end[axis])+away*clearance
			eye[along] = clampf(point[along],bounds.position[along]+0.2,bounds.end[along]-0.2)
			eye.y = clampf(point.y+0.65,bounds.position.y+0.2,bounds.end.y-0.2)
			var trial: Dictionary = _occlusion_trial(eye,point,{"method":"actual_wall_aabb_far_face","expected_wall":wall,"clearance":clearance})
			attempts.append(trial)
			if trial.ok:
				camera_pose = Transform3D(Basis.looking_at(point-eye,Vector3.UP),eye); game.camera.global_transform = camera_pose
				return {"ok":true,"occluded":true,"eye":eye,"target":point,"selected":trial,"attempts":attempts,"nearby_walls":nearby.size()}
	for distance: float in [2.5,4.0,7.0,11.0]:
		for index: int in range(16):
			var direction: Vector2 = Vector2.from_angle(float(index)*TAU/16.0)
			var eye: Vector3 = point+Vector3(direction.x*distance,0.65,direction.y*distance)
			var trial: Dictionary = _occlusion_trial(eye,point,{"method":"radial_fallback","distance":distance,"index":index})
			attempts.append(trial)
			if trial.ok:
				camera_pose = Transform3D(Basis.looking_at(point-eye,Vector3.UP),eye); game.camera.global_transform = camera_pose
				return {"ok":true,"occluded":true,"eye":eye,"target":point,"selected":trial,"attempts":attempts,"nearby_walls":nearby.size()}
	return {"ok":false,"reason":"no_bounded_actual_wall_eye","target":point,"nearby_walls":nearby,"attempts":attempts}
static func source_can_occlusion(hit: Dictionary,source_body: StaticBody3D) -> bool:
	if source_body == null or hit.get("collider") != source_body: return false
	var owner: String = str(source_body.get_meta("source_owner",""))
	return owner in ["interactiveProps:0","interactiveProps:1","interactiveProps:2","interactiveProps:3","interactiveProps:4","interactiveProps:5"]
func _sightline(eye: Vector3,point: Vector3,source_body: StaticBody3D = null) -> Dictionary:
	var hit: Dictionary = _ray(eye,point)
	var hit_body: Variant = hit.get("collider")
	var status := "clear" if hit.is_empty() else "source_prop_occluded" if source_can_occlusion(hit,source_body) else "intervening_geometry"
	return {"status":status,"target":point,"collider":str(hit_body),"source_owner":str(hit_body.get_meta("source_owner","")) if hit_body is Node else "","hit_position":hit.get("position"),"normal":hit.get("normal")}
func _frame(point: Vector3,near_view: bool = false,occluded: bool = false,source_body: StaticBody3D = null) -> Dictionary:
	if occluded: return _occluded_frame(point)
	var attempts: Array[Dictionary] = []
	for distance: float in ([0.85,1.1] if near_view else [2.8,4.0]):
		for index: int in range(16):
			var direction: Vector2 = Vector2.from_angle(float(index)*TAU/16.0)
			var eye: Vector3 = point+Vector3(direction.x*distance,0.35 if near_view else 0.65,direction.y*distance)
			eye.y = maxf(eye.y,0.65)
			var eye_proof: Dictionary = _eye_proof(eye)
			if not eye_proof.clear:
				attempts.append({"eye":eye,"eye_proof":eye_proof}); continue
			var sightline: Dictionary = _sightline(eye,point,source_body)
			attempts.append({"eye":eye,"eye_proof":eye_proof,"sightline":sightline})
			if sightline.status == "intervening_geometry": continue
			camera_pose = Transform3D(Basis.looking_at(point-eye,Vector3.UP),eye)
			game.camera.global_transform = camera_pose
			return {"ok":true,"eye":eye,"target":point,"occluded":occluded,"anchor_visibility":sightline.status,"anchor_sightline":sightline,"eye_proof":eye_proof,"near_view":near_view,"attempts":attempts,"visual_acceptance":false}
	return {"ok":false,"reason":"no_bounded_observer_pose","target":point,"occluded":occluded,"attempts":attempts}
func _particle_sightlines(snapshot: Dictionary,born_serials: Dictionary,birth_epoch: int,source_body: StaticBody3D = null) -> Dictionary:
	var rows: Array[Dictionary] = []
	var counts := {"clear":0,"source_prop_occluded":0,"intervening_geometry":0}
	if snapshot.epoch != birth_epoch: return {"scope":"birth epoch replaced; no new particles substituted","birth_epoch":birth_epoch,"current_epoch":snapshot.epoch,"particles":rows,"counts":counts,"visual_acceptance":false}
	_check(snapshot.particles.size() <= 220,"bounded actual particle center sightlines")
	for particle: Dictionary in snapshot.particles.slice(0,220):
		if not born_serials.has(int(particle.serial)): continue
		var point: Vector3 = particle.world_anchor+particle.birth_right*(particle.offset.x*0.04)-Vector3.UP*(particle.offset.y*0.04)
		var line: Dictionary = _sightline(camera_pose.origin,point,source_body)
		line.serial = particle.serial; line.recipe = particle.recipe; line.life = particle.life
		counts[line.status] += 1; rows.append(line)
	return {"scope":"actual collision center rays only; mesh/pixel visibility requires PNG review","eye":camera_pose.origin,"eye_proof":_eye_proof(camera_pose.origin),"counts":counts,"particles":rows,"visual_acceptance":false}
func _fresh(id: String) -> bool:
	pose_targets.clear(); pose_syncs = 0; pose_admitted_ms = 0.0
	active_fixture = {"id":id,"scope":"visual-only initial fixture; not earned gameplay","placements":[],"fields":{},"initial_seed":0}
	if not _check(game.runtime.fresh(),"fresh authoritative source epoch "+id): return false
	game._reset_presentation(); game._sync_model_nodes(0.0); game._resume(); _resolve()
	game.runtime.s.dayTime = 0.55
	active_fixture.fields["s.dayTime"] = 0.55
	game.observed.clear(); game.runtime.drain_events()
	game.physics.invalidate_placement_cache()
	await physics_frame
	active_fixture.physics_sentinel = _physics_sentinel()
	return _check(active_fixture.physics_sentinel.ok,"real existing wall overlap and crossing-ray remain active "+id)
func _field(body: Dictionary,key: String,value: Variant,id: String) -> void:
	active_fixture.fields[id+"."+key] = {"before":body.get(key),"fixture":value}; body[key] = value
func _seed(value: int) -> void:
	active_fixture.initial_seed = value; game.runtime.state.rng_seed = value
func _snapshot() -> Dictionary:
	return {"player":game.runtime.p.duplicate(true),"bossPhase":game.runtime.s.bossPhase,"olderPhase":game.runtime.s.get("brutusOlderPhase"),"mode":game.runtime.s.mode,"rng_seed":game.runtime.state.rng_seed,"pool":game.runtime.feedback_snapshot()}
func _recipes(snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in snapshot.get("particles",[]): result[row.recipe] = int(result.get(row.recipe,0))+1
	return result
func _controls() -> Dictionary:
	var result: Dictionary = {}
	for control: Node in game.hud.root.find_children("*","Control",true,false):
		result[str(control.get_path())] = {"transform":control.get_global_transform(),"size":control.size,"visible":control.visible}
	return result
func _view_state() -> Dictionary:
	return {"camera":game.camera.global_transform,"player":game.player.global_transform,"fov":game.camera.fov,"controls":_controls()}
func _view_differences(before: Dictionary,after: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: String in ["camera","player","fov"]:
		if before[key] != after[key]: result.append({"field":key,"before":before[key],"after":after[key]})
	var all_controls: Dictionary = before.controls.duplicate()
	all_controls.merge(after.controls,true)
	for path: String in all_controls:
		if before.controls.get(path) != after.controls.get(path): result.append({"field":"controls:"+path,"before":before.controls.get(path),"after":after.controls.get(path)})
	return result
static func sync_admitted_pose(scene: Node) -> float:
	var admitted: float = scene.runtime.last_advanced_ms
	scene._sync_model_nodes(admitted/1000.0)
	return admitted
func _pose_step() -> void:
	pose_admitted_ms += sync_admitted_pose(game)
	pose_syncs += 1
static func context_pose_targets(id: String,receipt: Variant) -> Array[String]:
	var result: Array[String] = []
	if id == "essential": result.append("lease_guy")
	elif id in ["melee","tony2","tony3"]: result.append("tony")
	elif id in ["older2","older3"]: result.append("brutus_older")
	elif id in ["ranged-aim","ranged-impact"]: result.append("paulie")
	elif id in ["fallen-aim","fallen-impact"]: result.append("omalley_fallen")
	elif id == "possum": result.append("pet_possum")
	elif id == "ally": result.assign(["stripe","tony"])
	elif id == "death_then_taser": result.assign(["tony",str(receipt.detached_source_cop_id)])
	elif id in ["radio","taser","taser_fatal"]: result.append(str(receipt.actor.id))
	return result
static func pose_mismatches(snapshot: Dictionary,rig: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if snapshot.is_empty(): errors.append("missing_director_snapshot")
	if int(rig.get("frame",0)) <= 0: errors.append("unadvanced_rig")
	var state: Array = rig.get("last_state",[])
	if state.size() != 8: errors.append("missing_pose_state"); return errors
	var coats: int = clampi(int(snapshot.get("coat_count",3)),0,3)
	if int(rig.get("last_coats",-1)) != coats or state[4] != coats: errors.append("coat_count")
	var wanted := {1:int(snapshot.get("action_serial",0)),2:bool(snapshot.get("contact",false)),3:bool(snapshot.get("dead",false)),5:bool(snapshot.get("grounded",true)),6:float(snapshot.get("hurt",0.0)) > 0.0}
	for key: int in wanted:
		if state[key] != wanted[key]: errors.append("pose_state:"+str(key))
	var action: String = str(snapshot.get("action",""))
	if not action.is_empty():
		var expected: String = action if action in rig.get("supported_actions",[]) else ""
		if str(state[0]) != expected: errors.append("explicit_action")
	var layers: Array = rig.get("layers",[])
	if layers.size() != 3: errors.append("missing_layer_census")
	for row: Dictionary in layers:
		if int(row.visible) != (int(row.total) if int(row.layer) <= coats else 0): errors.append("layer:"+str(row.layer))
	return errors
func _pose_receipts(require_current: bool) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for id: String in pose_targets:
		var model: Dictionary = _actor(id)
		var present: bool = game.actors.has(id) and is_instance_valid(game.actors[id])
		var row := {"id":id,"model_present":not model.is_empty(),"scene_present":present,"director":game.runtime.director.snapshot(id),"rig":{},"mismatches":[]}
		if model.is_empty():
			if present: row.mismatches.append("removed_actor_retains_scene_entry")
		else:
			row.model = {"hp":model.get("hp"),"dead":model.get("dead",false),"coats_off":model.get("coatsOff",0)}
			if not present: row.mismatches.append("missing_actual_actor")
			else:
				var body: Node3D = game.actors[id]
				var art: Node3D = body.get_node_or_null("Art")
				if art == null or not art.has_meta("roster_rig"): row.mismatches.append("missing_actual_rig")
				else:
					var rig: Dictionary = art.get_meta("roster_rig")
					var layers: Array[Dictionary] = []
					for layer: int in range(1,4):
						var visible := 0; var in_tree := 0
						for mesh: MeshInstance3D in rig.layers[layer]:
							visible += int(mesh.visible); in_tree += int(mesh.is_visible_in_tree())
						layers.append({"layer":layer,"total":rig.layers[layer].size(),"visible":visible,"visible_in_tree":in_tree})
					row.rig = {"visual_id":str(rig.definition.visual_id),"frame":rig.frame,"time":rig.time,"last_coats":rig.last_coats,"last_state":rig.last_state.duplicate(),"supported_actions":rig.definition.actions.duplicate(),"layers":layers,"body_visible":body.is_visible_in_tree(),"pose_updates":rig.pose_updates,"visibility_writes":rig.visibility_writes}
					row.mismatches = pose_mismatches(row.director,row.rig)
		if require_current: _check(row.mismatches.is_empty(),"actual current Director and rig pose/layers "+id+":"+str(row.mismatches))
		rows.append(row)
	return rows
func _paint() -> void:
	var rng: int = game.runtime.state.rng_seed
	game._sync_model_nodes(0.0)
	game.camera.global_transform = camera_pose
	game._sync_feedback_context()
	game.weather_view.sync({"dayTime":game.runtime.s.dayTime,"weather":"clear","office_generator":false,"geometry_revision":game.physics._collision_revision},visual_ms)
	game._sync_dynamic_emitters(visual_ms)
	game.hud.update_runtime(game.runtime); game.hud.update_actor_hud(visual_ms)
	game._sync_world_feedback(visual_ms)
	_check(rng == game.runtime.state.rng_seed,"render sync consumes no gameplay RNG")
func _capture(id: String,extra: Dictionary = {}) -> Dictionary:
	if not _check(captures.size() < MAX_CAPTURES,"finite96 capture cap"): return {}
	_paint()
	var require_pose: bool = str(extra.get("phase","")) in ["active","midlife","recovery"]
	var poses_before: Array[Dictionary] = _pose_receipts(require_pose)
	var pre_layout: Dictionary = _view_state()
	var rng: int = game.runtime.state.rng_seed
	# First paint can queue Label/Container minimum-size work. No source step runs.
	await process_frame; await RenderingServer.frame_post_draw
	var before: Dictionary = _view_state()
	_check(before.camera == pre_layout.camera and before.player == pre_layout.player and before.fov == pre_layout.fov,"GUI layout settling cannot move camera, aim or FOV "+id)
	await process_frame; await RenderingServer.frame_post_draw
	var after: Dictionary = _view_state()
	var differences: Array[Dictionary] = _view_differences(before,after)
	_check(differences.is_empty(),"world offset cannot move actual camera, aim, FOV or HUD "+id)
	_check(game.runtime.state.rng_seed == rng,"readback consumes no gameplay RNG "+id)
	var poses_after: Array[Dictionary] = _pose_receipts(false)
	_check(poses_before == poses_after,"capture freezes actual target poses "+id)
	var rendered: Image = root.get_texture().get_image()
	_check(rendered.get_width() == width and rendered.get_height() == int(width*9/16),"actual framebuffer resolution "+id)
	var path: String = output.path_join(id+".png")
	_check(rendered.save_png(path) == OK,"save actual frame "+id)
	var inspection: Dictionary = game.feedback_view.inspect()
	_check(inspection.live == game.runtime.feedback_snapshot().particles.size() and inspection.live <= 220,"actual four-bank upload matches pool "+id)
	var evidence := {"file":id+".png","sha256":FileAccess.get_sha256(path),"camera":before.camera,"player":before.player,"fov":before.fov,"controls":before.controls,"view_invariant":{"pre_layout":pre_layout,"before":before,"after":after,"layout_differences":_view_differences(pre_layout,before),"capture_differences":differences,"source_steps_during_layout":0},"pose_evidence":{"required_current":require_pose,"sync_calls":pose_syncs,"admitted_ms":pose_admitted_ms,"actors":poses_after,"capture_pose_changes":poses_before != poses_after},"grade":game.hud.district_grade.inspect(),"pool":game.runtime.feedback_snapshot(),"view":inspection,"details":extra}
	captures.append(evidence)
	return {"evidence":evidence,"image":rendered}
func _advance_until(milliseconds: float) -> float:
	var admitted := 0.0; var attempts := 0
	while admitted+0.001 < milliseconds and attempts < 480:
		attempts += 1; wall_clock += STEP
		probe_frame += 1; game.physics.begin_navigation_frame(probe_frame,wall_clock)
		game.runtime.advance_wall(wall_clock)
		if not game.runtime.advance(STEP/1000.0,{"input_vector":Vector2.ZERO,"monotonic_ms":wall_clock}): break
		admitted += game.runtime.last_advanced_ms
		_pose_step()
		_resolve()
		await physics_frame
		if game.runtime.s.mode != "playing": break
	_check(admitted+0.001 >= milliseconds,"bounded source Runtime admitted interval "+str(milliseconds))
	return admitted
func _world_point(snapshot: Dictionary,recipe: String) -> Vector3:
	for row: Dictionary in snapshot.particles:
		if row.recipe == recipe: return row.world_anchor
	return Vector3.INF
static func context_birth_serials(snapshot: Dictionary,recipes: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in snapshot.particles:
		if str(row.recipe) in recipes: result[int(row.serial)] = true
	return result
static func retained_context_births(snapshot: Dictionary,born_serials: Dictionary,birth_epoch: int) -> int:
	if snapshot.epoch != birth_epoch: return 0
	var result := 0
	for row: Dictionary in snapshot.particles:
		if born_serials.has(int(row.serial)): result += 1
	return result
func _context(id: String,recipes: Array[String],before: Dictionary,receipt: Variant,extra: Dictionary = {}) -> bool:
	if not _check(contexts.size() < MAX_CONTEXTS,"finite24 context cap"): return false
	_resolve()
	pose_targets = context_pose_targets(id,receipt)
	var snapshot: Dictionary = game.runtime.feedback_snapshot()
	var born: Dictionary = _recipes(snapshot)
	for recipe: String in recipes: _check(int(born.get(recipe,0)) == int(COUNTS[recipe]),"exact actual birth count "+id+":"+recipe)
	var point: Vector3 = _world_point(snapshot,recipes[0])
	if not _check(point.is_finite(),"real accepted pool anchor "+id): return false
	game._sync_model_nodes(0.0)
	var source_body: StaticBody3D = game.prop_view.collider(str(extra.prop_before.id)) if id in ["trash_cash","trash_rats"] else null
	var framing: Dictionary = _frame(point,false,false,source_body)
	if not _check(framing.ok,"real clear camera with explicit source-prop sightline classification "+id): return false
	var event_end: Array = game.observed.duplicate(true)
	var record := {"id":id,"recipes":recipes.duplicate(),"fixture":active_fixture.duplicate(true),"before":before,"after":_snapshot(),"receipt":receipt,"events":event_end,"framing":framing,"details":extra}
	contexts.append(record)
	var epoch: int = snapshot.epoch
	var born_serials: Dictionary = context_birth_serials(snapshot,recipes)
	record.tracked_birth_epoch = epoch; record.tracked_birth_serials = born_serials.keys()
	var birth_details := {"phase":"birth","framing":framing,"pose_boundary":"after actual admitted projectile steps" if id.ends_with("-impact") else "direct owner command before next admitted pose step"}
	if id in GROUND_MIDLIFE: birth_details.particle_sightlines = _particle_sightlines(snapshot,born_serials,epoch,source_body)
	await _capture(id+"-birth",birth_details)
	if id == "melee": await _extra_views(point)
	record.active_admitted_ms = await _advance_until(80.0)
	var active_details := {"phase":"active","admitted_ms":record.active_admitted_ms}
	if id in GROUND_MIDLIFE: active_details.particle_sightlines = _particle_sightlines(game.runtime.feedback_snapshot(),born_serials,epoch,source_body)
	await _capture(id+"-active",active_details)
	var aged: float = float(record.active_admitted_ms)
	if id in GROUND_MIDLIFE:
		aged += await _advance_until(maxf(0.0,250.0-aged))
		var midlife: Dictionary = game.runtime.feedback_snapshot()
		var retained: int = retained_context_births(midlife,born_serials,epoch)
		record.midlife_admitted_ms = aged
		record.midlife_retained_births = retained
		_check(aged >= 249.999 and retained > 0,"ground midlife uses real admitted time and retained source births "+id)
		await _capture(id+"-midlife",{"phase":"midlife","admitted_ms":aged,"retained_births":retained,"particle_sightlines":_particle_sightlines(midlife,born_serials,epoch,source_body),"unchanged_anchor_geometry_and_camera":true,"visibility_requires_image_review":true})
	var remain := true
	while aged < 2200.0 and remain:
		var interval: float = await _advance_until(50.0)
		aged += interval
		var now: Dictionary = game.runtime.feedback_snapshot()
		remain = retained_context_births(now,born_serials,epoch) > 0
		if game.runtime.s.mode != "playing": break
		if interval <= 0.0: break
	_check(not remain,"birth serials expire at real source boundary "+id)
	record.recovery_admitted_ms = aged
	await _capture(id+"-recovery",{"phase":"recovery","birth_serials_expired":not remain,"admitted_ms":aged})
	return true
func _extra_views(point: Vector3) -> void:
	var pose: Transform3D = camera_pose
	var near_frame: Dictionary = _frame(point,true)
	if _check(near_frame.ok,"bounded clear near-camera melee view"): await _capture("melee-near",near_frame)
	camera_pose = pose
	game.feedback_strength = 0.0
	var baseline: Dictionary = await _capture("melee-shake-zero",{"strength":0})
	game.feedback_strength = 1.0
	var shaken: Dictionary = await _capture("melee-shake-source",{"strength":1})
	var source_offset: Vector2 = game.hud.district_grade.inspect().world_feedback_offset
	_check(source_offset != Vector2.ZERO,"actual source shake produces nonzero world-only shader offset")
	var scale: float = float(width)/1280.0
	var rectangle := Rect2i(Vector2i(Vector2(32,25)*scale),Vector2i(Vector2(460,25)*scale))
	var glyphs: Array[Vector2i] = foreground_mask(baseline.image,rectangle,Color("e8c040"))
	var fill: Dictionary = _health_fill_proof(baseline.image.get_size())
	_check(fill.ok,"actual opaque health fill configuration and framebuffer bounds")
	var fill_pixels: Array[Vector2i] = []
	if fill.ok: fill_pixels = foreground_mask(baseline.image,fill.rectangle,fill.color)
	var glyph_proof: Dictionary = foreground_comparison(baseline.image,shaken.image,glyphs)
	var fill_proof: Dictionary = foreground_comparison(baseline.image,shaken.image,fill_pixels)
	var combined: Array[Vector2i] = unique_foreground(glyphs,fill_pixels)
	var proof: Dictionary = foreground_comparison(baseline.image,shaken.image,combined)
	_check(glyph_proof.pixels > 0 and glyph_proof.equal,"opaque status glyph pixels remain fixed above world shake")
	_check(fill_proof.pixels > 0 and fill_proof.equal,"actual opaque health meter pixels remain fixed above world shake")
	_check(proof.pixels >= 12 and proof.equal,"minimum12 unique opaque foreground pixels remain byte-identical")
	proof.glyphs = glyph_proof; proof.meter = fill_proof; proof.fill_geometry = fill
	proof.minimum_unique_pixels = 12; proof.plate_background_excluded = true
	captures[-1].hud_foreground = proof
	var occlusion: Dictionary = _frame(point,false,true)
	contexts[-1].occlusion_search = occlusion
	if _check(occlusion.ok,"bounded actual-world wall occlusion witness"): await _capture("melee-occluded",occlusion)
	camera_pose = pose

static func opaque_fill_rectangle(size: Vector2,ratio: float,minimum: Vector2,screen: Transform2D,image_size: Vector2i) -> Rect2i:
	if not size.is_finite() or not minimum.is_finite() or not is_finite(ratio) or ratio <= 0.0 or ratio > 1.0: return Rect2i()
	if size.x <= minimum.x or size.y <= 0.0 or minimum.x < 0.0: return Rect2i()
	if not screen.x.is_finite() or not screen.y.is_finite() or not screen.origin.is_finite(): return Rect2i()
	if screen.x.y != 0.0 or screen.y.x != 0.0 or screen.x.x <= 0.0 or screen.y.y <= 0.0: return Rect2i()
	# Pinned4.5.1 ProgressBar LTR fill draw: round(ratio*(width-minimum_width))+minimum_width.
	var progress: int = roundi(ratio*(size.x-minimum.x))
	if progress <= 0: return Rect2i()
	var first: Vector2 = screen*Vector2.ZERO
	var last: Vector2 = screen*Vector2(float(progress)+minimum.x,size.y)
	var start := Vector2i(ceili(first.x)+2,ceili(first.y)+2)
	var end := Vector2i(floori(last.x)-2,floori(last.y)-2)
	if end.x <= start.x or end.y <= start.y: return Rect2i()
	return Rect2i(start,end-start).intersection(Rect2i(Vector2i.ZERO,image_size))
static func opaque_fill_style(style: StyleBoxFlat) -> bool:
	if style == null or style.bg_color.a != 1.0 or not style.draw_center or style.skew != Vector2.ZERO: return false
	for field: String in ["border_width_left","border_width_top","border_width_right","border_width_bottom","corner_radius_top_left","corner_radius_top_right","corner_radius_bottom_left","corner_radius_bottom_right","expand_margin_left","expand_margin_top","expand_margin_right","expand_margin_bottom"]:
		if float(style.get(field)) != 0.0: return false
	return true
func _health_fill_proof(image_size: Vector2i) -> Dictionary:
	var bar: ProgressBar = game.hud.health
	var fill: StyleBoxFlat = bar.get_theme_stylebox("fill") as StyleBoxFlat
	var result := {"ok":false,"rectangle":Rect2i(),"color":Color.TRANSPARENT,"control":str(bar.get_path()),"value":bar.value,"minimum":bar.min_value,"maximum":bar.max_value,"ratio":bar.ratio,"size":bar.size}
	if not opaque_fill_style(fill) or not bar.is_visible_in_tree() or bar.show_percentage or bar.indeterminate or bar.fill_mode != ProgressBar.FILL_BEGIN_TO_END or bar.is_layout_rtl(): return result
	var node: Node = bar
	while node != null:
		if node is CanvasItem and (node.modulate != Color.WHITE or node.self_modulate != Color.WHITE or node.material != null): return result
		node = node.get_parent()
	# Viewport transform includes real stretch; no desktop window position or guessed second scale.
	var screen: Transform2D = bar.get_viewport_transform()*bar.get_global_transform()
	result.transform_to_framebuffer = screen; result.fill_minimum_size = fill.get_minimum_size()
	result.rectangle = opaque_fill_rectangle(bar.size,bar.ratio,fill.get_minimum_size(),screen,image_size)
	result.color = fill.bg_color; result.ok = result.rectangle.has_area()
	return result
static func foreground_mask(image: Image,rectangle: Rect2i,color: Color) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var bounds: Rect2i = rectangle.intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	for y: int in range(bounds.position.y,bounds.end.y):
		for x: int in range(bounds.position.x,bounds.end.x):
			var pixel: Color = image.get_pixel(x,y)
			if pixel.r8 == color.r8 and pixel.g8 == color.g8 and pixel.b8 == color.b8 and pixel.a8 == 255: points.append(Vector2i(x,y))
	return points
static func unique_foreground(first: Array[Vector2i],second: Array[Vector2i]) -> Array[Vector2i]:
	var seen: Dictionary = {}; var result: Array[Vector2i] = []
	for group: Array[Vector2i] in [first,second]:
		for point: Vector2i in group:
			if not seen.has(point): result.append(point); seen[point] = true
	return result
static func foreground_comparison(first: Image,second: Image,points: Array[Vector2i]) -> Dictionary:
	var a := PackedByteArray(); var b := PackedByteArray()
	for point: Vector2i in points:
		var left: Color = first.get_pixelv(point); var right: Color = second.get_pixelv(point)
		a.append_array(PackedByteArray([left.r8,left.g8,left.b8,left.a8]))
		b.append_array(PackedByteArray([right.r8,right.g8,right.b8,right.a8]))
	return {"pixels":points.size(),"equal":a == b,"baseline_hash":_hash_bytes(a),"shaken_hash":_hash_bytes(b),"sample_positions":points.slice(0,8),"channels":"exact RGBA8 at original coordinates"}

func _melee(id: String,actor_id: String,expected: Array[String]) -> bool:
	var target: Dictionary = _actor(actor_id)
	if not _check(not target.is_empty() and _approach(target,38.0),"actual reachable canonical target "+id): return false
	game._sync_model_nodes(0.0); _frame(Content.to_world(Combat.center(target),1.1)); game._sync_feedback_context()
	var hp: float = target.hp; var before: Dictionary = _snapshot()
	var result: Dictionary = game.runtime.attack((Combat.center(target)-game.runtime.state.player_center()).normalized())
	_check(result.get("ok",false),"accepted ordinary swing "+id)
	_check(target.hp == hp if id == "essential" else target.hp < hp,"source target HP receipt "+id)
	return await _context(id,expected,before,result)
func _bottle() -> bool:
	var selected: Dictionary = {}
	for index: int in range(6,14):
		var id := "interactive:%d" % index
		var row: Dictionary = game.runtime.interactive_props.render_record(id)
		if not row.get("placed",false) or row.get("broken",false): continue
		if _approach_bottle(id,Vector2(row.x,row.y-4.0)): selected = row; break
	if not _check(not selected.is_empty(),"actual source bottle has clear legal swing position"): return false
	var before: Dictionary = _snapshot(); var point := Vector2(selected.x,selected.y-4.0)
	game._sync_model_nodes(0.0); _frame(Content.to_world(point,0.08)); game._sync_feedback_context()
	var result: Dictionary = game.runtime.attack((point-game.runtime.state.player_center()).normalized())
	var row: Dictionary = game.runtime.interactive_props.render_record(selected.id)
	_check(row.broken and row.respawnT >= 60000.0 and row.respawnT < 120000.0,"bottle transition commits source break and respawn")
	return await _context("bottle",["bottle_break"],before,result,{"prop_before":selected,"prop_after":row})
func _trash(id: String) -> bool:
	var selected: Dictionary = {}
	for index: int in range(6):
		var row: Dictionary = game.runtime.interactive_props.render_record("interactive:%d" % index)
		if row.get("placed",false) and _approach_prop(row.id,Vector2(row.x,row.y),42.0): selected = row; break
	if not _check(not selected.is_empty(),"source placed trashcan reachable "+id): return false
	_seed(1 if id == "trash_cash" else 1456)
	game._sync_model_nodes(0.0)
	var source_body: StaticBody3D = game.prop_view.collider(str(selected.id))
	if not _check(source_body != null and source_can_occlusion({"collider":source_body},source_body),"selected actual canonical can collider "+id): return false
	var preframe: Dictionary = _frame(Content.to_world(Vector2(selected.x,selected.y),0.08),false,false,source_body)
	active_fixture.source_can = {"id":selected.id,"owner":source_body.get_meta("source_owner",""),"transform":source_body.global_transform,"shape":str(source_body.get_child(0).shape),"pre_trigger_frame":preframe}
	if not _check(preframe.ok,"pre-trigger observer honors exact source can without intervening geometry "+id): return false
	game._sync_feedback_context()
	var before: Dictionary = _snapshot(); var result: Dictionary = game.runtime.kick_can(selected.id)
	var row: Dictionary = game.runtime.interactive_props.render_record(selected.id)
	_check(result.get("ok",false) and result.get("committed",false) and row.cdT == 60000.0 and row.tipT == 200.0,"actual kick commit "+id)
	_check(game.runtime.p.cash > before.player.cash if id == "trash_cash" else game.runtime.p.cash == before.player.cash,"exact source cash-versus-rats branch "+id)
	return await _context(id,[id],before,result,{"prop_before":selected,"prop_after":row})
func _dumpster() -> bool:
	var selected := ""
	for raw: Variant in game.runtime.world_props.interaction_ids("dumpster"):
		var id: String = str(raw); var row: Dictionary = game.runtime.props.record(id)
		if not row.get("looted",false) and _approach_prop(id,Vector2(row.x+row.w*0.5,row.y+row.h*0.5),42.0): selected = id; break
	if not _check(not selected.is_empty(),"actual unopened dumpster approach"): return false
	_seed(1)
	var prop: Dictionary = game.runtime.props.record(selected)
	game._sync_model_nodes(0.0); _frame(Content.to_world(Vector2(prop.x+prop.w*0.5,prop.y),0.08)); game._sync_feedback_context()
	var before: Dictionary = _snapshot(); var menu: Dictionary = game.runtime.open_world_prop(selected)
	var rats := ""
	if menu.get("ok",false):
		for option: Dictionary in menu.options:
			if option.label == "nothing. dumpsters know.": rats = option.id
	if not _check(not rats.is_empty(),"fixed source seed produces actual rats offer without reroll"): return false
	var result: Dictionary = game.runtime.select_world_prop(menu.token,rats)
	_check(result.get("ok",false) and game.runtime.props.record(selected).looted,"actual dumpster selection commits looted state")
	return await _context("dumpster",["dumpster_rats"],before,result,{"menu":menu,"prop":game.runtime.props.record(selected).duplicate(true)})
func _possum() -> bool:
	var result: Dictionary = game.runtime.companions.spawn_pet_possum(); _resolve()
	var body: Dictionary = _actor("pet_possum")
	if not _check(result.get("spawned",false) and not body.is_empty(),"actual companion owner physically spawns YOUR POSSUM"): return false
	game._sync_model_nodes(0.0); await physics_frame
	_field(body,"revealT",0.0,"pet_possum"); _seed(29)
	_frame(Content.to_world(game.runtime.state.player_center()+Vector2(0,50),0.08)); game._sync_feedback_context()
	var before: Dictionary = _snapshot(); var piles: Array = game.runtime.state.cash_piles.duplicate(true)
	var accepted: bool = game.runtime.companions.tick_possum_reveal(body,STEP)
	_check(accepted and game.runtime.state.cash_piles != piles,"real reveal moves an existing source pile after placement")
	return await _context("possum",["possum_reveal"],before,{"ok":accepted}, {"piles_before":piles,"piles_after":game.runtime.state.cash_piles.duplicate(true)})

func _boss_phase(id: String) -> bool:
	var older: bool = id.begins_with("older")
	var ok: bool = game.runtime.bosses.spawn_brutus_older() if older else game.runtime.bosses.start_tony()
	_resolve()
	var body: Dictionary = _actor("brutus_older" if older else "tony")
	if not _check(ok and not body.is_empty(),"actual boss start "+id): return false
	if not _check(_approach(body,100.0),"actual boss observer fixture "+id): return false
	var phase: int = 2 if id.ends_with("2") else 3
	_field(body,"hp",(98.0 if phase == 2 else 48.0) if older else (130.0 if phase == 2 else 60.0),str(body.id))
	game._sync_model_nodes(0.0); _frame(Content.to_world(Combat.center(body),1.1)); game._sync_feedback_context()
	var before: Dictionary = _snapshot(); var actors_before: int = game.runtime.state.npcs.size()
	var accepted: bool = game.runtime.bosses.tick_after_actors(STEP,wall_clock)
	_check(accepted and int(game.runtime.s.get("brutusOlderPhase" if older else "bossPhase")) == phase,"accepted actual phase transition "+id)
	if not older and phase == 2: _check(game.runtime.state.npcs.size() == actors_before+2,"Tony phase2 has both real preflighted adds")
	return await _context(id,["older_phase" if older else "tony_coat"],before,{"ok":accepted,"phase":phase})
func _ranged(id: String) -> bool:
	var fallen: bool = id == "fallen"
	if fallen:
		if not _check(game.runtime.bosses.transform_fallen_priest(),"actual source priest transformation"): return false
	_resolve()
	var body: Dictionary = _actor("omalley_fallen" if fallen else "paulie")
	if not _check(not body.is_empty() and _approach(body,220.0),"actual long clear projectile lane "+id): return false
	_field(body,"throwT",0.0,str(body.id)); _field(body,"throwAimT",0.0,str(body.id)); _field(body,"aimingThrow",false,str(body.id))
	_field(body,"panicT",0.0,str(body.id))
	if not body.get("aggro",false): _check(game.runtime.combat.aggro(str(body.id)),"source aggro transition for continued ranged action")
	game._sync_model_nodes(0.0); _frame(Content.to_world(Combat.center(body),1.6)); game._sync_feedback_context()
	var before: Dictionary = _snapshot()
	game.runtime.director._hostile(body,STEP)
	_check(body.get("aimingThrow",false) and body.throwAimT == (350.0 if fallen else 300.0),"actual source aim timer "+id)
	# Aim must be captured before its source continuation; _context recovery would fire later.
	if not await _aim_context(id,before): return false
	var impact_before: Dictionary = _snapshot(); var hp: float = game.runtime.p.hp
	var fired := false; var hit := false; var steps := 0
	while steps < 240:
		steps += 1
		wall_clock += STEP
		probe_frame += 1; game.physics.begin_navigation_frame(probe_frame,wall_clock)
		game.runtime.advance_wall(wall_clock)
		if not game.runtime.advance(STEP/1000.0,{"input_vector":Vector2.ZERO,"monotonic_ms":wall_clock}): break
		_pose_step()
		fired = fired or not game.runtime.state.projectiles.is_empty()
		_resolve()
		if _recipes(game.runtime.feedback_snapshot()).has("holy_impact" if fallen else "bottle_impact"): hit = true; break
		await physics_frame
	if not _check(fired and hit,"actual actor-created projectile reaches player through real sweep "+id): return false
	_check(game.runtime.p.hp < hp,"actual projectile applies source player damage "+id)
	return await _context(id+"-impact",["holy_impact" if fallen else "bottle_impact"],impact_before,{"fired":fired,"hit":hit,"steps":steps,"source_ms":float(steps)*STEP})
func _aim_context(id: String,before: Dictionary) -> bool:
	_resolve()
	pose_targets = context_pose_targets(id+"-aim",{})
	var recipe := "fallen_aim" if id == "fallen" else "ranged_aim"
	var snapshot: Dictionary = game.runtime.feedback_snapshot()
	if not _check(int(_recipes(snapshot).get(recipe,0)) == COUNTS[recipe],"exact actual aim birth "+id): return false
	var point: Vector3 = _world_point(snapshot,recipe)
	var frame: Dictionary = _frame(point)
	if not _check(frame.ok,"actual aim clear observer "+id): return false
	contexts.append({"id":id+"-aim","recipes":[recipe],"fixture":active_fixture.duplicate(true),"before":before,"after":_snapshot(),"events":game.observed.duplicate(true),"continuation":"same source actor fire sequence; no artificial aim recovery"})
	frame.phase = "birth"; frame.pose_boundary = "direct owner aim command before next admitted pose step"
	await _capture(id+"-aim-birth",frame)
	return true
func _ally() -> bool:
	if not _check(game.runtime.bosses.start_coop(),"actual cooperative boss owner creates Stripe ally"): return false
	_resolve()
	var stripe: Dictionary = _actor("stripe"); var tony: Dictionary = _actor("tony")
	var staged := false
	for offset: Vector2 in [Vector2(28,0),Vector2(-28,0),Vector2(0,28),Vector2(0,-28)]:
		var copy: Dictionary = stripe.duplicate(true); copy.x = tony.x+offset.x; copy.y = tony.y+offset.y
		var point: Variant = game.physics.clear_placement(game.runtime.combat._geometry(copy))
		if not point is Vector2 or point.distance_to(Vector2(copy.x,copy.y)) > 0.001: continue
		stripe.x = point.x; stripe.y = point.y; staged = true; break
	if not _check(staged,"actual clear initial canonical ally placement"): return false
	active_fixture.placements.append({"id":"stripe","point":Vector2(stripe.x,stripe.y),"reason":"visual-only cooperative contact fixture"})
	_field(stripe,"attackCd",0.0,"stripe"); game._sync_model_nodes(0.0); await physics_frame
	_frame(Content.to_world(Combat.center(tony),1.1)); game._sync_feedback_context()
	var before: Dictionary = _snapshot(); var hp: float = tony.hp
	game.runtime.director._ally(stripe,STEP)
	_check(tony.hp == hp-10 and stripe.attackCd == 700.0,"actual ally hit and cooldown receipt")
	return await _context("ally",["ally_hit"],before,{"hp_before":hp,"hp_after":tony.hp,"cooldown":stripe.attackCd})
func _police(id: String) -> bool:
	var taser: bool = id.begins_with("taser")
	if id == "taser_fatal" and not _prior_essential(): return false
	var body: Dictionary = game.runtime.combat._spawn_cop(false,taser)
	_resolve()
	if not _check(not body.is_empty(),"actual source police spawn "+id): return false
	game._sync_model_nodes(0.0); await physics_frame
	if taser:
		# Axis-separated capsules can still overlap source logical depth at a diagonal.
		if not _check(_approach(body,26.0),"actual source-contact player placement "+id): return false
		_field(body,"taserChargeT",4000.0,str(body.id)); _field(body,"attackCd",0.0,str(body.id))
		_field(game.runtime.p,"iframes",0.0,"player")
		if id == "taser_fatal": _field(game.runtime.p,"hp",1.0,"player")
	else:
		if not _check(_approach(body,150.0),"radio caller actual distance and LOS"): return false
		_field(game.runtime.p,"wanted",1,"player"); _field(body,"radioCdT",0.0,str(body.id)); _seed(1972)
	game._sync_model_nodes(0.0); _frame(Content.to_world(Combat.center(body),1.5)); game._sync_feedback_context()
	var before: Dictionary = _snapshot(); var prior_epoch: int = before.pool.epoch
	if taser: game.runtime.director._hostile(body,STEP)
	else: _check(game.runtime.combat.tick_police(STEP,wall_clock),"actual source police timer step")
	_resolve()
	if taser:
		_check(body.taserChargeT == 0 and body.attackCd == 1000.0,"actual charged taser cooldown "+id)
		if id == "taser_fatal":
			var death_index := -1; var taser_index := -1
			for index: int in range(game.observed.size()):
				var event: Dictionary = game.observed[index]
				if event.kind == "arrest": death_index = index
				for descriptor: Dictionary in event.payload.get("feedback",[]):
					if descriptor.recipe == "taser": taser_index = index
			_check(death_index >= 0 and taser_index > death_index,"actual fatal cop arrest event precedes post-reset taser")
			_check(game.runtime.feedback_snapshot().epoch > prior_epoch and game.runtime.feedback_snapshot().particles.size() == 10,"arrest clears old pool once and preserves exactly post-reset taser")
			for row: Dictionary in game.runtime.feedback_snapshot().particles: _check(row.source_point == game.runtime.state.player_center(),"fatal taser is anchored at actual post-death source point")
	else: _check(body.radioCdT == 5000.0 and body.radioVisualT > 780.0,"actual radio source cooldown and visual timer")
	return await _context(id,["taser" if taser else "radio"],before,{"actor":body.duplicate(true),"source_method":"Director._hostile" if taser else "Combat.tick_police"})

func _prior_essential() -> bool:
	var body: Dictionary = _actor("lease_guy")
	if not _check(not body.is_empty() and _approach(body,38.0),"actual prior essential contact fixture"): return false
	var result: Dictionary = game.runtime.attack((Combat.center(body)-game.runtime.state.player_center()).normalized())
	_resolve()
	return _check(result.get("ok",false) and _recipes(game.runtime.feedback_snapshot()).get("essential",0) == 1,"old epoch contains one genuine essential contact before lifecycle")
static func contact_offsets(player: Dictionary,actor: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not Contact.valid(player) or not Contact.valid(actor): return result
	var half := Vector2(float(player.w)+float(actor.w),float(player.h)+float(actor.h))*0.5-Vector2.ONE*0.5
	if not half.is_finite() or half.x <= 0 or half.y <= 0: return result
	for index: int in range(16):
		var direction: Vector2 = Vector2.from_angle(PI*0.5+float(index)*TAU/16.0)
		var divisor: float = maxf(absf(direction.x)/half.x,absf(direction.y)/half.y)
		result.append(direction/divisor)
	return result
func _contact_candidate(body: Dictionary,center: Vector2) -> Dictionary:
	var copy: Dictionary = body.duplicate(true)
	copy.x = center.x-float(copy.w)*0.5; copy.y = center.y-float(copy.h)*0.5
	var wanted := Vector2(copy.x,copy.y)
	var source_touch: bool = Combat.overlaps(game.runtime.p,copy)
	var peer_clear: bool = not Contact.penetrating(copy,wanted,game.runtime.p)
	var result: Variant = game.physics.clear_placement(game.runtime.combat._geometry(copy))
	var exact: bool = result is Vector2 and result.distance_to(wanted) <= 0.001
	var line: bool = game.runtime.combat.can_hit(center,game.runtime.state.player_center(),str(body.id),"player")
	return {"ok":source_touch and peer_clear and exact and line,"id":body.id,"center":center,"requested_top_left":wanted,"actual_top_left":result,"source_overlap":source_touch,"source_peer_clear":peer_clear,"exact_actual_placement":exact,"can_hit":line,"geometry":game.runtime.combat._geometry(copy)}
func _stage_contact_pair(tony: Dictionary,brendan: Dictionary,spawn: Vector2) -> bool:
	var tony_trials: Array[Dictionary] = []; var brendan_trials: Array[Dictionary] = []
	for offset: Vector2 in contact_offsets(game.runtime.p,tony): tony_trials.append(_contact_candidate(tony,spawn+offset))
	for offset: Vector2 in contact_offsets(game.runtime.p,brendan): brendan_trials.append(_contact_candidate(brendan,spawn+offset))
	active_fixture.contact_search = {"tony":tony_trials,"brendan":brendan_trials,"pair_cap":256,"selected":[]}
	for first: Dictionary in tony_trials:
		if not first.ok: continue
		for second: Dictionary in brendan_trials:
			if not second.ok or Combat.overlaps(first.geometry,second.geometry): continue
			active_fixture.contact_search.selected = [first,second]
			for entry: Dictionary in [first,second]:
				var body: Dictionary = tony if entry.id == tony.id else brendan
				var point: Vector2 = entry.actual_top_left
				active_fixture.placements.append({"id":body.id,"before":Vector2(body.x,body.y),"fixture":point,"proof":"actual Adapter exact clear_placement + source contact + can_hit; pair preflight before writes"})
				body.x = point.x; body.y = point.y
			return true
	return false
func _death_then_taser() -> bool:
	if not _prior_essential(): return false
	var tony: Dictionary = _actor("tony")
	var brendan: Dictionary = game.runtime.combat._spawn_cop(false,true)
	if not _check(not brendan.is_empty() and game.runtime.combat.aggro("tony"),"actual ordinary Tony aggro and source Brendan spawn"): return false
	var spawn: Vector2 = game.runtime.state.SPAWN+Vector2(game.runtime.p.w,game.runtime.p.h)*0.5
	if not _check(_place_player(spawn),"actual legal source respawn point for two-hit lifecycle fixture"): return false
	if not _check(_stage_contact_pair(tony,brendan,spawn),"both canonical standing body shapes clear with strict source contact and LOS"): return false
	_field(game.runtime.p,"hp",1.0,"player"); _field(game.runtime.p,"iframes",0.0,"player")
	_field(tony,"attackCd",0.0,"tony"); _field(brendan,"attackCd",0.0,str(brendan.id)); _field(brendan,"taserChargeT",4000.0,str(brendan.id))
	game._sync_model_nodes(0.0); await physics_frame
	var before: Dictionary = _snapshot()
	# The real Director captures its roster once. Tony's actual death removes police
	# from the authoritative array; the source's same-pass detached Brendan still
	# finishes his charged contact against the reset player's source iframes.
	var accepted: bool = game.runtime.director.tick(STEP,wall_clock)
	_resolve()
	var death_index := -1; var taser_index := -1
	for index: int in range(game.observed.size()):
		var event: Dictionary = game.observed[index]
		if event.kind == "death": death_index = index
		for descriptor: Dictionary in event.payload.get("feedback",[]):
			if descriptor.recipe == "taser": taser_index = index
	_check(accepted and death_index >= 0 and taser_index > death_index,"real same-pass ordinary death precedes detached canonical Brendan taser")
	_check(_actor(str(brendan.id)).is_empty(),"source death really removed police from authoritative roster")
	_check(game.runtime.feedback_snapshot().epoch > before.pool.epoch and game.runtime.feedback_snapshot().particles.size() == 10,"death removes prior essential and preserves only post-reset taser")
	return await _context("death_then_taser",["taser"],before,{"ok":accepted,"death_event":death_index,"taser_event":taser_index,"detached_source_cop_id":brendan.id})

func _case(id: String) -> bool:
	if not await _fresh(id): return false
	var result := false
	match id:
		"essential": result = await _melee(id,"lease_guy",["essential"])
		"melee": result = await _melee(id,"tony",["melee_sparks","melee_rust","melee_flash"])
		"bottle": result = await _bottle()
		"trash_cash","trash_rats": result = await _trash(id)
		"dumpster": result = await _dumpster()
		"possum": result = await _possum()
		"ranged","fallen": result = await _ranged(id)
		"tony2","tony3","older2","older3": result = await _boss_phase(id)
		"ally": result = await _ally()
		"radio","taser","taser_fatal": result = await _police(id)
		"death_then_taser": result = await _death_then_taser()
	fixtures.append(active_fixture.duplicate(true))
	if result: completed_cases.append(id)
	_check(result,"case completed "+id)
	return result
func _source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in ["res://scripts/full_scene.gd","res://scripts/full_runtime.gd","res://scripts/world_feedback.gd","res://scripts/world_feedback_view.gd","res://scripts/world_feedback_anchors.gd","res://scripts/combat_system.gd","res://scripts/actor_director.gd","res://scripts/boss_system.gd","res://scripts/interactive_prop_actions.gd","res://scripts/world_prop_actions.gd","res://scripts/companion_system.gd","res://data/source_content.json"]: result[path] = FileAccess.get_sha256(path)
	return result
func _finish(complete: bool) -> void:
	if finishing: return
	finishing = true
	if game != null: game.set_process(false)
	var hashes: Dictionary = _source_hashes()
	var available := true
	for path: String in hashes:
		if path.ends_with(".gd") and str(hashes[path]).is_empty(): available = false
	var report := {"schema":1,"format":"rock-bottom-domain-feedback-visual","complete":complete,"acceptance":complete and failures.is_empty(),"scope":"staged actual-domain real-render evidence only; not controller/campaign/performance acceptance","packet":packet,"width":width,"height":int(width*9/16),"wall_ms":Time.get_ticks_msec()-started,"checks":checks,"failures":failures,"expected_cases":CASES.get(packet,[]),"completed_cases":completed_cases,"contexts":contexts,"captures":captures,"fixtures":fixtures,"source_hashes":hashes,"source_hashes_available":available,"source_hash_note":"Copied archive/export hashes are required when compiled scripts are unavailable.","visual_review_required":true,"renderer":RenderingServer.get_current_rendering_method(),"unproven":skipped_visual_claims}
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("feedback-visual.json"),FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(_json(report),"\t")); file.close()
	print("ACTUAL DOMAIN FEEDBACK VISUAL: ","PASS" if report.acceptance else "FAIL"," ",packet," ",checks," checks; ",contexts.size()," contexts; ",captures.size()," captures")
	if game != null: game.queue_free()
	await process_frame
	quit(0 if report.acceptance else 1)
func _timeout() -> void:
	if finishing: return
	_check(false,"global300s watchdog including startup; incomplete coroutine cannot pass")
	_finish(false)
func _run() -> void:
	started = Time.get_ticks_msec()
	if not _args(): await _finish(false); return
	if not _check(DisplayServer.get_name() != "headless","actual native/Web renderer required; dummy rendering cannot satisfy evidence"): await _finish(false); return
	root.size = Vector2i(width,int(width*9/16)); root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	create_timer(float(MAX_WALL_MS)/1000.0).timeout.connect(_timeout)
	source_eye = SphereShape3D.new(); source_eye.radius = 0.06
	game = ObservedScene.new(); root.add_child(game)
	while not game.ready_for_play and Time.get_ticks_msec()-started < 90000: await process_frame
	if not _check(game.ready_for_play,"real FullScene boot within90s"): await _finish(false); return
	suspend_callbacks(game,game.hud)
	game.store.save_path = output.path_join("visual-only-save.json"); game.store.storage_key = "world_feedback_visual_fixture"
	root.grab_focus(); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	wall_clock = maxf(float(Time.get_ticks_msec()),float(game.runtime._wall_ms))
	for id: String in CASES[packet]:
		if finishing: return
		await _case(id)
	_check(completed_cases.size() == CASES[packet].size(),"every named case reached its completion witness")
	_check(contexts.size() == CONTEXTS[packet],"every required transition context captured")
	var found: Dictionary = {}
	for context: Dictionary in contexts:
		for recipe: String in context.recipes: found[recipe] = true
	_check(found.size() == 9,"packet covers nine distinct actual source recipes")
	await _finish(true)
