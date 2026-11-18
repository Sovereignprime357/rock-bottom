class_name RockBottomIncidents
extends RefCounted
## Source scene incidents. Never NPCs, interaction targets, combatants or economies.
const MODULE := "src/systems/incidents.js"
const IDS: Array[String] = ["runaway_mattress","possum_inventory","laundromat_walkout","yuri_receipt","park_dry_committee","ticketed_luggage"]
var _host_ref: WeakRef
var _spatial_ref: WeakRef
var _comms_ref: WeakRef
var _path_ref: WeakRef
var _player_epoch: Dictionary = {}
var _state_epoch: Dictionary = {}
var definitions: Dictionary = {}
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null
func _init(owner: RefCounted,spatial: Object,communications: Object) -> void:
	_host_ref = weakref(owner)
	_spatial_ref = weakref(spatial) if spatial != null else null
	_comms_ref = weakref(communications) if communications != null else null
	definitions = owner.definition(MODULE,"INCIDENT_DEFS",{})
	_player_epoch = owner.p; _state_epoch = owner.s
func _dep(reference: WeakRef,method: StringName) -> Object:
	var value: Object = reference.get_ref() if reference != null else null
	return value if value != null and value.has_method(method) else null
func _bound() -> bool: return host != null and is_same(_player_epoch,host.p) and is_same(_state_epoch,host.s)
func ready() -> bool:
	if host == null or definitions.size() != 6 or _dep(_spatial_ref,&"move_body") == null: return false
	if _path_ref != null:
		var mapper: Object = _dep(_path_ref,&"map_mattress")
		if mapper == null or not mapper.has_method(&"ready") or not mapper.ready(): return false
	var comms: Object = _dep(_comms_ref,&"post")
	if comms == null or not comms.has_method(&"ready") or not comms.ready(): return false
	var ids: Array = host.definition(MODULE,"INCIDENT_IDS",[])
	if ids != IDS: return false
	for id: String in IDS:
		if not definitions.get(id) is Dictionary or definitions[id].get("beats",[]).size() != 4: return false
	return true
func bind_path_owner(mapper: Object) -> bool:
	if mapper == null or not mapper.has_method(&"ready") or not mapper.has_method(&"map_mattress") or not mapper.ready(): return false
	if host.s.get("incident") != null: return false
	_path_ref = weakref(mapper); return true
func _mapped_mattress(incident: Dictionary,point: Vector2) -> Dictionary:
	var mapper: Object = _dep(_path_ref,&"map_mattress")
	if mapper == null: return {"ok":false,"reason":"missing_path_owner"}
	var result: Variant = mapper.map_mattress(incident,point)
	if not result is Dictionary or result.get("ok") != true or not result.get("point") is Vector2 or not result.point.is_finite(): return {"ok":false,"reason":"invalid_path_point"}
	var delta: Vector2 = result.point-point
	if delta.length() > 100.001 or (absf(delta.x) > 0.001 if incident.road.axis == "h" else absf(delta.y) > 0.001): return {"ok":false,"reason":"invalid_lateral_offset"}
	return result
func reset_session(kind: String) -> bool:
	if kind not in ["fresh","restore"] or not ready(): return false
	if _bound(): return true
	_player_epoch = host.p; _state_epoch = host.s
	host.s.incident = null; host.s.incidentPaperT = 0.0; host.s.incidentWetT = 0.0
	if kind == "restore": host.s.incidentT = 35000.0+host.random_float()*20000.0
	host.emit_event("incident_changed",{"active":false})
	return true
func _toast(text: String,ms: int) -> void: host.emit_event("toast",{"text":text,"duration_ms":ms})
func _sound(id: String) -> void:
	if id == "traffic": host.random_float() # Pitch argument precedes the source audio-ready gate.
	host.emit_event("sound",{"id":id})
func _ensure_flags() -> void:
	if host.s.flags.get("incidentDay") != host.s.day:
		host.s.flags.incidentDay = host.s.day; host.s.flags.incidentMask = 0; host.s.flags.incidentsToday = 0
	for key: String in ["incidentMask","incidentsToday"]:
		if host.s.flags.get(key) == null: host.s.flags[key] = 0
	if host.s.flags.get("lastIncidentId") == null: host.s.flags.lastIncidentId = ""
func _npc(id: String) -> Dictionary:
	for actor: Dictionary in host.npcs:
		if actor.get("id") == id and not actor.get("dead",false): return actor
	return {}
