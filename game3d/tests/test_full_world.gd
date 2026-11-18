extends SceneTree
## Run serially with the pinned Godot executable, --headless --path game3d
## --script res://tests/test_full_world.gd. This exercises generated physics.

const World = preload("res://scripts/full_neighborhood.gd")
const Content = preload("res://scripts/content_catalog.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _ray(world: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.hit_from_inside = true
	return world.get_world_3d().direct_space_state.intersect_ray(query)


func _capsule_clear(world: Node3D, point: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.48
	shape.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, Vector3(point.x, 0.96, point.z))
	query.collision_mask = 1
	query.margin = 0.0
	return world.get_world_3d().direct_space_state.intersect_shape(query, 8).is_empty()


func _route_length(route: PackedVector3Array) -> float:
	var total: float = 0.0
	for index: int in range(route.size() - 1): total += route[index].distance_to(route[index + 1])
	return total


func _capsule_segment_clear(world: Node3D, from: Vector3, to: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.48
	shape.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, Vector3(from.x, 0.96, from.z))
	query.motion = Vector3(to.x - from.x, 0, to.z - from.z)
	query.collision_mask = 1
	query.margin = 0.0
	var motion: PackedFloat32Array = world.get_world_3d().direct_space_state.cast_motion(query)
	return motion.size() == 2 and motion[0] >= 0.99999


func _source_endpoint(world: Node3D, point: Dictionary) -> Vector3:
	var source := Vector2(float(point.x), float(point.y))
	var raw: Vector3 = Content.to_world(source, 0.06)
	if world.is_clear_position(raw) and _capsule_clear(world, raw): return raw
	for key: String in world.service_points:
		var service: Dictionary = world.service_points[key]
		if service.source_point.distance_to(source) < 0.02 and service.approach.is_finite():
			return service.approach
	return Vector3.INF


func _test_full_oracle(world: Node3D) -> void:
	var path: String = "res://tests/fixtures/world_routes_reference.json"
	check(FileAccess.file_exists(path), "live-selector world route oracle exists")
	if not FileAccess.file_exists(path): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(parsed is Dictionary and int(parsed.get("schema", 0)) == 1, "world route oracle schema")
	if not parsed is Dictionary: return
	var oracle: Dictionary = parsed
	check(str(oracle.source.corpusSha256) == str(Content.load_content().source.corpusSha256), "world route oracle matches current source corpus")
	check(oracle.campaignLegs.size() == 69 and oracle.routePairs.size() == 252, "all69 campaign legs and252 legal route pairs")
	check(oracle.excludedRoutePairs.size() == 1 and str(oracle.excludedRoutePairs[0].name) == "scrap_gate <-> ditch_gauge", "ratified excluded route remains excluded")
	var endpoints: Dictionary = {}
	for point: Dictionary in oracle.endpoints:
		var key: String = str(point.x) + "," + str(point.y)
		var resolved: Vector3 = _source_endpoint(world, point)
		check(resolved.is_finite(), "oracle endpoint has a real source action approach: " + key)
		endpoints[key] = resolved
	var cache: Dictionary = {}
	var legs: Array = []
	legs.append_array(oracle.campaignLegs)
	legs.append_array(oracle.routePairs)
	var worst: float = 0.0
	var worst_name: String = ""
	var completed: int = 0
	var started: int = Time.get_ticks_msec()
	for leg: Dictionary in legs:
		var a_key: String = str(leg.a.x) + "," + str(leg.a.y)
		var b_key: String = str(leg.b.x) + "," + str(leg.b.y)
		var from: Vector3 = endpoints[a_key]
		var to: Vector3 = endpoints[b_key]
		if not from.is_finite() or not to.is_finite(): continue
		var cache_key: String = a_key + " -> " + b_key
		var reverse_key: String = b_key + " -> " + a_key
		var route := PackedVector3Array()
		if cache.has(cache_key): route = cache[cache_key]
		elif cache.has(reverse_key):
			route = cache[reverse_key].duplicate(); route.reverse()
		else:
			route = world.find_route(from, to)
			cache[cache_key] = route
		check(route.size() >= 2, "full oracle physical path: " + str(leg.name))
		if route.size() < 2: continue
		for index: int in range(route.size() - 1):
			check(world.segment_clear(route[index], route[index + 1]), "oracle grown-footprint clearance: " + str(leg.name))
			check(_capsule_segment_clear(world, route[index], route[index + 1]), "oracle real capsule sweep: " + str(leg.name))
		var seconds: float = _route_length(route) / Content.speed_metres(2.2)
		check(seconds < float(oracle.timing.legBudgetSeconds), "oracle base-walk60s budget: " + str(leg.name) + " = " + str(seconds))
		if seconds > worst: worst = seconds; worst_name = str(leg.name)
		completed += 1
		if completed % 32 == 0:
			print("FULL WORLD ORACLE PROGRESS: ", completed, "/321; ", Time.get_ticks_msec() - started, "ms")
			await process_frame
	check(completed == 321, "all321 legal campaign/route walks actually completed")
	print("FULL WORLD ORACLE: ", completed, " legs; worst ", worst, "s base walk (", worst_name, "); elapsed ", Time.get_ticks_msec() - started, "ms; actual capsule sweep per segment")


func _test_route(world: Node3D, from: Vector3, to: Vector3, label: String, sample_physics: bool = false) -> PackedVector3Array:
	var route: PackedVector3Array = world.find_route(from, to)
	check(route.size() >= 2, "physical route exists: " + label + " " + str(world.last_route_metrics))
	if route.size() < 2: return route
	check(route[0].is_equal_approx(from) and route[-1].is_equal_approx(to), "route retains exact approach endpoints: " + label)
	for index: int in range(route.size() - 1):
		check(world.segment_clear(route[index], route[index + 1]), "route segment clears generated footprints: " + label)
		if sample_physics:
			var samples: int = maxi(1, ceili(route[index].distance_to(route[index + 1]) / 0.65))
			for sample_index: int in range(samples + 1):
				var point: Vector3 = route[index].lerp(route[index + 1], float(sample_index) / samples)
				check(_capsule_clear(world, point), "real capsule clears route: " + label + " at " + str(point))
	return route


func _run() -> void:
	var world: Node3D = World.new()
	root.add_child(world)
	world.build()
	await process_frame
	await physics_frame
	await physics_frame
	check(world.built, "full world built from source content")
	var counts: Dictionary = {"zones": 23, "terrain": 15, "roads": 28, "crossings": 26, "paths": 8,
		"rails": 4, "structures": 53, "props": 193, "interactiveProps": 14, "decor": 96, "wires": 20, "lights": 24}
	for category: String in counts:
		var records: Dictionary = world.source_records.get(category, {})
		check(records.size() == int(counts[category]), "full source coverage: " + category)
		for id: String in records:
			check(int(records[id].mesh_count) > 0, "actual meshes generated for " + category + ":" + id)
	var children_before: int = world.get_child_count()
	world.build()
	check(world.get_child_count() == children_before, "world construction is idempotent")
	check(int(world.build_metrics.grid_bytes) == 860 * 560, "navigation uses one packed blocked byte per cell")
	check(int(world.batch_stats.source_meshes) > 1000 and int(world.batch_stats.batches) < int(world.batch_stats.source_meshes), "static construction is spatially batched")
	check(world.presentation_adaptations.size() == 3, "two embedded dumpsters and the occupied boxcar have explicit real-opening adaptations")
	check(not world.is_clear_position(Vector3(-42.1, 0, 0)) and not world.is_clear_position(Vector3(302.1, 0, 0)), "full source boundary cannot be crossed")
	var spawn: Vector3 = world.safe_spawn(world.anchors().spawn)
	check(spawn.is_finite() and _capsule_clear(world, spawn), "source spawn has real clear recovery placement")
	check(Content.to_source(world.anchors().spawn).is_equal_approx(Vector2(1062, 854)), "spawn uses source body center and correct origin")
	for raw: Variant in Content.load_content().actors.day1:
		var actor: Dictionary = raw
		check(world.anchors()[str(actor.id)].is_equal_approx(Content.body_position(actor)), "actor placement remains source-centered: " + str(actor.id))
	for witness: Dictionary in world.structure_witnesses:
		var hit: Dictionary = _ray(world, witness.from, witness.to)
		check(not hit.is_empty() and str(hit.collider.get_meta("source_owner", "")) == str(witness.owner), "visible rear wall stops physics ray: " + str(witness.owner))
	for aperture: Dictionary in world.aperture_witnesses:
		check(_ray(world, aperture.from, aperture.to).is_empty(), "visible aperture has no invisible full-footprint wall: " + str(aperture.owner))
		check(float(aperture.width) >= 0.96, "aperture accommodates source-width body: " + str(aperture.owner))
	var live_owners: Dictionary = {}
	for obstacle: Dictionary in world.obstacle_records():
		var body: StaticBody3D = obstacle.body as StaticBody3D
		check(is_instance_valid(body) and body.collision_layer == 1 and body.get_child_count() > 0,
			"live collision body for " + str(obstacle.owner))
		live_owners[str(obstacle.owner)] = true
	for id: String in world.source_records.props:
		var prop: Dictionary = world.source_records.props[id]
		if not str(prop.type) in World.FLAT_PROPS:
			check(live_owners.has("props:" + id), "standing prop has real collision: " + id + "/" + str(prop.type))
	for key: String in world.service_points:
		var service: Dictionary = world.service_points[key]
		var approach: Vector3 = service.approach
		check(approach.is_finite(), "service has a clear approach: " + key)
		if not approach.is_finite(): continue
		check(_capsule_clear(world, approach), "actual source-width capsule fits service approach: " + key)
		var distance: float = Vector2(approach.x, approach.z).distance_to(Vector2(service.target.x, service.target.z))
		check(distance < float(service.reach), "service respects source interaction reach: " + key)
		var hit: Dictionary = _ray(world, approach + Vector3(0, 1.45, 0), service.target)
		var owner: String = str(hit.collider.get_meta("source_owner", "")) if not hit.is_empty() else ""
		check(hit.is_empty() or (str(service.kind) != "actor" and owner == str(service.structure_id)), "eye-level service ray is unobstructed: " + key + " hit " + owner)
	# Every route stop and all legacy indoor NPCs must connect to the real street network.
	for id: String in world.route_points():
		var approach: Vector3 = world.service_points["route:" + id].approach
		if approach.is_finite(): _test_route(world, spawn, approach, "spawn to " + id)
	for id: String in ["pete", "tony", "priest", "barb", "laundromat_lady", "priests_son", "karaoke", "skid_sherri", "prop:3", "prop:4"]:
		var approach: Vector3 = world.service_points[id].approach
		if approach.is_finite(): _test_route(world, spawn, approach, "legacy/interior " + id, true)
	var from: Vector3 = world.service_points["route:pawn_sill"].approach
	var to: Vector3 = world.service_points["route:ditch_gauge"].approach
	if from.is_finite() and to.is_finite():
		var critical: PackedVector3Array = _test_route(world, from, to, "pawn_sill to ditch_gauge", true)
		if critical.size() >= 2:
			var metres: float = _route_length(critical)
			var walk_seconds: float = metres / Content.speed_metres(2.2)
			print("FULL WORLD CRITICAL ROUTE: ", metres, "m / ", walk_seconds, "s base walk; physical radius0.48m; turn/approach controller trial still required")
			var source_bends: Array[Vector2] = []
			for bend: Vector3 in critical: source_bends.append(Content.to_source(bend))
			print("FULL WORLD CRITICAL SOURCE BENDS: ", source_bends)
			check(walk_seconds < 60.0, "actual collision route fits source60s budget at base walk without speed bonus")
	await _test_full_oracle(world)
	world.set_day_time(60.0)
	var day: Color = world.sky_material.sky_horizon_color
	world.set_day_time(180.0)
	check(world.sky_material.sky_horizon_color.get_luminance() < day.get_luminance() * 0.6, "full world inherits actual dark night sky")
	print("FULL WORLD BUILD METRICS: ", world.build_metrics)
	print("FULL WORLD GEOMETRY ", "PASS" if failures.is_empty() else "FAIL", ": ", checks, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
