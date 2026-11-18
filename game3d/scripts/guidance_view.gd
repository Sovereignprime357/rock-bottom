class_name RockBottomGuidanceView
extends RefCounted
## Detached, read-only views of existing authorities. Source pixels; no gameplay clock.
const Content = preload("res://scripts/content_catalog.gd")
const Memory = preload("res://scripts/memory_loop.gd")
const QUEST_ORDER := ["intro_remember","intro_tony","intro_smoke","first_rock","copper_sings","finisher","conductor","priest_mercy","fallen_king","pigeon_crown","stripe_package","barb_crossword","fallen_priest","scrap_dog","office_space","paper_empire","regional_office","all_business","hostile_correspondence","blue_weather","cart_appeal","copper_mass","royal_static","one_cracklord"]
const REWARDS := {
	"intro_remember":"+1 cred","intro_tony":"+1 cred","intro_smoke":"+2 cred","pigeon_crown":"the crown (cursed hat)",
	"stripe_package":"$40 + 3 cred OR a brick. depends.","barb_crossword":"+ 1 clean packet","fallen_king":"the corner",
	"office_space":"one office key","paper_empire":"one bent sign · zoning error entered","regional_office":"a larger administrative problem",
	"all_business":"all eleven forms agree with themselves","hostile_correspondence":"one hostile frequency",
	"blue_weather":"$24 + 18 cred · one bent seal","cart_appeal":"$30 + 22 cred · one longer receipt","copper_mass":"$36 + 26 cred · b flat entered",
	"royal_static":"the throne ditch answers","one_cracklord":"$60 + 40 cred · one folding chair"}
const ACTIVITIES := [
	["score · smoke · sleep · cook","dealer corner -> milk crate"],["strip · sell · pawn · equip junk","abandoned building · scrap yard · pawn"],
	["fight · dodge · cart-roadkill","alleys · projects · old school"],["dumpster dive · kick cans · break bottles","everywhere with poor supervision"],
	["panhandle · tacos · laundry · karaoke","marketplace · food truck · laundromat"],["phone calls · prophecies · secrets","scrap phone · possum · pigeon"],
	["faction work · hideouts · bus routes","street · scrap · spiritual"],["benches · night cash · train waiting","park · train yard"],
	["office upgrades · district claims · work orders","the lot · far east"],["curb corrections · rival courts · daily pretenders","four kingdoms made of municipal leftovers"]]
const CLAN_FLAGS := {"blue_tarp":"blueTarpCleared","cart_cavalry":"cartKeepCleared","copper_choir":"copperChoirCleared","throne":"throneDitchCleared"}
const CLAN_COLORS := {"blue_tarp":"#7890a0","cart_cavalry":"#d4c896","copper_choir":"#d06030","throne":"#e8c040"}
var _refs: Dictionary = {}
var _static: Array = []
var _world: Dictionary = {}
var _targets: Dictionary = {}
var _claims: Array = []
var _upgrades: Array = []
var _clans: Array = []
var _stops: Dictionary = {}
var _venues: Array = []
var _people: Dictionary = {}
var _people_count: int = 0
var _tier_labels: Dictionary = {}

func _init(state: RefCounted,progression: Object,memory: Object,office: Object,kingdom: Object,campaign: Object) -> void:
	for pair: Array in [["state",state],["progression",progression],["memory",memory],["office",office],["kingdom",kingdom],["campaign",campaign]]:
		_refs[pair[0]] = weakref(pair[1]) if pair[1] != null else null
	if state == null: return
	_world = state.content.get("world",{}).duplicate(true)
	_targets = Content.definition("src/systems/campaigns.js","QUEST_TARGETS",{})
	_claims = Content.definition("src/systems/campaigns.js","CLAIM_SITES",[])
	_upgrades = Content.definition("src/systems/campaigns.js","OFFICE_UPGRADE_DEFS",[])
	_clans = Content.definition("src/systems/campaigns.js","KINGDOM_CLAN_LIST",[])
	_stops = Content.definition("src/systems/progression_routes.js","ROUTE_STOP_BY_ID",{})
	_venues = Content.definition("src/systems/recognition.js","REGULAR_VENUES",[])
	_people = Content.definition("src/data/catalogs.js","VENDOR_INDEX_META",{})
	_people_count = Content.definition("src/data/catalogs.js","VENDOR_FLOATER_IDS",[]).size()
	_tier_labels = Content.definition("src/systems/factions.js","FACTION_TIER_LABELS",{})
	_build_static()

func _owner(key: String) -> Object:
	var ref: WeakRef = _refs.get(key)
	return ref.get_ref() if ref != null else null