func _combat_busy() -> bool:
	if host.s.get("bossActive",false) or host.s.get("brutusOlderActive",false): return true
	var cx: float = host.p.x+host.p.w*0.5; var cy: float = host.p.y+host.p.h*0.5
	for actor: Dictionary in host.npcs:
		if actor.get("dead",false) or not actor.get("aggro",false): continue
		var dx: float = actor.x+actor.w*0.5-cx; var dy: float = actor.y+actor.h*0.5-cy
		if sqrt(dx*dx+dy*dy) < 320.0: return true
	return false
func _script_busy() -> bool:
	for actor: Dictionary in host.npcs:
		if not actor.get("dead",false) and (actor.get("isDay3Visitor",false) or actor.get("id") == "bus_driver"): return true
	return false
func _required_valid(incident: Dictionary) -> bool:
	var definition: Dictionary = definitions.get(incident.get("id"),{})
	if definition.is_empty() or not definition.get("required"): return true
	var actor: Dictionary = _npc(definition.required)
	return not actor.is_empty() and not actor.get("aggro",false) and not actor.get("hostile",false)
func _current_zone() -> Dictionary:
	var cx: float = host.p.x+host.p.w*0.5; var cy: float = host.p.y+host.p.h*0.5
	var best: Dictionary = {}; var rank: float = -1.0
	for zone: Dictionary in host.content.world.zones:
		if cx < zone.x or cx > zone.x+zone.w or cy < zone.y or cy > zone.y+zone.h: continue
		var faction: String = zone.get("faction","neutral")
		var tier: float = 0.0 if faction == "neutral" else absf(float(host.p.faction.get(faction,0)))
		if tier > rank: best = zone; rank = tier
	return best
func _nearest_road() -> Dictionary:
	var roads: Array = host.content.world.roadSegments
	var best: Dictionary = roads[0]; var distance: float = INF
	var cx: float = host.p.x+host.p.w*0.5; var cy: float = host.p.y+host.p.h*0.5
	for road: Dictionary in roads:
		var dx: float = clampf(cx,road.x,road.x+road.w)-cx; var dy: float = clampf(cy,road.y,road.y+road.h)-cy
		var squared: float = dx*dx+dy*dy
		if squared < distance: distance = squared; best = road
	return best
func _start(id: String) -> bool:
	if not _bound() or not ready() or not definitions.has(id): return false
	var definition: Dictionary = definitions[id]
	var incident := {"id":id,"t":0.0,"beat":-1,"duration":definition.duration,"actors":[],"bumped":false}
	match id:
		"runaway_mattress":
			var road: Dictionary = _nearest_road(); var horizontal: bool = road.axis == "h"
			var center: float = host.p.x+host.p.w*0.5 if horizontal else host.p.y+host.p.h*0.5
			var lo: float = road.x if horizontal else road.y; var hi: float = road.x+road.w if horizontal else road.y+road.h
			var projected: float = clampf(center,lo+18,hi-18)
			var direction: int = 1 if hi-projected >= projected-lo else -1
			var start: float = clampf(projected-direction*380,lo+18,hi-18); var end: float = clampf(projected+direction*560,lo+18,hi-18)
			incident.road = road.duplicate(true); incident.dir = direction
			var x: float = start if horizontal else road.x+road.w*0.5; var y: float = road.y+road.h*0.5 if horizontal else start
			incident.actors = [{"kind":"mattress","x":x,"y":y,"sx":x,"sy":y,"ex":end if horizontal else x,"ey":y if horizontal else end}]
		"possum_inventory": incident.actors = [{"kind":"forklift","x":720.0,"y":1515.0}]
		"laundromat_walkout": incident.actors = [{"kind":"dryer","x":1540.0,"y":1190.0}]
		"yuri_receipt":
			var dog: Dictionary = _npc("brutus")
			incident.anchor = {"x":310.0,"y":220.0,"tx":dog.x+dog.w*0.5 if not dog.is_empty() else 570.0,"ty":dog.y+dog.h*0.5 if not dog.is_empty() else 150.0}
			if dog.is_empty(): incident.overrideBeat2 = "the wind wraps the leash post.\nthe post remains employed."
		"park_dry_committee": incident.anchor = {"x":2600.0,"y":1280.0}; incident.sprayAngle = -0.4
		"ticketed_luggage": incident.actors = [{"kind":"suitcase","x":360.0,"y":2985.0}]
	if id == "runaway_mattress" and _path_ref != null:
		var actor: Dictionary = incident.actors[0]; var mapped: Dictionary = _mapped_mattress(incident,Vector2(actor.x,actor.y))
		if not mapped.ok: return false
		actor.x = mapped.point.x; actor.y = mapped.point.y
	host.s.incident = incident; _ensure_flags()
	host.s.flags.incidentMask = int(host.s.flags.incidentMask)|(1<<IDS.find(id))
	host.s.flags.incidentsToday += 1; host.s.flags.lastIncidentId = id
	host.emit_event("save_requested")
	_comms_ref.get_ref().post(str(definition.beats[0][1]).split("\n")[0],"@local_eyewitness")
	host.emit_event("incident_changed",{"active":true,"id":id})
	return true
