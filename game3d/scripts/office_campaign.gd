class_name RockBottomOfficeCampaign
extends RefCounted
## Office commands share the accepted Campaign foundation and the single GameState.
const Session = preload("res://scripts/action_session.gd")
const Campaign = preload("res://scripts/campaign_system.gd")
const MODULE := "src/systems/campaigns.js"
var _owner_ref: WeakRef
var _campaign_ref: WeakRef
var _progression_ref: WeakRef
var _travel_ref: WeakRef
var host: RefCounted:
	get: return _owner_ref.get_ref() if _owner_ref != null else null
var session: RefCounted
var _target: String = ""
var _view: String = ""
var _page: int = 0
var sites: Array = []
var upgrades: Array = []
var by_id: Dictionary = {}

func _init(owner: RefCounted,spatial: Object,campaign: Object,progression: Object,travel: Object) -> void:
	_owner_ref = weakref(owner)
	_campaign_ref = weakref(campaign) if campaign != null else null
	_progression_ref = weakref(progression) if progression != null else null
	_travel_ref = weakref(travel) if travel != null else null
	session = Session.new(owner,spatial)
	sites = owner.definition(MODULE,"CLAIM_SITES",[]); upgrades = owner.definition(MODULE,"OFFICE_UPGRADE_DEFS",[])
	for site: Dictionary in sites: by_id[site.id] = site
func _dep(reference: WeakRef,method: StringName) -> Object:
	var value: Object = reference.get_ref() if reference != null else null
	return value if value != null and value.has_method(method) else null
func ready() -> bool:
	return host != null and sites.size() == 11 and upgrades.size() == 6 and _dep(_campaign_ref,&"update_office_milestones") != null and _dep(_campaign_ref,&"maybe_unlock_kingdom") != null and _dep(_campaign_ref,&"sync_quests") != null and _dep(_progression_ref,&"roll_route") != null and _dep(_progression_ref,&"valid_route") != null and _dep(_travel_ref,&"open") != null
func supports(id: String) -> bool: return id in ["office","lease_guy","gutter_greg"]
func _fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
func _done() -> Dictionary: return {"ok":true,"closed":true}
func _toast(text: String,ms: int = 2200) -> void: host.emit_event("toast",{"text":text,"duration_ms":ms})
func _sound(id: String) -> void: host.emit_event("sound",{"id":id})
func _save() -> void: host.emit_event("save_requested")
func _feed(text: String) -> void: host.emit_event("feed",{"text":text,"author":"@crackheadcent"})
func _ensure() -> Dictionary:
	host.s.districtClaims = Campaign.normalize_claims(host.s.districtClaims)
	host.s.office = Campaign.normalize_office(host.s.office,host.s.districtClaims)
	return host.s.office
func _sync_day() -> void:
	if host.s.office.workDay != host.s.day: host.s.office.workDay = host.s.day; host.s.office.workToday = 0
func _claimed() -> Array[String]:
	var result: Array[String] = []
	for site: Dictionary in sites:
		if host.s.districtClaims.get(site.id,false) == true: result.append(site.id)
	return result
func _cap() -> int: return mini(3,1+int(floor(_claimed().size()/4.0)))
func _contract() -> bool: return host.s.office.get("claimJob") != null or host.s.office.get("workJob") != null
func _cost() -> int: return 20+5*_claimed().size()
func _upgrade_count() -> int:
	var count: int = 0
	for upgrade: Dictionary in upgrades:
		if host.s.office.upgrades.get(upgrade.id,false): count += 1
	return count
func _claim_reason(site: Dictionary) -> String:
	if site.is_empty(): return "not on the form."
	if host.s.districtClaims.get(site.id,false): return "already entered in pen."
	if site.faction != "neutral" and host.p.faction.get(site.faction,0) < 10: return str(site.faction)+" must be liked (+10)."
	return ""