func ready() -> bool:
	for key: String in ["state","progression","memory","office","kingdom","campaign"]:
		if _owner(key) == null: return false
	return true
func _quest_keys(quests: Dictionary) -> Array:
	var keys: Array = []
	for key: String in QUEST_ORDER:
		if quests.has(key): keys.append(key)
	for key: String in quests:
		if not keys.has(key): keys.append(key)
	return keys
func primary_objective() -> Dictionary:
	if not ready(): return {}
	var host: Object = _owner("state"); var p: Dictionary = host.p; var s: Dictionary = host.s
	var qs: Dictionary = s.get("quests",{}); var flags: Dictionary = s.get("flags",{})
	if not flags.get("introDone",false):
		if qs.has("intro_remember") and not qs.intro_remember.get("done",false):
			var point := Vector2(1180,870)
			for pile: Dictionary in host.cash_piles:
				if pile.get("intro",false) and not pile.get("collected",false): point = Vector2(pile.x,pile.y); break
			return {"kind":"intro","text":"find $10 on the block. $%s/10" % str(mini(10,int(s.counters.get("introCashEarned",0)))),"x":point.x,"y":point.y}
		if (qs.has("intro_tony") and not qs.intro_tony.get("done",false)) or float(p.get("rocks",0))+float(p.get("soapRocks",0)) <= 0:
			return {"kind":"intro","text":"buy a rock from tony. talking did not count." if qs.get("intro_tony",{}).get("done",false) else "bother the man at the corner.","x":1634,"y":886}
		return {"kind":"intro","text":"take the rock back to the milk crate.","x":1064,"y":882}
	var office: Dictionary = _owner("office").office_objective()
	if (s.office.get("claimJob") is Dictionary or s.office.get("workJob") is Dictionary) and not office.is_empty(): return office.duplicate(true)
	var kingdom: Dictionary = _owner("kingdom").objective()
	if not kingdom.is_empty(): return kingdom.duplicate(true)
	if float(p.get("rocks",0))+float(p.get("soapRocks",0)) > 0 and float(p.rockedT) <= 0 and float(p.shakes) >= 50:
		var spot: Dictionary = _owner("memory").bad_idea_spot(host.player_center())
		return {"kind":"loop","text":"smoke a rock at "+str(spot.feedName)+".","x":spot.x,"y":spot.y}
	if not office.is_empty(): return office.duplicate(true)
	var stop: Dictionary = _owner("progression").current_stop()
	if not stop.is_empty(): return {"kind":"route","text":"route %d · %d/3 · %s" % [s.blockRoute.serial,int(s.blockRoute.cursor)+1,stop.task],"x":stop.x,"y":stop.y}
	for id: String in _quest_keys(qs):
		var quest: Dictionary = qs[id]
		if quest.get("done",false) or quest.get("available") == false or quest.get("intro",false): continue
		if id == "pigeon_crown" and s.get("crownPickup") is Dictionary and not s.crownPickup.get("collected",false):
			return {"kind":"quest","text":quest.flav,"x":s.crownPickup.x,"y":s.crownPickup.y}
		if _targets.has(id):
			var target: Dictionary = _targets[id].duplicate(true); target.kind = "quest"; return target
	var center: Vector2 = host.player_center()
	return {"kind":"idle","text":"walk until the neighborhood assigns something.","x":center.x,"y":center.y}

static func source_round(value: float) -> int: return int(floor(value+0.5))
static func objective_direction(dx: float,dy: float) -> String:
	if absf(dx) < 24 and absf(dy) < 24: return "HERE"
	var sector: float = atan2(dy,dx)/(PI/4.0)
	var half: float = float(source_round(sector*2.0))*0.5
	# Approved presentation-only libm compatibility: stabilize exact bisectors.
	if absf(sector-half) <= 0.000000000001: sector = half
	var octant: int = source_round(sector)
	return ["→","↘","↓","↙","←","↖","↑","↗","→"][posmod(octant+8,8)]
func objective_view(camera_yaw: float = 0.0) -> Dictionary:
	var objective: Dictionary = primary_objective()
	if objective.is_empty(): return {}
	var center: Vector2 = _owner("state").player_center()
	var dx: float = float(objective.x)-center.x; var dy: float = float(objective.y)-center.y
	var distance: float = sqrt(dx*dx+dy*dy); var here: bool = distance < 28.0
	objective["distance"] = distance; objective["paces"] = maxi(1,int(ceil(distance/10.0))); objective["here"] = here
	objective["direction"] = objective_direction(dx,dy)
	objective["bearing"] = wrapf(atan2(dx,-dy)+(camera_yaw if is_finite(camera_yaw) else 0.0),-PI,PI)
	objective["hud_text"] = "BAD IDEA · "+str(objective.text)+" · "+("HERE" if here else "%d paces %s" % [objective.paces,objective.direction])
	return objective

