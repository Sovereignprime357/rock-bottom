from pathlib import Path
import hashlib,json
H=Path(__file__).resolve().parent;R=H.parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
def put(p,b):
 p=H/p;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
def edit(b,a,c):
 a=a.encode();c=c.encode();assert b.count(a)==1,a;return b.replace(a,c,1)
probe_ref='game3d/tests/dave_walkthrough_probe.gd';contract_ref='game3d/tests/test_dave_walkthrough_contract.gd'
old=(R/probe_ref).read_bytes();test=(R/contract_ref).read_bytes()
assert sha(old)=='5ccad87002e44292bb517dbe2f7c77a1daae1034b8307858ed761e31825878b2'
assert sha(test)=='c2a7dec8778dd8121cf5f6218770504ca34c914925821e5998947ff65e64564f'
addition='''static func resume_choice(origin: Vector3, preferred: Vector3, certify: Callable) -> Dictionary:
	if not origin.is_finite() or not preferred.is_finite() or not certify.is_valid(): return {"ok":false,"attempts":0}
	var heading := Vector2(preferred.x-origin.x,preferred.z-origin.z)
	if heading.length_squared() < 0.000001: return {"ok":false,"attempts":0}
	var angle: float = heading.angle()
	var attempts: int = 0
	for offset: float in [0.0,PI*0.25,-PI*0.25,PI*0.5,-PI*0.5,PI*0.75,-PI*0.75,PI]:
		var point := origin+Vector3(cos(angle+offset),0,sin(angle+offset))*0.35
		attempts += 1
		var receipt: Dictionary = certify.call(origin,point)
		if receipt.get("ok") == true: return {"ok":true,"point":point,"attempts":attempts,"certificate":receipt.duplicate(true)}
	return {"ok":false,"attempts":attempts}

'''
new=edit(old,'static func report_errors(row: Dictionary) -> Array[String]:',addition+'static func report_errors(row: Dictionary) -> Array[String]:')
before='''	var route: PackedVector3Array = _resident_route(origin,spawn)
	if not _check(route.size() >= 2,"certified normal return direction"): return
	var point: Vector3 = route[1]; var move_start: int = Time.get_ticks_msec()
	while game.player.position.distance_to(origin) < 0.15:
		if not _alive() or not _check(Time.get_ticks_msec()-move_start < 5000,"finite resumed movement"): _release(); return
		var alignment: float = _aim(Vector3(point.x,game.camera.global_position.y,point.z),_dt())
		_motion(Vector2(point.x-game.player.position.x,point.z-game.player.position.z).normalized() if alignment > 0.96 else Vector2.ZERO)
		await game.frame_sampled
'''
after='''	var point := Vector3.INF
	var move_start: int = Time.get_ticks_msec()
	var last_choice: int = move_start-250
	var choices: int = 0
	proof.resume_choices = []
	while game.player.position.distance_to(origin) < 0.15:
		if not _alive() or not _check(Time.get_ticks_msec()-move_start < 5000,"finite resumed movement"): _release(); return
		var now: int = Time.get_ticks_msec()
		var clear: bool = point.is_finite() and bool(_combat_segment(game.player.position,point).ok)
		if not clear:
			_release()
			if now-last_choice >= 250 and choices < 20:
				last_choice = now; choices += 1
				var selected: Dictionary = resume_choice(game.player.position,spawn,Callable(self,"_combat_segment"))
				proof.resume_choices.append({"wall_ms":now-boot_wall,"choice":choices,"result":selected.duplicate(true)})
				point = selected.point if selected.ok else Vector3.INF
				clear = bool(selected.ok)
		if clear:
			var alignment: float = _aim(Vector3(point.x,game.camera.global_position.y,point.z),_dt())
			_motion(Vector2(point.x-game.player.position.x,point.z-game.player.position.z).normalized() if alignment > 0.96 else Vector2.ZERO)
		await game.frame_sampled
'''
new=edit(new,before,after)
testaddition='''class ResumeCertificates:
	extends RefCounted
	var accepted_call: int = 0
	var points: Array[Vector3] = []
	func certify(from: Vector3,to: Vector3) -> Dictionary:
		points.append(to)
		return {"ok":accepted_call > 0 and points.size() == accepted_call,"from":from,"to":to,"reason":"fixture certificate"}

func _resume_checks() -> void:
	var witness := ResumeCertificates.new()
	var from := Vector3(2,0.06,3)
	var preferred := from+Vector3(0,0,-25)
	witness.accepted_call = 2
	var alternate: Dictionary = Probe.resume_choice(from,preferred,witness.certify)
	_check(alternate.ok and alternate.attempts == 2 and witness.points.size() == 2,"blocked return heading chooses actual certified alternate, without requiring a distant route")
	_check(alternate.point == witness.points[1] and alternate.point != witness.points[0],"chosen point is the accepted alternate only")
	_check(alternate.certificate.to == alternate.point,"choice retains the actual matching certificate")
	witness.points.clear(); witness.accepted_call = 0
	var blocked: Dictionary = Probe.resume_choice(from,preferred,witness.certify)
	_check(not blocked.ok and blocked.attempts == 8 and witness.points.size() == 8,"all eight blocked directions refuse without blind movement")
	for point: Vector3 in witness.points:
		_check(point.is_finite() and point.y == from.y and absf(point.distance_to(from)-0.35) < 0.000001,"every finite local heading keeps the bounded horizontal radius")
	_check(witness.points[0].distance_to(from+Vector3(0,0,-0.35)) < 0.000001,"preferred original-spawn heading stays first")
	var first_order: Array[Vector3] = witness.points.duplicate()
	witness.points.clear(); Probe.resume_choice(from,preferred,witness.certify)
	_check(witness.points == first_order,"same inputs retain exact finite choice order without RNG")
	witness.points.clear(); witness.accepted_call = 1
	var forward: Dictionary = Probe.resume_choice(from,preferred,witness.certify)
	_check(forward.ok and forward.attempts == 1 and witness.points.size() == 1,"first clear direction needs no unnecessary alternatives")
	witness.points.clear(); witness.accepted_call = 0
	_check(not Probe.resume_choice(from,preferred,witness.certify).ok,"fresh blocked certificates cannot reuse a previous successful selection")
	witness.points.clear()
	_check(not Probe.resume_choice(Vector3.INF,preferred,witness.certify).ok and witness.points.is_empty(),"invalid origin makes no certificate query")
	_check(not Probe.resume_choice(from,from,witness.certify).ok and witness.points.is_empty(),"degenerate desired heading makes no blind motion")
	completed_groups += 1

'''
newtest=edit(test,'func _run() -> void:',testaddition+'func _run() -> void:')
newtest=edit(newtest,'_valid_checks(); _wake_checks(); _frame_checks(); _completion_checks()','_valid_checks(); _wake_checks(); _frame_checks(); _completion_checks(); _resume_checks()')
newtest=edit(newtest,'completed_groups == 4,"all four contract groups reached their actual tails"','completed_groups == 5,"all five contract groups reached their actual tails"')
newtest=edit(newtest,'completed_groups,"/4 groups; no rendered acceptance)"','completed_groups,"/5 groups; no rendered acceptance)"')
line=b'\trow["posed_ground"] = preload("res://tests/posed_ground_diagnostic.gd").measure(game.actors.dave.get_node("Art"))\n'
ground=new.replace(b'\tproof.frames.append(row); captures.append(LABELS[index])\n',line+b'\tproof.frames.append(row); captures.append(LABELS[index])\n')
for ref,data,base in [(probe_ref,new,old),(contract_ref,newtest,test)]:put('candidate/'+ref,data);put('original/'+ref,base)
put('ground-wrapper/dave_walkthrough_probe.gd',ground)
failed=R/'.build/full-port/dave-sleep-validation/web-v1/browser-evidence'
evidence={p.relative_to(R).as_posix():sha(p.read_bytes()) for p in sorted(failed.iterdir()) if p.is_file()}
assert evidence and any('browser-report.json' in p for p in evidence)
result={'schema':1,'scope':'test-only final movement successor; original source/art/physics unchanged','old':{probe_ref:sha(old),contract_ref:sha(test)},'candidate':{probe_ref:sha(new),contract_ref:sha(newtest)},'groundWrapper':sha(ground),'failedWebV1':evidence,'engineRun':False,'nativeArtEvidenceUnchanged':True,'newWebExecutionPending':True}
put('MANIFEST.json',(json.dumps(result,indent=2)+'\n').encode())
put('EDITS.json',(json.dumps({'probe':[{'before':'static func report_errors(row: Dictionary) -> Array[String]:','after':addition+'static func report_errors(row: Dictionary) -> Array[String]:'},{'before':before,'after':after}],'contractAddition':testaddition},indent=2)+'\n').encode())
print('DAVE RESUME DRIVER PREPARE: PASS; only two test files plus unchanged passive line; failed originals pinned')
