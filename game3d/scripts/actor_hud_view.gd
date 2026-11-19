class_name RockBottomActorHudView
extends RefCounted
## Detached source display facts only. Never normalizes or ticks a gameplay owner.
const Content = preload("res://scripts/content_catalog.gd")
const CACHE_LIMIT := 128
var _host_ref: WeakRef
var _player_epoch: Dictionary = {}
var _state_epoch: Dictionary = {}
var _names: Dictionary = {}
var _name_order: Array[String] = []
var _vendor_ids: Array = []
var _epoch_serial: int = 0
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null
func _init(owner: RefCounted) -> void:
	_host_ref = weakref(owner)
	_vendor_ids = Content.definition("src/data/catalogs.js","VENDOR_FLOATER_IDS",[])
static func number(value: Variant,fallback: float = 0) -> float:
	return float(value) if (value is int or value is float) and is_finite(float(value)) else fallback
static func truthy(value: Variant) -> bool:
	if value == null: return false
	if value is bool: return value
	if value is int or value is float: return float(value) != 0 and not is_nan(float(value))
	if value is String: return not value.is_empty()
	return true
static func source_text(value: Variant) -> String:
	if value == null: return "null"
	if value is float and is_finite(value) and floor(value) == value: return "%d"%int(value)
	return str(value)
static func wrap_name(name: String) -> Array[String]:
	var lines: Array[String] = [""]
	for word: String in name.split(" ",true):
		var index: int = lines.size()-1; var joined: String = (lines[index]+" "+word).strip_edges()
		if joined.length() > 17 and not lines[index].is_empty() and lines.size() < 2: lines.append(word)
		else: lines[index] = joined
	return lines
func _name(name: String) -> Array[String]:
	if _names.has(name):
		_name_order.erase(name); _name_order.append(name)
		var cached: Array[String] = []; cached.assign(_names[name]); return cached
	var lines: Array[String] = wrap_name(name)
	if _names.size() >= CACHE_LIMIT: _names.erase(_name_order.pop_front())
	_names[name] = lines.duplicate(); _name_order.append(name); return lines
static func _mark(kind: String,text: String,x: float,y: float,size: int,color: String,bold: bool = false,alpha: float = 1.0) -> Dictionary:
	return {"kind":kind,"text":text,"x":x,"y":y,"font_px":size,"color":color,"bold":bold,"alpha":alpha}
static func actor_facts(actor: Dictionary,player: Dictionary,met: Array,vendor_ids: Array,visual_ms: float) -> Dictionary:
	var x: float = number(actor.get("x")); var y: float = number(actor.get("y")); var w: float = number(actor.get("w")); var h: float = number(actor.get("h"))
	var dx: float = number(player.get("x"))+number(player.get("w"))*.5-x-w*.5
	var dy: float = number(player.get("y"))+number(player.get("h"))*.5-y-h*.5
	var hostile: bool = truthy(actor.get("hostile")); var aggro: bool = truthy(actor.get("aggro"))
	var shown: bool = truthy(actor.get("vendor")) or hostile or aggro or dx*dx+dy*dy < 260.0*260.0
	var id: String = str(actor.get("id","")); var name: String = source_text(actor.get("name")) if truthy(actor.get("name")) else ""
	var hp: float = number(actor.get("hp")); var maximum: float = number(actor.get("maxHp"))
	var ratio: float = hp/maximum if maximum != 0 else 0.0
	var health: Dictionary = {}
	if truthy(actor.get("showHp")) and hp < maximum:
		health = {"hp":hp,"max_hp":maximum,"ratio":ratio,"color":"#a8c030" if ratio > .6 else "#e8c040" if ratio > .3 else "#d04040"}
	var markers: Array[Dictionary] = []
	if truthy(actor.get("asleep")):
		var bob: float = sin(visual_ms/600.0)*2.0
		markers.append(_mark("sleep","z",w*.5,bob,10,"#d4c896")); markers.append(_mark("sleep","z",w*.5+4,-6-bob,10,"#d4c896"))
	if aggro: markers.append(_mark("aggro","!",w*.5+2,8+sin(visual_ms/180.0)*2,14,"#e8c040",true))
	var windup: Dictionary = {}; var cooldown: Dictionary = {}
	if actor.get("chargeState") == "windup":
		var pulse: float = (sin(visual_ms/60.0)+1)*.5
		windup = {"color":"#d04040","alpha":.18+pulse*.22}
		markers.append(_mark("windup","!",0,-12-pulse*4,18,"#fff080",true))
	if actor.get("chargeState") == "cooldown": cooldown = {"color":"#d0c0a0","alpha":.10+(sin(visual_ms/120.0)+1)*.05}
	if truthy(actor.get("aimingThrow")): markers.append(_mark("aim","*",0,-10,10,"#fff080",true))
	if number(actor.get("radioVisualT")) > 0: markers.append(_mark("radio","*",8,-6+sin(visual_ms/100.0),11,"#88c0ff",true))
	if number(actor.get("grabFreezeT")) > 0: markers.append(_mark("grab","-<",0,-12,12,"#d488d4",true))
	var floater: Variant = actor.get("hasFloater")
	if (id in vendor_ids or truthy(floater)) and id not in met and not aggro and not hostile:
		var symbol: String = source_text(floater) if truthy(floater) else "?"
		markers.append(_mark("floater",symbol,0,-16+sin(visual_ms/360.0+x*.013)*2,22 if floater == "?" and truthy(actor.get("isBusDriver")) else 16,"#e8c040",true,.78))
	var chatter: String = source_text(actor.chatter) if number(actor.get("chatterT")) > 0 and truthy(actor.get("chatter")) else ""
	return {"id":id,"name":name,"show_name":shown,"name_lines":wrap_name(name) if shown else [],"name_color":"#d04040" if hostile or aggro else "#d4c896","hp":health,
		"markers":markers,"windup":windup,"cooldown":cooldown,"chatter":chatter,"distance_squared":dx*dx+dy*dy,"source_bottom":y+h,"source_center":Vector2(x+w*.5,y+h*.5),"source_width":w,
		"priority":0 if not windup.is_empty() or truthy(actor.get("aimingThrow")) or number(actor.get("grabFreezeT")) > 0 else 1 if hostile or aggro else 2 if not chatter.is_empty() else 3}