func _row(title: String,text: String = "") -> Dictionary: return {"title":title,"text":text}
func _section(title: String,rows: Array) -> Dictionary: return {"title":title,"rows":rows}
func _num(value: Variant) -> String:
	return str(int(value)) if (value is int or value is float) and float(value) == floor(float(value)) else str(value)
func journal() -> Dictionary:
	if not ready(): return {}
	var host: Object = _owner("state"); var s: Dictionary = host.s; var p: Dictionary = host.p
	var sections: Array = []; var now: Dictionary = primary_objective()
	sections.append(_section("WHAT TO PRESS",[_row("move / run","wasd or arrows / shift"),_row("look / hit / bother","mouse / left mouse or space / e"),_row("pockets / bad ideas","i / q"),_row("squint wrong / feed / mute","f / p / m")]))
	sections.append(_section("NOW",[_row(str(now.get("text","")),"the neighborhood has selected one thing.")]))
	var route: Variant = s.get("blockRoute"); var route_rows: Array = []; var route_title: String = "BLOCK ROUTE "
	if _owner("progression").valid_route(route):
		route_title += "· %d" % route.serial
		for index: int in range(route.stops.size()):
			var stop: Dictionary = _stops.get(route.stops[index],{})
			route_rows.append(_row(("✓" if index < int(route.cursor) else "·")+" %d. %s" % [index+1,stop.get("task","")],str(stop.get("zone",""))+(" · NOW" if index == int(route.cursor) else "")))
	else: route_rows.append(_row("","finish the first loop. the clipboard is under a brick."))
	sections.append(_section(route_title+" · FILED %d" % p.lifetime.get("routesCompleted",0),route_rows))
	sections.append(_section("THE OFFICE",_office_rows(s,p)))
	sections.append(_section("CURB WAR",_kingdom_rows(s)))
	var hustles: Array = []
	for job: Dictionary in s.get("hustles",[]):
		var rewards: Array[String] = []
		# Source authored reward insertion order; JSON object sorting is not display order.
		for key: String in ["cash","cred","brain"]:
			if job.get("reward",{}).has(key): rewards.append("+%s %s" % [_num(job.reward[key]),key])
		hustles.append(_row(("✓ " if job.get("done",false) else "· ")+str(job.desc)+" "+_owner("progression").hustle_progress(job),"reward: "+" · ".join(rewards)))
	if hustles.is_empty(): hustles.append(_row("","no hustles today."))
	sections.append(_section("TODAY'S HUSTLES · DAY %d" % s.day,hustles))
	var active: Array = []; var latent: Array = []; var done: Array = []
	for id: String in _quest_keys(s.quests):
		var q: Dictionary = s.quests[id]
		if not s.flags.get("introDone",false) and not q.get("intro",false): continue
		var row: Dictionary = _row(("✓ " if q.get("done",false) else "· ")+str(q.get("title","")),str(q.get("flav",""))+("" if q.get("done",false) else "\nreward: "+str(REWARDS.get(id,"—"))))
		row["id"] = id; row["done"] = q.get("done",false)
		if q.get("done",false): done.append(row)
		elif q.get("available") == false: latent.append(row)
		elif not q.has("available") or q.available == true: active.append(row)
	sections.append(_section("QUESTS · ACTIVE · %d" % active.size(),active if not active.is_empty() else [_row("","none active.")]))
	if not latent.is_empty(): sections.append(_section("QUESTS · AVAILABLE · %d" % latent.size(),latent))
	if not done.is_empty(): sections.append(_section("QUESTS · DONE · %d" % done.size(),done))
	var faction_rows: Array = []
	for key: String in ["street","scrap","spiritual"]:
		var value: int = int(p.faction.get(key,0)); var tier: String = host.faction_tier(value)
		var row: Dictionary = _row(key.to_upper(),str(_tier_labels.get(tier,tier))+" · "+("+" if value >= 0 else "")+str(value))
		var percent: float = clampf(float(value)+50.0,0.0,100.0)
		row["tier"] = tier; row["value"] = value; row["bar_left"] = percent if value < 0 else 50.0; row["bar_width"] = absf(percent-50.0)
		row["color"] = "#7fa055" if tier in ["liked","loved"] else "#a0554a" if tier == "hated" else "#776"
		faction_rows.append(row)
	faction_rows.append(_row("","hated · neutral · liked · loved")); sections.append(_section("FACTIONS",faction_rows))
	var regular_rows: Array = [_row("","nothing here pays. the neighborhood is keeping count.\nthe block concedes nothing. the block is already yours.")]
	for venue: Dictionary in _venues:
		var counters: Dictionary = s.get("recognition",{}).get(venue.id,{})
		var verbs: Array[String] = []
		for action: String in Memory.VERBS:
			if int(counters.get(action,0)) > 0: verbs.append(action.replace("_"," ")+" "+_num(counters[action]))
		var ledger: String = _owner("memory").ledger_line(venue.id)
		regular_rows.append(_row(str(venue.label)+" "+Memory.tier(counters).to_upper()+" · %d REMEMBERED" % Memory.total(counters),("nothing entered yet." if verbs.is_empty() else " · ".join(verbs))+("\n"+ledger if not ledger.is_empty() else "")))
	sections.append(_section("THE REGULAR",regular_rows))
	var activities: Array = []
	for pair: Array in ACTIVITIES: activities.append(_row(pair[0],pair[1]))
	sections.append(_section("WAYS TO WASTE TUESDAY",activities))
	var people_rows: Array = []; var met: Array = s.get("metVendors",[])
	for id: String in met:
		if not _people.has(id): continue
		var name: String = id.to_upper()
		# Deliberate repair: source renderQuests references an undefined bare `npcs`.
		for actor: Dictionary in host.npcs:
			if actor.get("id") == id: name = str(actor.get("name",name)); break
		people_rows.append(_row(name,str(_people[id].zone)+"\n"+str(_people[id].tag)))
	if met.is_empty(): people_rows.append(_row("","no one yet. walk."))
	sections.append(_section("PEOPLE YOU'VE MET · %d/%d" % [met.size(),_people_count],people_rows))
	return {"sections":sections,"close":"[ q / esc ] close"}