func _reason(target: String) -> String:
	if not ready(): return "missing_dependency"
	if not supports(target): return "unknown_service"
	if host.s.mode not in ["playing","dialogue"]: return "wrong_mode"
	if host.s.get("bossKind","") == "kingdom": return "active_boss"
	var point: Vector2
	var reach: float = 60.0
	if target == "office":
		var door: Dictionary = host.definition(MODULE,"OFFICE_DOOR",{})
		point = Vector2(door.x+door.w*0.5,door.y+door.h*0.5); reach = 44.0
	else:
		var body: Dictionary = {}
		for actor: Dictionary in host.npcs:
			if actor.get("id") == target: body = actor; break
		if body.is_empty() or body.get("dead",false): return "missing_resident"
		point = Vector2(body.x+body.w*0.5,body.y+body.h*0.5)
	return "out_of_reach" if host.player_center().distance_squared_to(point) >= reach*reach else ""
func _option(id: String,label: String,enabled: bool = true,reason: String = "unavailable") -> Dictionary:
	return {"id":id,"label":label,"enabled":enabled,"reason":"" if enabled else reason}
func _options(view: String,page: int) -> Array[Dictionary]:
	var o: Dictionary = host.s.office
	var result: Array[Dictionary] = []
	var count: int = _claimed().size()
	match view:
		"lease_guy":
			if o.owned: result.append(_option("lease","ask about the lease."))
			else:
				var routes: int = int(host.p.lifetime.get("routesCompleted",0))
				var can: bool = host.p.cash >= 40 and host.p.copper >= 1
				result.append(_option("purchase",("replace the lock. $40 + 1 pure copper." if can else "need $40 and 1 pure copper.") if routes >= 3 else "file three block routes first. (%d/3)" % routes,routes >= 3 and can))
				result.append(_option("includes","ask what the unit includes."))
			result.append(_option("leave","leave."))
		"gutter_greg":
			var done: bool = host.s.counters.get("gutterInventoryDay",0) == host.s.day
			result.append(_option("inventory","count inventory. (already counted today.)" if done else "count the canal inventory. (+1 scrap)",not done))
			result.append(_option("water","ask where the water went.")); result.append(_option("leave","leave."))
		"office":
			if not o.owned:
				result.append(_option("look","look toward the leasing guy.")); result.append(_option("leave","leave.")); return result
			var cap: int = _cap()
			if o.claimJob is Dictionary and o.claimJob.stage == "file":
				var site: Dictionary = by_id[o.claimJob.id]; var cost: int = _cost(); var can: bool = host.p.cash >= cost and host.p.copper >= 1
				result.append(_option("file_claim","file %s. $%d + 1 copper." % [str(site.name).to_lower(),cost] if can else "filing needs $%d + 1 copper." % cost,can))
			if o.workJob is Dictionary and o.workJob.stage == "file": result.append(_option("file_work","daily ledger closed. inspected order waits for morning." if o.workToday >= cap else "file work order %d. collect the net." % o.workJob.serial,o.workToday < cap))
			result.append(_option("claims",("open the active claim file." if o.claimJob != null else "open district claims. (%d/%d)" % [count,sites.size()]) if o.upgrades.desk else "district claims need a desk.",o.upgrades.desk))
			var work: String = "work orders need a radio."
			if o.upgrades.radio:
				if o.workJob != null: work = "work order %d is %s." % [o.workJob.serial,o.workJob.stage]
				elif count == 0: work = "work orders need one claimed district."
				elif o.workToday >= cap: work = "work orders closed today. (%d/%d)" % [o.workToday,cap]
				else: work = "take a work order. (%d/%d filed today)" % [o.workToday,cap]
			result.append(_option("work",work,o.upgrades.radio and not _contract() and count > 0 and o.workToday < cap))
			if host.s.kingdom.stage != "locked": result.append(_option("kingdom","open the hostile correspondence." if host.s.kingdom.stage == "summons" else "open the CURB WAR ledger."))
			result.append(_option("upgrades","look at office upgrades. (%d/%d)" % [_upgrade_count(),upgrades.size()]))
			result.append(_option("locker","open the chained locker." if o.upgrades.locker else "locker not installed.",o.upgrades.locker))
			result.append(_option("cot","use the cot." if o.upgrades.cot else "cot not installed.",o.upgrades.cot))
			var reroll: String = "route board not installed." if not o.upgrades.route_board else ("route board used today." if o.rerollDay == host.s.day else "replace the current block route. (no payout)")
			result.append(_option("reroll",reroll,o.upgrades.route_board and o.rerollDay != host.s.day and not _contract()))
			result.append(_option("leave","leave the office."))
		"upgrades":
			for d: Dictionary in upgrades:
				var price: String = "$%d" % d.cash+(" + %d copper" % d.copper if d.copper else "")
				result.append(_option("upgrade:"+d.id,"✓ %s installed." % d.name if o.upgrades[d.id] else "%s · %s · %s" % [d.name,price,d.desc],not o.upgrades[d.id] and host.p.cash >= d.cash and host.p.copper >= d.copper))
			result.append(_option("back","back to the office."))
		"claims":
			if o.claimJob is Dictionary:
				if o.claimJob.stage == "file":
					var cost: int = _cost(); var can: bool = host.p.cash >= cost and host.p.copper >= 1
					result.append(_option("file_claim","file now. $%d + 1 copper." % cost if can else "need $%d + 1 copper." % cost,can))
				result.append(_option("cancel_claim","cancel the claim. (no refund)" if o.claimJob.stage == "install" else "cancel the claim."))
			elif o.workJob == null:
				for site: Dictionary in sites.slice(page*7,page*7+7):
					var reason: String = _claim_reason(site)
					var owned: bool = host.s.districtClaims.get(site.id,false)
					result.append(_option("claim:"+site.id,"✓ %s · entered in pen." % site.name if owned else ("%s · %s" % [site.name,reason] if not reason.is_empty() else "%s · open a survey file." % site.name),reason.is_empty(),reason))
				if page < 1: result.append(_option("page:1","next ledger page."))
				if page > 0: result.append(_option("page:0","previous ledger page."))
			result.append(_option("back","back." if o.workJob != null else "back to the office."))
	return result
