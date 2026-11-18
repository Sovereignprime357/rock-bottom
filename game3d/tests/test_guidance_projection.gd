extends SceneTree
const GuideProjection = preload("res://scripts/guidance_projection.gd")
var checks: int = 0
var failures: Array[String] = []
var completed: int = 0
var groups: int = 0
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _near(a: float,b: float) -> bool: return absf(a-b) <= 0.000001
func _source() -> void:
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/guidance_projection_reference.json"))
	_check(fixture is Dictionary and fixture.count == 30,"30 unchanged-source draw cases exist")
	if not fixture is Dictionary: return
	for row: Dictionary in fixture.cases:
		var style: Dictionary = GuideProjection.source_style(row.visualMs)
		_check(_near(style.alpha,row.alpha) and _near(style.width,row.width),"source pulse opacity and2px line")
		if row.kind == "ring":
			_check(_near(style.radius,row.radius),"source11to14px pulsing radius")
			_check(floor(float(row.point[0])+style.square_offset.x+0.5) == row.square[0] and floor(float(row.point[1])+style.square_offset.y+0.5) == row.square[1],"source square rounds above ring")
			_check(row.square[2] == style.square_size and row.square[3] == style.square_size,"source4px square")
		else:
			_check(row.vertices.size() == 4 and style.arrow.size() == 4,"source four-arrow-vertex shape")
			for index: int in range(4): _check(style.arrow[index].distance_to(Vector2(row.vertices[index][0],row.vertices[index][1])) < 0.000001,"source arrow vertex"+str(index))
		_check(row.fill == "#e8c040","source gold guidance color")
		_check(style.arrow_alpha == 1.0,"source arrow fill does not inherit pulsing stroke alpha")
		completed += 1
	_check(fixture.modalDraws == 0 and fixture.randomDraws == 0,"source guide modal suppression and zero RNG")
	groups += 1
func _geometry() -> void:
	var viewport := Vector2(1280,720); var safe := Rect2(24,200,1232,360)
	var camera := Transform3D(Basis.IDENTITY,Vector3(0,1.63,0)); var projection: Projection = Projection.create_perspective(78.0,1280.0/720.0,0.06,380.0)
	var front: Dictionary = GuideProjection.project(Vector3(0,1.63,-10),camera,projection,viewport,safe,90,1)
	_check(front.kind == "ring" and front.center.distance_to(viewport*0.5) < 0.001 and front.square,"front visible point receives centered source ring/square")
	for visibility: int in [-1,0,1]:
		var result: Dictionary = GuideProjection.project(Vector3(0,1.63,-10),camera,projection,viewport,safe,90,visibility)
		_check(result.square == (visibility == 1) and result.dashed == (visibility == 0),"clear/occluded/unknown convey no false arrival visibility")
		_check(_near(result.alpha,front.alpha*(0.45 if visibility == 0 else 1.0)),"occlusion uses muted source pulse")
	for target: Vector3 in [Vector3(0,1.63,10),Vector3(10,1.63,10),Vector3(-10,1.63,10),Vector3(0,1.63,-0.01),Vector3(0,1.63,-400),Vector3(100,1.63,-10),Vector3(-100,1.63,-10),Vector3(0,100,-10),Vector3(0,-100,-10)]:
		var result: Dictionary = GuideProjection.project(target,camera,projection,viewport,safe,90)
		_check(result.kind == "arrow" and result.center.x >= safe.position.x and result.center.x <= safe.end.x and result.center.y >= safe.position.y and result.center.y <= safe.end.y,"offscreen/near/far/behind clamped safe arrow "+str(target))
		_check(_near(result.center.x,safe.position.x) or _near(result.center.x,safe.end.x) or _near(result.center.y,safe.position.y) or _near(result.center.y,safe.end.y),"arrow reaches one safe edge")
		_check(is_finite(result.angle),"arrow direction finite")
	var behind: Dictionary = GuideProjection.project(Vector3(0,1.63,10),camera,projection,viewport,safe,90)
	_check(behind.behind and _near(behind.angle,PI/2.0) and _near(behind.center.y,safe.end.y),"straight-behind points down without mirrored projection")
	var far_ahead: Dictionary = GuideProjection.project(Vector3(0,1.63,-400),camera,projection,viewport,safe,90)
	_check(not far_ahead.behind and _near(far_ahead.angle,-PI/2.0) and _near(far_ahead.center.y,safe.position.y),"clipped front center points ahead rather than implying behind")
	var right: Dictionary = GuideProjection.project(Vector3(10,1.63,10),camera,projection,viewport,safe,90)
	var left: Dictionary = GuideProjection.project(Vector3(-10,1.63,10),camera,projection,viewport,safe,90)
	_check(right.center.x > viewport.x*0.5 and left.center.x < viewport.x*0.5,"behind preserves physical left/right turn sides")
	for yaw: float in [0.0,PI/2.0,PI,-PI/2.0]:
		camera.basis = Basis(Vector3.UP,yaw)
		var world: Vector3 = camera*Vector3(0,0,-10)
		var result: Dictionary = GuideProjection.project(world,camera,projection,viewport,safe,90,1)
		_check(result.kind == "ring" and result.center.distance_to(viewport*0.5) < 0.001,"camera yaw projection follows actual basis")
	var a: Dictionary = GuideProjection.source_style(100); a.arrow[0] = Vector2(999,999)
	_check(GuideProjection.source_style(100).arrow[0] == Vector2(10,0),"returned geometry does not poison static shape")
	groups += 1