func _finish(interrupted: bool = false) -> bool:
	if not _bound() or host.s.get("incident") == null: return false
	host.s.incident = null
	host.s.incidentT = (45000.0 if interrupted else 70000.0)+host.random_float()*(20000.0 if interrupted else 40000.0)
	host.emit_event("incident_changed",{"active":false,"interrupted":interrupted}); return true
static func _segment_distance(px: float,py: float,x1: float,y1: float,x2: float,y2: float) -> float:
	var dx: float = x2-x1; var dy: float = y2-y1; var squared: float = dx*dx+dy*dy
	var ratio: float = clampf(((px-x1)*dx+(py-y1)*dy)/squared,0,1) if squared != 0 else 0.0
	var x: float = px-(x1+ratio*dx); var y: float = py-(y1+ratio*dy)
	return sqrt(x*x+y*y)
func _bump(actor: Dictionary) -> void:
	var bounds: Dictionary = host.content.world.bounds
	var intended := Vector2(clampf(host.p.x+signf(actor.ex-actor.sx)*14.0,0,bounds.w-host.p.w),clampf(host.p.y+signf(actor.ey-actor.sy)*14.0,0,bounds.h-host.p.h))
	var body := {"id":"player","x":host.p.x,"y":host.p.y,"w":host.p.w,"h":host.p.h}
	var origin := Vector2(body.x,body.y)
	var result: Variant = _spatial_ref.get_ref().move_body(body,intended)
	if result is Dictionary and result.get("position") is Vector2 and result.position.is_finite() and result.get("blocked") is bool and result.position.x >= 0 and result.position.y >= 0 and result.position.x+body.w <= bounds.w and result.position.y+body.h <= bounds.h and result.position.distance_to(origin) <= intended.distance_to(origin)+0.001:
		host.p.x = result.position.x; host.p.y = result.position.y
	else: host.emit_event("dependency_missing",{"system":"incidents","key":"mattress_motion"})
	_toast("the mattress has insurance.\nyou do not.",1800)
func _update_active(incident: Dictionary) -> void:
	var time: float = incident.t; var progress: float = minf(1.0,time/float(incident.duration)); var ease: float = progress*progress*(3-2*progress)
	var cx: float = host.p.x+host.p.w*0.5; var cy: float = host.p.y+host.p.h*0.5
	match incident.id:
		"runaway_mattress":
			var actor: Dictionary = incident.actors[0]
			actor.x = actor.sx+(actor.ex-actor.sx)*ease; actor.y = actor.sy+(actor.ey-actor.sy)*ease+sin(time/240.0)*3
			if _path_ref != null:
				var mapped: Dictionary = _mapped_mattress(incident,Vector2(actor.x,actor.y))
				if not mapped.ok: host.emit_event("dependency_missing",{"system":"incidents","key":"mattress_path"}); return
				actor.x = mapped.point.x; actor.y = mapped.point.y
			if not incident.bumped and time > 1800 and absf(actor.x-cx) < 25 and absf(actor.y-cy) < 25:
				incident.bumped = true; host.s.shake = maxf(float(host.s.get("shake",0)),5.0); _bump(actor)
		"possum_inventory":
			var actor: Dictionary = incident.actors[0]; var ratio: float = minf(1,time/24500.0)
			actor.x = 720+ratio*620; actor.y = 1515+sin(time/430.0)*5
		"laundromat_walkout":
			var actor: Dictionary = incident.actors[0]; var ratio: float = minf(1,time/24500.0)
			actor.x = 1540+ratio*360; actor.y = 1190+ratio*45+sin(time/170.0)*3
		"yuri_receipt":
			var anchor: Dictionary = incident.anchor
			if time > 5000 and _segment_distance(cx,cy,anchor.x,anchor.y,anchor.tx,anchor.ty) < 20: host.s.incidentPaperT = 4000.0
		"park_dry_committee":
			var anchor: Dictionary = incident.anchor; var dx: float = cx-anchor.x; var dy: float = cy-anchor.y
			incident.sprayAngle = atan2(dy,dx) if time > 12000 and time < 23000 else sin(time/900.0)*0.7-0.5
			if time > 12000 and time < 23000 and sqrt(dx*dx+dy*dy) < 175: host.s.incidentWetT = 4000.0
		"ticketed_luggage":
			var actor: Dictionary = incident.actors[0]
			actor.x = 360+(time/9000.0)*310 if time < 9000 else (670.0 if time < 14500 else 670+minf(1,(time-14500.0)/12500.0)*650)
			actor.y = 2985+sin(time/260.0)*3
			if absf(actor.x-cx) < 32 and absf(actor.y-cy) < 28: actor.y += 28