func _text(view: String,page: int) -> Dictionary:
	var o: Dictionary = host.s.office
	match view:
		"lease_guy":
			return {"title":"THE LEASING GUY","text":"he checks the key ring.\none key is missing.\nhe knows which key." if o.owned else ("he has a key on a fishhook.\nthe unit says TAX HELP.\nthere is no tax help." if host.p.lifetime.get("routesCompleted",0) >= 3 else "he has a key on a fishhook.\nhe wants three route sheets before he knows your name.\nhe does not want your name.")}
		"gutter_greg": return {"title":"GUTTER GREG","text":"greg is guarding a rubber duck.\nthe duck is in the municipal inventory.\nthe municipality has not been told."}
		"upgrades": return {"title":"OFFICE IMPROVEMENTS","text":"a legal pad is taped to the wall.\nthe legal pad is not legal advice.\ncash $%d · pure copper %d." % [host.p.cash,host.p.copper]}
		"claims":
			if o.claimJob is Dictionary:
				var site: Dictionary = by_id[o.claimJob.id]; var stage: String = o.claimJob.stage
				return {"title":"ACTIVE CLAIM · "+str(site.name),"text":"stage: %s.\n%s" % [stage,site.survey.task if stage == "survey" else ("survey attached. filing fee pending." if stage == "file" else site.sign.task)]}
			if o.workJob is Dictionary: return {"title":"DISTRICT CLAIMS","text":"the desk is occupied by work order %d.\nfinish the order before opening another file." % o.workJob.serial}
			return {"title":"DISTRICT CLAIMS · PAGE %d" % (page+1),"text":"the form recognizes signs, curbs, and faction permission.\nstreet %d · scrap %d · spiritual %d." % [host.p.faction.street,host.p.faction.scrap,host.p.faction.spiritual]}
	if not o.owned: return {"title":"THE OFFICE","text":"the key does not fit.\nthe door has one lock and three opinions.\nthe leasing guy is standing somewhere in the lot."}
	var count: int = _claimed().size()
	return {"title":"THE OFFICE","text":"one room. one lock. %d district%s entered in pen.\nupgrades: %d/%d. orders filed: %d.\nthe smell has seniority." % [count,"" if count == 1 else "s",_upgrade_count(),upgrades.size(),o.jobsCompleted]}
func open(target: String) -> Dictionary:
	close()
	return _open_view(target,target,0)