func _office_rows(s: Dictionary,p: Dictionary) -> Array:
	var office: Dictionary = s.get("office",{}); var claims: Array = _owner("campaign").claimed_ids()
	if not office.get("owned",false):
		return [_row("THE LEASING GUY HAS A KEY" if s.quests.get("office_space",{}).get("available") == true else "LOCKED · FILE 3 BLOCK ROUTES","routes %d/3 · the lot · $40 + 1 pure copper" % p.lifetime.get("routesCompleted",0))]
	var upgrades: int = 0
	for definition: Dictionary in _upgrades:
		if office.get("upgrades",{}).get(definition.id,false): upgrades += 1
	var active: String = "none accepted"
	for pair: Array in [["claimJob","claim · "],["workJob","order "]]:
		if not office.get(pair[0]) is Dictionary: continue
		var job: Dictionary = office[pair[0]]; var name: String = ""
		for site: Dictionary in _claims:
			if site.id == job.id: name = str(site.name).to_lower(); break
		active = str(pair[1])+(_num(job.serial)+" · " if pair[0] == "workJob" else "")+name+" · "+str(job.stage); break
	var districts: Array[String] = []
	for site: Dictionary in _claims: districts.append(("✓ " if s.get("districtClaims",{}).get(site.id,false) else "· ")+str(site.name).to_lower())
	var today: int = int(office.get("workToday",0)) if int(office.get("workDay",0)) == int(s.day) else 0
	return [_row("OWNED · %d/%d DISTRICTS · %d/%d UPGRADES" % [claims.size(),_claims.size(),upgrades,_upgrades.size()],"active: %s\norders: %d/%d today · %d lifetime" % [active,today,mini(3,1+int(floor(float(claims.size())/4.0))),office.get("jobsCompleted",0)]),_row(""," · ".join(districts))]
func _kingdom_rows(s: Dictionary) -> Array:
	var k: Dictionary = s.get("kingdom",{}); var stage: String = str(k.get("stage","locked")); var claims: Array = _owner("campaign").claimed_ids()
	if stage == "locked": return [_row("LOCKED · LOCAL THRONE UNSETTLED","%s fallen king · %s office · %s claims %d/4" % ["✓" if s.quests.get("fallen_king",{}).get("done",false) else "·","✓" if s.office.get("owned",false) else "·","✓" if claims.size() >= 4 else "·",mini(4,claims.size())])]
	var seals: int = 0
	for id: String in k.get("defeats",[]):
		if id != "curb_emperor": seals += 1
	var clan_stage: bool = false
	for clan: Dictionary in _clans:
		if stage == clan.get("marksStage") or stage == clan.get("bossStage"): clan_stage = true; break
	var bits: int = 0
	for index: int in range(3):
		if int(k.get("marks",0)) & (1 << index): bits += 1
	var cleared: Array[String] = []
	for pair: Array in [["blueTarpCleared","blue tarp court"],["cartKeepCleared","cart cavalry keep"],["copperChoirCleared","copper choir yard"],["throneDitchCleared","throne ditch"]]: cleared.append(("✓" if s.flags.get(pair[0],false) else "·")+" "+str(pair[1]))
	return [_row("ONE CRACKLORD · CHAIR OCCUPIED" if stage == "complete" else "ACTIVE · "+stage.replace("_"," ").to_upper(),"seals %d/3 · " % seals+("corrections %d/3 · " % bits if clan_stage else "")+"pretenders %d" % k.get("pretendersDefeated",0)),_row(""," · ".join(cleared))]