func tick_active(dt_ms: float,intro_active: bool,silence_active: bool) -> bool:
	if not _bound() or not ready() or not is_finite(dt_ms) or dt_ms <= 0 or dt_ms > 50: return false
	if host.s.mode != "playing" or float(host.s.get("hitPause",0)) > 0: return true
	var active: Variant = host.s.get("incident")
	if active != null and (not active is Dictionary or not definitions.has(active.get("id"))): return false
	if active is Dictionary and active.id == "runaway_mattress" and _path_ref != null:
		var time: float = float(active.t)+dt_ms; var progress: float = minf(1.0,time/float(active.duration)); var ease: float = progress*progress*(3-2*progress)
		var actor: Dictionary = active.actors[0]
		if not _mapped_mattress(active,Vector2(actor.sx+(actor.ex-actor.sx)*ease,actor.sy+(actor.ey-actor.sy)*ease+sin(time/240.0)*3)).ok: return false
	host.s.incidentPaperT = maxf(0,float(host.s.get("incidentPaperT",0))-dt_ms)
	host.s.incidentWetT = maxf(0,float(host.s.get("incidentWetT",0))-dt_ms)
	if active is Dictionary:
		if silence_active or _combat_busy() or _script_busy() or not _required_valid(active): _finish(true); return true
		var definition: Dictionary = definitions[active.id]
		active.t += dt_ms; _update_active(active)
		while int(active.beat)+1 < definition.beats.size() and active.t >= definition.beats[int(active.beat)+1][0]:
			active.beat += 1
			var text: String = active.get("overrideBeat2",definition.beats[active.beat][1]) if active.beat == 2 else definition.beats[active.beat][1]
			_toast(text,2600 if active.beat == definition.beats.size()-1 else 3200)
			if active.beat == 1 and definition.get("sfx"): _sound(definition.sfx)
		if active.t >= active.duration: _finish(false)
		return true
	if intro_active or silence_active or _combat_busy() or _script_busy(): return true
	_ensure_flags()
	if int(host.s.flags.incidentsToday) >= 3: return true
	var timer: Variant = host.s.get("incidentT")
	host.s.incidentT = (35000.0+host.random_float()*20000.0 if timer == null else float(timer))-dt_ms
	if host.s.incidentT > 0: return true
	var zone: Dictionary = _current_zone(); var choices: Array[String] = []; var specific: Array[String] = []
	for id: String in IDS:
		var definition: Dictionary = definitions[id]
		if int(host.s.flags.incidentMask)&(1<<IDS.find(id)): continue
		if definition.get("zone") and zone.get("id") != definition.zone: continue
		if definition.get("clearDay",false) and (host.s.weather != "clear" or host.s.dayTime < 0.25 or host.s.dayTime > 0.75): continue
		if not _required_valid({"id":id}): continue
		choices.append(id)
		if definition.get("zone"): specific.append(id)
	if not specific.is_empty(): choices = specific
	if choices.is_empty(): host.s.incidentT = 30000.0; return true
	var picked: String = choices[host.random_index(choices.size())]
	if choices.size() > 1 and picked == host.s.flags.lastIncidentId:
		for id: String in choices:
			if id != picked: picked = id; break
	return _start(picked)
func visual_snapshot() -> Dictionary:
	if not _bound(): return {"active":null,"paper_ms":0.0,"wet_ms":0.0}
	var active: Variant = host.s.get("incident")
	return {"active":active.duplicate(true) if active is Dictionary else null,"paper_ms":float(host.s.get("incidentPaperT",0)),"wet_ms":float(host.s.get("incidentWetT",0))}