static func combat_facts(player: Dictionary,state: Dictionary,visual_ms: float) -> Dictionary:
	if state.get("mode") == "title": return {}
	var hp: float = number(player.get("hp")); var boss: Dictionary = {}
	var raw: Variant = state.get("bossNPC")
	if truthy(state.get("bossActive")) and raw is Dictionary and not raw.is_empty() and not truthy(raw.get("dead")):
		var value: float = number(raw.get("hp")); var maximum: float = number(raw.get("maxHp"))
		var name: String = str(raw.get("name","")) if state.get("bossKind") == "kingdom" else "TRE BAG TONY"
		boss = {"text":name+" · "+source_text(maxf(0,ceil(value)))+"/"+source_text(maximum),"hp":value,"max_hp":maximum,"ratio":value/maximum if maximum != 0 else 0.0}
	var combo: Dictionary = {}
	if number(state.get("combo")) >= 2:
		var count: float = number(state.combo)
		combo = {"text":source_text(count)+"x","label":"combo","font_px":16+count*2,"alpha":minf(1,number(state.get("comboT"))/1000.0)}
	return {"flash":minf(1,number(state.get("flash"))) if number(state.get("flash")) > 0 else 0.0,"flash_color":str(state.get("flashColor","#fff")),
		"high":.08+sin(visual_ms/120.0)*.04 if number(player.get("rockedT")) > 0 else 0.0,"crash":.18 if number(player.get("crashT")) > 0 else 0.0,
		"stun":.10+(sin(visual_ms/80.0)+1)*.05 if number(player.get("stunT")) > 0 else 0.0,"stun_text":"GRABBED" if number(player.get("stunT")) > 0 else "",
		"slow":.08+sin(visual_ms/220.0)*.05 if number(player.get("slowT")) > 0 else 0.0,"low_hp":.08+sin(visual_ms/200.0)*.05 if hp <= 30 else 0.0,
		"vignette":(1-hp/30)*.6+sin(visual_ms/300.0)*.1 if hp <= 30 else 0.0,"shakes":.08 if number(player.get("shakes")) >= 90 else 0.0,"boss":boss,"combo":combo}
func is_current() -> bool:
	return host != null and is_same(host.p,_player_epoch) and is_same(host.s,_state_epoch)
func snapshot(visual_ms: float) -> Dictionary:
	if host == null or not is_finite(visual_ms) or visual_ms < 0: return {}
	if not is_current(): _player_epoch = host.p; _state_epoch = host.s; _epoch_serial += 1
	var mode: String = str(host.s.get("mode","title")); var actors: Array[Dictionary] = []
	var time: float = number(host.s.get("dayTime")); var night: bool = time < .25 or time > .75
	var met: Array = host.s.get("metVendors",[]) if host.s.get("metVendors") is Array else []
	if mode != "title":
		for actor: Dictionary in host.npcs:
			if truthy(actor.get("dead")) or truthy(actor.get("departed")) or (night and (actor.get("id") in ["mom","pete"] or truthy(actor.get("daytimeOnly")))): continue
			var row: Dictionary = actor_facts(actor,host.p,met,_vendor_ids,visual_ms)
			if row.show_name: row.name_lines = _name(row.name)
			actors.append(row)
	return {"mode":mode,"actors":actors,"combat":combat_facts(host.p,host.s,visual_ms),"epoch":_epoch_serial}
func cache_size() -> int: return _names.size()