func _open_view(target: String,view: String,page: int) -> Dictionary:
	var reason: String = _reason(target)
	if not reason.is_empty(): return _fail(reason)
	var reach: Dictionary = session.probe(target)
	if not reach.ok: return reach
	var o: Dictionary = host.s.office
	if view in ["lease_guy","upgrades","claims"] or (view == "office" and o.get("owned",false)): o = _ensure()
	if view in ["claims","upgrades"] and not o.owned: view = "office"
	if view == "claims" and not o.upgrades.desk: view = "office"
	if view == "office" and o.owned:
		_sync_day(); _campaign_ref.get_ref().update_office_milestones(); _campaign_ref.get_ref().maybe_unlock_kingdom(false,true); _campaign_ref.get_ref().sync_quests()
	page = clampi(page,0,1)
	var options: Array[Dictionary] = _options(view,page)
	var actions: Array[String] = []
	for option: Dictionary in options: actions.append(option.id)
	var accepted: Dictionary = session.begin(target,actions)
	if not accepted.ok: return accepted
	_target = target; _view = view; _page = page; host.s.mode = "dialogue"
	var result: Dictionary = _text(view,page)
	result.merge({"ok":true,"domain":"office","token":accepted.token,"target":target,"view":view,"page":page,"options":options})
	return result
func close() -> void:
	if not _target.is_empty() and host != null and host.s.mode == "dialogue": host.s.mode = "playing"
	_target = ""; _view = ""; _page = 0
	if session != null: session.close()
func select(token: Variant,action: String) -> Dictionary:
	var target: String = _target; var view: String = _view; var page: int = _page
	var accepted: Dictionary = session.consume(token,action)
	if not accepted.ok: return accepted
	_target = ""; _view = ""; _page = 0
	if host != null and host.s.mode == "dialogue": host.s.mode = "playing"
	var reason: String = _reason(target)
	if not reason.is_empty(): return _fail(reason)
	var choice: Dictionary = {}
	for option: Dictionary in _options(view,page):
		if option.id == action: choice = option; break
	if choice.is_empty() or not choice.enabled: return _fail("action_unavailable" if choice.is_empty() else str(choice.reason))
	host.s.mode = "playing"
	match action:
		"leave": return _done()
		"back": return _open_view("office","office",0)
		"look": _toast("east side of the lot.\nclipboard. key ring. no urgency.")
		"lease": _toast("there is no lease.\nhe says this like a feature.")
		"includes": _toast("four walls.\none door.\na smell with seniority.")
		"water": _toast("greg points downstream.\nthere is no downstream on the form.")
		"inventory": host.s.counters.gutterInventoryDay = host.s.day; host.apply_rep({"scrap":1}); _toast("duck: one.\ncart parts: uncertain.\n+ 1 scrap",2400); _save()
		"purchase":
			if not _purchase(): return _fail("purchase_unavailable")
		"claims","upgrades": return _open_view("office",action,0)
		"file_claim":
			if not _file_claim(): return _fail("filing_unavailable")
			return _open_view("office",view,0)
		"cancel_claim":
			var paid: bool = host.s.office.claimJob.stage == "install"
			host.s.office.claimJob = null; _toast("the form is canceled.\nthe filing fee is not." if paid else "the form is canceled.\nno one had signed it.",2400); _save()
			return _open_view("office","office",0)
		"work":
			if not _start_work(): return _fail("work_unavailable")
		"file_work":
			if not _file_work(): return _fail("work_unavailable")
			return _open_view("office","office",0)
		"reroll":
			var o: Dictionary = _ensure()
			if not o.upgrades.route_board or o.rerollDay == host.s.day or _contract(): return _fail("reroll_unavailable")
			o.rerollDay = host.s.day
			var progression: Object = _progression_ref.get_ref()
			var last: String = host.s.blockRoute.lastStopId if progression.valid_route(host.s.blockRoute) else ""
			progression.roll_route(false,last); _toast("the old sheet goes under the desk.\nit receives no payout."); _save()
		"locker","cot":
			var result: Dictionary = _travel_ref.get_ref().open("office:chest" if action == "locker" else "office:cot")
			result.domain = "travel"; return result
		"kingdom": return _fail("kingdom_actions_pending")
		_:
			if action.begins_with("page:"): return _open_view("office","claims",int(action.get_slice(":",1)))
			if action.begins_with("claim:"):
				if not _select_claim(action.get_slice(":",1)): return _fail("claim_unavailable")
			elif action.begins_with("upgrade:"):
				if not _purchase_upgrade(action.get_slice(":",1)): return _fail("upgrade_unavailable")
				return _open_view("office","upgrades",0)
			else: return _fail("unknown_action")
	return _done()