func journal_text() -> String:
	var view: Dictionary = journal()
	if view.is_empty(): return ""
	var lines: Array[String] = []
	for section: Dictionary in view.sections:
		lines.append(str(section.title))
		for row: Dictionary in section.rows:
			if not str(row.title).is_empty(): lines.append(str(row.title))
			if not str(row.text).is_empty(): lines.append(str(row.text))
		lines.append("")
	lines.append(str(view.close)); return "\n".join(lines)

func _command(op: String,color: String,values: Array,width: float = 1.0) -> Dictionary:
	return {"op":op,"color":color,"values":values,"width":width}
func _build_static() -> void:
	_static.clear()
	if _world.is_empty(): return
	var sx: float = 120.0/float(_world.bounds.w); var sy: float = 96.0/float(_world.bounds.h)
	_static.append(_command("fill","#000",[0,0,120,96]))
	for z: Dictionary in _world.zones: _static.append(_command("fill",z.color,[z.x*sx,z.y*sy,z.w*sx,z.h*sy]))
	for pair: Array in [["roadSegments","#38352e"],["landmarkFacades","#171510"]]:
		for row: Dictionary in _world.get(pair[0],[]): _static.append(_command("fill",pair[1],[row.x*sx,row.y*sy,maxf(1.0,row.w*sx),maxf(1.0,row.h*sy)]))
	for row: Dictionary in _world.get("railLines",[]): _static.append(_command("line","#6b6253",[row.x1*sx,row.y1*sy,row.x2*sx,row.y2*sy]))
func map_static() -> Array: return _static.duplicate(true)
func map_dynamic() -> Dictionary:
	if not ready() or _world.is_empty(): return {}
	var host: Object = _owner("state"); var s: Dictionary = host.s; var p: Dictionary = host.p
	var sx: float = 120.0/float(_world.bounds.w); var sy: float = 96.0/float(_world.bounds.h); var commands: Array = []
	for id: String in _owner("campaign").claimed_ids():
		for z: Dictionary in _world.zones:
			if z.id == id: commands.append(_command("stroke","#e8c040",[z.x*sx+0.5,z.y*sy+0.5,maxf(1.0,z.w*sx-1.0),maxf(1.0,z.h*sy-1.0)])); break
	for z: Dictionary in _world.zones:
		if not z.has("clan"): continue
		var cleared: bool = s.flags.get(CLAN_FLAGS.get(z.clan,""),false)
		commands.append(_command("stroke",CLAN_COLORS.get(z.clan,"#8a3a3a") if cleared else "#8a3a3a",[z.x*sx+0.5,z.y*sy+0.5,maxf(1.0,z.w*sx-1.0),maxf(1.0,z.h*sy-1.0)],2.0 if cleared else 1.0))
	if s.office.get("owned",false) or s.flags.get("theLotEntered",false): commands.append(_command("fill","#e8c040" if s.office.get("owned",false) else "#776",[4920*sx-2,3210*sy-2,4,4]))
	for actor: Dictionary in host.npcs:
		if actor.get("dead",false) or actor.get("departed",false): continue
		var color: String = "#d06030" if actor.get("id") == "tony" else "#5aa0ff" if actor.get("isCop",false) else "#d04040" if actor.get("hostile",false) or actor.get("aggro",false) else "#88aa66"
		commands.append(_command("fill",color,[actor.x*sx-1,actor.y*sy-1,2,2]))
	var target: Dictionary = primary_objective()
	if not target.is_empty(): commands.append(_command("stroke","#e8c040",[source_round(target.x*sx)-2,source_round(target.y*sy)-2,5,5]))
	commands.append(_command("fill","#e8c040",[p.x*sx-1,p.y*sy-1,3,3]))
	return {"commands":commands,"player":[p.x*sx,p.y*sy]}