func _invalid() -> void:
	var camera := Transform3D.IDENTITY; var projection: Projection = Projection.create_perspective(78,1.5,0.06,380)
	var viewport := Vector2(900,600); var safe := Rect2(24,200,852,250); var target := Vector3(0,0,-10)
	for invalid_target: Vector3 in [Vector3.ZERO,Vector3(NAN,0,-10),Vector3(INF,0,-10)]:
		_check(GuideProjection.project(invalid_target,camera,projection,viewport,safe,90).is_empty(),"camera-coincident or nonfinite target suppressed")
	for invalid_view: Vector2 in [Vector2.ZERO,Vector2(-1,500),Vector2(INF,500)]:
		_check(GuideProjection.project(target,camera,projection,invalid_view,safe,90).is_empty(),"invalid viewport suppressed")
	for invalid_safe: Rect2 in [Rect2(),Rect2(2000,0,100,100),Rect2(0,0,5,5),Rect2(NAN,0,100,100)]:
		_check(GuideProjection.project(target,camera,projection,viewport,invalid_safe,90).is_empty(),"invalid safe rectangle suppressed")
	camera.basis = Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
	_check(GuideProjection.project(target,camera,projection,viewport,safe,90).is_empty(),"singular camera suppressed before inverse")
	camera = Transform3D.IDENTITY
	var empty := Projection(Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO)
	_check(GuideProjection.project(target,camera,empty,viewport,safe,90).is_empty(),"singular projection suppressed")
	projection.x.x = INF
	_check(GuideProjection.project(target,camera,projection,viewport,safe,90).is_empty(),"nonfinite projection suppressed")
	_check(GuideProjection.source_style(NAN).is_empty() and GuideProjection.source_style(INF).is_empty(),"nonfinite visual time suppressed")
	groups += 1
func _actual_camera() -> void:
	var camera := Camera3D.new(); root.add_child(camera); camera.make_current(); camera.near = 0.06; camera.far = 380; camera.position = Vector3(0,1.63,0)
	await process_frame
	var viewport: Vector2 = root.get_visible_rect().size
	_check(viewport.x > 100 and viewport.y > 100,"actual root viewport dimensions")
	var safe := Rect2(Vector2(24,42),viewport-Vector2(48,76))
	for fov: float in [45.0,78.0,100.0]:
		camera.fov = fov
		for yaw: float in [0.0,PI/2.0,-PI/2.0]:
			camera.rotation.y = yaw
			for local: Vector3 in [Vector3(0,0,-10),Vector3(0.5,0.5,-10),Vector3(-1,-0.5,-20)]:
				var target: Vector3 = camera.global_transform*local
				var actual: Vector2 = camera.unproject_position(target)
				var result: Dictionary = GuideProjection.project(target,camera.global_transform,camera.get_camera_projection(),viewport,safe,90,1)
				_check(not camera.is_position_behind(target) and result.kind == "ring","actual Camera3D forward classification")
				_check(result.center.distance_to(actual) <= 0.002,"pure projection matches actual Camera3D unproject at FOV/yaw")
	camera.queue_free(); await process_frame
	groups += 1
func _run() -> void:
	_source(); _geometry(); _invalid(); await _actual_camera()
	_check(completed == 30 and groups == 4,"all30draw samples and fourgroups completed")
	if failures.is_empty(): print("3D GUIDANCE PROJECTION: PASS (%d checks / 30 source draw cases)" % checks); quit(0)
	else:
		for failure: String in failures: print("FAIL: "+failure)
		print("3D GUIDANCE PROJECTION: FAIL (%d/%d)" % [failures.size(),checks]); quit(1)