func _purchase() -> bool:
	var o: Dictionary = _ensure()
	if o.owned or host.p.lifetime.get("routesCompleted",0) < 3 or host.p.cash < 40 or host.p.copper < 1: return false
	host.p.cash -= 40; host.p.copper -= 1; o.owned = true
	if host.s.quests.has("office_space"):
		host.s.quests.office_space.done = true; host.s.quests.office_space.available = true; _toast("· QUEST COMPLETE ·\nTHE OFFICE"); _sound("rankUp")
	if host.s.quests.has("paper_empire"): host.s.quests.paper_empire.available = true
	host.unlock_achievement("squatters_rights"); _sound("rankUp"); _toast("- $40 · - 1 copper\n+ one key\nthe office is yours in the sense that no one stopped you.",4200)
	_feed("acquired an office. the office was surprised."); _save(); return true
func _purchase_upgrade(id: String) -> bool:
	var o: Dictionary = _ensure()
	for d: Dictionary in upgrades:
		if d.id != id: continue
		if not o.owned or o.upgrades[id] or host.p.cash < d.cash or host.p.copper < d.copper: return false
		host.p.cash -= int(d.cash); host.p.copper -= int(d.copper); o.upgrades[id] = true
		_sound("rankUp"); _toast("· OFFICE UPGRADE ·\n%s installed.\n%s" % [d.name,d.desc],3000); _save(); return true
	return false
func _select_claim(id: String) -> bool:
	var o: Dictionary = _ensure(); var site: Dictionary = by_id.get(id,{})
	if not o.owned or not o.upgrades.desk or _contract() or not _claim_reason(site).is_empty(): return false
	o.claimJob = {"id":id,"stage":"survey"}; _toast("· CLAIM OPENED ·\n%s\nfirst: %s" % [site.name,site.survey.task],3200); _save(); return true
func _file_claim() -> bool:
	var o: Dictionary = _ensure()
	if not o.claimJob is Dictionary or o.claimJob.stage != "file": return false
	var cost: int = _cost()
	if host.p.cash < cost or host.p.copper < 1: return false
	host.p.cash -= cost; host.p.copper -= 1; o.claimJob.stage = "install"; _sound("coin")
	_toast("- $%d · - 1 copper\nform filed.\nnow install the sign at %s." % [cost,str(by_id[o.claimJob.id].name).to_lower()],3400); _save(); return true
func _start_work() -> bool:
	var o: Dictionary = _ensure(); _sync_day(); var owned: Array[String] = _claimed()
	if not o.upgrades.radio or owned.is_empty() or _contract() or o.workToday >= _cap(): return false
	var pool: Array[String] = []
	for id: String in owned:
		if id != o.lastWorkId: pool.append(id)
	if pool.is_empty(): pool = owned.duplicate()
	var id: String = pool[host.random_index(pool.size())]
	o.orderSerial += 1; o.workJob = {"id":id,"stage":"inspect","serial":o.orderSerial}; o.lastWorkId = id
	_toast("· WORK ORDER %d ·\ninspect the sign at %s.\nbring the condition back." % [o.orderSerial,str(by_id[id].name).to_lower()],3200); _save(); return true
func _file_work() -> bool:
	var o: Dictionary = _ensure(); _sync_day()
	if not o.workJob is Dictionary or o.workJob.stage != "file" or o.workToday >= _cap(): return false
	var pay: int = mini(12,5+_claimed().size()); o.jobsCompleted += 1; o.workToday += 1
	host.p.lifetime.officeJobs = o.jobsCompleted; host.p.cash += pay
	var cred: int = 1 if int(o.jobsCompleted)%5 == 0 else 0
	host.p.cred += cred
	var serial: int = int(o.workJob.serial); o.workJob = null; _sound("coin")
	_toast("· ORDER %d FILED ·\ngross $%d. chair rental $17.\nnet + $%d%s" % [serial,pay+17,pay," · + 1 cred" if cred else ""],3600); _save(); return true
