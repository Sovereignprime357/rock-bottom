extends SceneTree
const Probe = preload("res://tests/world_dust_visual_probe.gd")
var checks: int = 0
var failures: int = 0
var groups: int = 0
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1; push_error(label)
func _initialize() -> void: call_deferred("_run")
func _valid() -> Dictionary:
	var contexts: Array = []
	for id: String in Probe.CASES:
		contexts.append({"id":id,"fixture":{"physics_sentinel":{"ok":true}},"start_capture":0,"end_capture":2,"admitted_ms":6300.0,"tracked":[1,2],"survived":[],"wall":{"ok":true},"ablation":{"changed_pixels":0 if id == "wall_occlusion" else 2}})
	return {"complete":true,"failures":[],"completed":Probe.CASES.duplicate(),"contexts":contexts,"captures":[{},{}],"wall_ms":179999,"width":960,"height":540}
func _run() -> void:
	var points: Array[Vector2] = [Vector2(100,200),Vector2(140,240)]
	_check(Probe.pixel_rect(points,Vector2(1280,720),Vector2i(1280,720)) == Rect2i(97,197,47,47),"native1280 exact projection rounding/pad")
	_check(Probe.pixel_rect(points,Vector2(1280,720),Vector2i(960,540)) == Rect2i(72,147,37,37),"actual960 uses3:4 logical-to-framebuffer mapping")
	points.assign([Vector2(-100,-100),Vector2(10,10)])
	_check(Probe.pixel_rect(points,Vector2(1280,720),Vector2i(960,540)) == Rect2i(0,0,12,12),"offscreen projection clips actual pixel bounds")
	points.assign([Vector2.INF])
	_check(Probe.pixel_rect(points,Vector2(1280,720),Vector2i(960,540)) == Rect2i(),"invalid projection refuses")
	var candidates: Dictionary = Probe.wall_candidates([
		{"owner":"structures:far","bounds":AABB(Vector3(30,0,0),Vector3(0.24,3,4))},
		{"owner":"structures:near","bounds":AABB(Vector3(15,0,0),Vector3(0.24,3,4))},
		{"owner":"structures:roof","bounds":AABB(Vector3(1,4,0),Vector3(4,0.24,4))},
		{"owner":"props:not_wall","bounds":AABB(Vector3(1,0,0),Vector3(0.24,3,4))}
	],Vector3(0,1.7,2))
	_check(candidates.candidate_count == 2 and candidates.candidates[0].owner == "structures:near" and candidates.candidates[1].owner == "structures:far","nearest real walls beyond12m remain eligible in distance order")
	_check(candidates.structure_walls == 2 and candidates.vertical_matches == 2,"wall census retains strict structural/vertical filters")
	var many: Array = []
	for i: int in range(32): many.append({"owner":"structures:"+str(i),"bounds":AABB(Vector3(20+i,0,0),Vector3(0.24,3,4))})
	var capped: Dictionary = Probe.wall_candidates(many,Vector3(0,1.7,2))
	_check(capped.candidate_count == 32 and capped.candidates.size() == 16,"observer search retains only16 nearest walls and32 eye attempts")
	groups += 1
	var good: Dictionary = _valid()
	_check(Probe.assess(good),"complete bounded receipts accepted independently of human aesthetics")
	for kind: String in ["missing_case","wrong_size","timeout","failure","incomplete","no_wall","retained_serial","missing_serials","missing_pixels","missing_physics"]:
		var bad: Dictionary = good.duplicate(true)
		match kind:
			"missing_case": bad.completed.pop_back()
			"wrong_size": bad.height = 720
			"timeout": bad.wall_ms = 180001
			"failure": bad.failures.append("actual engine failure")
			"incomplete": bad.complete = false
			"no_wall": bad.contexts[6].wall.ok = false
			"retained_serial": bad.contexts[7].survived.append(1)
			"missing_serials": bad.contexts[7].tracked.clear()
			"missing_pixels": bad.contexts[0].ablation.changed_pixels = 0
			"missing_physics": bad.contexts[0].fixture.physics_sentinel.ok = false
		_check(not Probe.assess(bad),"report rejects "+kind)
	groups += 1
	var a := Image.create(16,16,false,Image.FORMAT_RGBA8); a.fill(Color.BLACK)
	var b := a.duplicate() as Image; b.set_pixel(5,5,Color.WHITE)
	_check(Probe.pixel_changes(a,b,Rect2i(0,0,16,16)) == 1,"real pixel counter detects one changed raster pixel")
	_check(Probe.pixel_changes(a,b,Rect2i(0,0,4,4)) == 0,"occlusion ROI ignores unrelated changed pixels")
	_check(Probe.pixel_changes(a,b,Rect2i(-4,-4,10,10)) == 1,"ROI clipping retains actual overlapping change")
	var row := {"world_anchor":Vector3(2,1,4),"birth_right":Vector3.RIGHT,"offset":Vector2(3,-5)}
	_check(Probe.row_point(row).distance_to(Vector3(2.12,1.2,4)) < 0.000001,"actual frozen-anchor plus source drift conversion")
	groups += 1
	_check(groups == 3,"all three detached contract groups complete")
	print("WORLD DUST VISUAL CONTRACT: ","PASS" if failures == 0 else "FAIL","; ",checks," checks; ",groups," groups; real render evidence pending")
	quit(0 if failures == 0 else 1)