func active_field_target() -> Dictionary:
	if host == null: return {}
	var o: Dictionary = host.s.office
	var job: Dictionary = {}
	var phase: String = ""
	if o.get("claimJob") is Dictionary and o.claimJob.stage in ["survey","install"]: job = o.claimJob; phase = "survey" if job.stage == "survey" else "sign"
	elif o.get("workJob") is Dictionary and o.workJob.stage == "inspect": job = o.workJob; phase = "sign"
	if job.is_empty() or not by_id.has(job.id): return {}
	var point: Dictionary = by_id[job.id][phase]
	return {"id":"claim:%s:%s" % [job.id,phase],"claim_id":job.id,"stage":job.stage,"x":point.x,"y":point.y,"task":point.task}
func use_field_target(context: Dictionary = {}) -> Dictionary:
	if not ready(): return _fail("missing_dependency")
	if host.s.mode != "playing" or context.get("hidden",false) or host.p.stunT > 0 or host.s.get("bossActive",false) or host.s.get("brutusOlderActive",false): return _fail("field_unavailable")
	var target: Dictionary = active_field_target()
	if target.is_empty(): return _fail("no_active_field_target")
	if context.has("target_id") and context.target_id != target.id: return _fail("wrong_target")
	if host.player_center().distance_squared_to(Vector2(target.x,target.y)) >= 58.0*58.0: return _fail("out_of_reach")
	var reach: Dictionary = session.probe(target.id)
	if not reach.ok: return reach
	var o: Dictionary = host.s.office; var site: Dictionary = by_id[target.claim_id]
	if target.stage == "survey":
		o.claimJob.stage = "file"; _sound("coin"); _toast(str(site.survey.stamp)+"\nreturn to the office. the desk wants money.",3000); _save()
	elif target.stage == "install":
		host.s.districtClaims[site.id] = true; o.claimJob = null; host.p.cred += 2
		_campaign_ref.get_ref().update_office_milestones(false); _campaign_ref.get_ref().maybe_unlock_kingdom(false,true); _sound("rankUp")
		_toast(str(site.sign.stamp)+"\n· DISTRICT ENTERED ·  + 2 cred\n"+str(site.name),3800); _feed("installed a sign at "+str(site.name).to_lower()+". the sign has standing."); _save()
	else: o.workJob.stage = "file"; _sound("coin"); _toast("sign inspected.\nit is still leaning.\nreturn to the office.",2600); _save()
	return {"ok":true,"target":target.id,"stage":target.stage}
func office_objective() -> Dictionary:
	if host == null or not host.s.flags.get("introDone",false): return {}
	var o: Dictionary = host.s.office; var quest: Dictionary = host.s.quests.get("office_space",{})
	if not o.get("owned",false) and not quest.get("done",false) and quest.get("available") == true: return {"kind":"office","text":"find the leasing guy in the lot.","x":5400,"y":3100}
	if o.get("claimJob") is Dictionary:
		var site: Dictionary = by_id[o.claimJob.id]; var stage: String = o.claimJob.stage
		if stage == "survey": return {"kind":"office","text":"survey "+str(site.name).to_lower()+". "+str(site.survey.task),"x":site.survey.x,"y":site.survey.y}
		if stage == "file": return {"kind":"office","text":"return to the office and file "+str(site.name).to_lower()+".","x":4920,"y":3210}
		return {"kind":"office","text":"install the claim sign. "+str(site.sign.task),"x":site.sign.x,"y":site.sign.y}
	if o.get("workJob") is Dictionary:
		var site: Dictionary = by_id[o.workJob.id]
		if o.workJob.stage == "inspect": return {"kind":"office","text":"order %d · inspect the %s sign." % [o.workJob.serial,str(site.name).to_lower()],"x":site.sign.x,"y":site.sign.y}
		return {"kind":"office","text":"order %d · return to the office and file." % o.workJob.serial,"x":4920,"y":3210}
	var paper: Dictionary = host.s.quests.get("paper_empire",{})
	if o.get("owned",false) and not paper.get("done",false) and paper.get("available") == true: return {"kind":"office","text":"use the office desk. claim the drainage canal." if o.upgrades.desk else "put a desk in the office.","x":4920,"y":3210}
	return {}
