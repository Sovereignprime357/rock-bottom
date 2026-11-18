class_name RockBottomKingdomCampaign
extends RefCounted
## Source court actions; Combat, Campaign, Day and Runtime retain their authorities.
const Campaign = preload("res://scripts/campaign_system.gd")
const Session = preload("res://scripts/action_session.gd")
const MODULE := "src/systems/campaigns.js"
var _owner_ref: WeakRef
var _spatial_ref: WeakRef
var _campaign_ref: WeakRef
var _office_ref: WeakRef
var _combat_ref: WeakRef
var _memory_ref: WeakRef
var _communications_ref: WeakRef
var _days_ref: WeakRef
var host: RefCounted:
	get: return _owner_ref.get_ref() if _owner_ref != null else null
var session: RefCounted
var clans: Array = []
var emperor: Dictionary = {}
var doors: Array = []
var _by_id: Dictionary = {}
var _player_epoch: Dictionary = {}
var _state_epoch: Dictionary = {}
var _ledger_open: bool = false
var _wall_ms: float = 0.0
var _ending_at: float = -1.0
var _ending_due: bool = false

func _init(owner: RefCounted,spatial: Object,campaign: Object,office: Object,combat: Object,memory: Object,communications: Object,days: Object) -> void:
	_owner_ref = weakref(owner)
	_spatial_ref = weakref(spatial) if spatial != null else null
	_campaign_ref = weakref(campaign) if campaign != null else null
	_office_ref = weakref(office) if office != null else null
	_combat_ref = weakref(combat) if combat != null else null
	_memory_ref = weakref(memory) if memory != null else null
	_communications_ref = weakref(communications) if communications != null else null
	_days_ref = weakref(days) if days != null else null
	session = Session.new(owner,spatial)
	clans = owner.definition(MODULE,"KINGDOM_CLAN_LIST",[]); emperor = owner.definition(MODULE,"KINGDOM_EMPEROR",{}); doors = owner.definition(MODULE,"KINGDOM_DOORS",[])
	for clan: Dictionary in clans: _by_id[clan.id] = clan
	_sync_epoch()
func _dep(reference: WeakRef,method: StringName) -> Object:
	var value: Object = reference.get_ref() if reference != null else null
	return value if value != null and value.has_method(method) else null
func ready() -> bool:
	return host != null and clans.size() == 3 and not emperor.is_empty() and doors.size() == 4 and _dep(_spatial_ref,&"can_reach_target") != null and _dep(_campaign_ref,&"refresh_forces") != null and _dep(_office_ref,&"_start_work") != null and _dep(_office_ref,&"open") != null and _dep(_combat_ref,&"clear_actor") != null and _dep(_memory_ref,&"record") != null and _dep(_communications_ref,&"post") != null and _dep(_communications_ref,&"broadcast") != null and _dep(_days_ref,&"can_replace_campaign_forces") != null and _dep(_days_ref,&"discard_pending_campaign_clan") != null
func _sync_epoch() -> bool:
	if host == null: return false
	if not is_same(_player_epoch,host.p) or not is_same(_state_epoch,host.s):
		_player_epoch = host.p; _state_epoch = host.s; _ending_at = -1.0; _ending_due = false; _ledger_open = false; session.close()
	return true
func _fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
func _toast(text: String,ms: int = 2200) -> void: host.emit_event("toast",{"text":text,"duration_ms":ms})
func _sound(id: String) -> void: host.emit_event("sound",{"id":id})
func _save() -> void: host.emit_event("save_requested")
func _feed(text: String,author: String = "@blocklog") -> void: _communications_ref.get_ref().post(text,author)
func _actor(id: String) -> Dictionary:
	for body: Dictionary in host.npcs:
		if body.get("id") == id: return body
	return {}
func _clan(stage: String) -> Dictionary:
	for clan: Dictionary in clans:
		if stage in [clan.marksStage,clan.bossStage]: return clan
	return {}
func _canonical() -> Dictionary:
	var kingdom: Dictionary = Campaign.normalize_kingdom(host.s.kingdom)
	kingdom.pretendersDefeated = maxi(int(kingdom.pretendersDefeated),Campaign.office_nat(host.p.lifetime.get("pretendersDefeated")))
	return kingdom
func _ensure() -> Dictionary:
	host.s.kingdom = _canonical(); host.p.lifetime.pretendersDefeated = host.s.kingdom.pretendersDefeated
	return host.s.kingdom
static func _bits(marks: int) -> int: return int((marks&1) != 0)+int((marks&2) != 0)+int((marks&4) != 0)
func _common_reason() -> String:
	if not _sync_epoch() or not ready(): return "missing_dependency"
	if host.s.mode not in ["playing","dialogue"]: return "wrong_mode"
	if host.s.get("bossKind","") == "kingdom": return "active_boss"
	return ""
func _office_reason() -> String:
	var reason: String = _common_reason()
	if not reason.is_empty(): return reason
	var door: Dictionary = host.definition(MODULE,"OFFICE_DOOR",{})
	return "out_of_reach" if host.player_center().distance_squared_to(Vector2(door.x+door.w*0.5,door.y+door.h*0.5)) >= 44.0*44.0 else ""
func _option(id: String,label: String,enabled: bool = true) -> Dictionary: return {"id":id,"label":label,"enabled":enabled,"reason":"" if enabled else "unavailable"}
func _ledger_options() -> Array[Dictionary]:
	var o: Dictionary = host.s.office
	if host.s.kingdom.stage == "summons": return [_option("accept","answer the frequency." if o.upgrades.radio else "install the radio first.",o.upgrades.radio),_option("leave","leave it under the stapler.")]
	var office: Object = _office_ref.get_ref(); var count: int = office._claimed().size(); var cap: int = office._cap()
	var work: String = "work orders need a radio."
	if o.upgrades.radio:
		if o.workJob != null: work = "work order %d is %s." % [o.workJob.serial,o.workJob.stage]
		elif count == 0: work = "work orders need one claimed district."
		elif o.workToday >= cap: work = "work orders closed today. (%d/%d)" % [o.workToday,cap]
		else: work = "take a work order. (%d/%d filed today)" % [o.workToday,cap]
	return [_option("clause","read the succession clause."),_option("work",work,o.upgrades.radio and o.workJob == null and o.claimJob == null and count > 0 and o.workToday < cap),_option("back","back to the office.")]
func open_ledger() -> Dictionary:
	close()
	var reason: String = _office_reason()
	if not reason.is_empty(): return _fail(reason)
	var reach: Dictionary = session.probe("office")
	if not reach.ok: return reach
	var k: Dictionary = _ensure(); _office_ref.get_ref()._ensure()
	if k.stage != "summons": _office_ref.get_ref()._sync_day()
	var options: Array[Dictionary] = _ledger_options(); var actions: Array[String] = []
	for option: Dictionary in options: actions.append(option.id)
	var accepted: Dictionary = session.begin("office",actions)
	if not accepted.ok: return accepted
	_ledger_open = true; host.s.mode = "dialogue"
	var title: String = "HOSTILE CORRESPONDENCE"
	var text: String = "the envelope says OCCUPANT / REGARDING KINGDOM.\nthe return address is a tarp tied to a fence."
	if k.stage != "summons":
		var target: Dictionary = objective(); var seals: int = 0
		for id: String in k.defeats:
			if id != "curb_emperor": seals += 1
		title = "CURB WAR LEDGER"; text = str(target.get("text","the chair remains occupied."))+"\n\nseals entered: %d/3\npretenders removed: %d" % [seals,k.pretendersDefeated]
	return {"ok":true,"domain":"kingdom","token":accepted.token,"target":"office","title":title,"text":text,"options":options}
func close() -> void:
	if _ledger_open and host != null and is_same(_state_epoch,host.s) and host.s.mode == "dialogue": host.s.mode = "playing"
	_ledger_open = false
	if session != null: session.close()
func select(token: Variant,action: String) -> Dictionary:
	var accepted: Dictionary = session.consume(token,action)
	if not accepted.ok:
		if accepted.reason not in ["stale_session","replaced_state"]:
			_ledger_open = false
			if host != null and host.s.mode == "dialogue": host.s.mode = "playing"
		return accepted
	_ledger_open = false
	if host.s.mode == "dialogue": host.s.mode = "playing"
	var reason: String = _office_reason()
	if not reason.is_empty(): return _fail(reason)
	var choice: Dictionary = {}
	for option: Dictionary in _ledger_options():
		if option.id == action: choice = option; break
	if choice.is_empty() or not choice.enabled: return _fail("action_unavailable")
	match action:
		"leave": pass
		"clause": _toast("one curb. one ruler.\nall measurements final.\nno ruler has supplied a ruler.",3000)
		"back": return _office_ref.get_ref().open("office")
		"work":
			if not _office_ref.get_ref()._start_work(): return _fail("work_unavailable")
		"accept":
			var k: Dictionary = _ensure(); var o: Dictionary = _office_ref.get_ref()._ensure()
			if k.stage != "summons" or not o.upgrades.radio: return _fail("summons_unavailable")
			k.stage = "tarp_marks"; k.marks = 0; _campaign_ref.get_ref().sync_quests(); _sound("radio")
			_toast("· CURB WAR OPEN ·\nblue tarp court disputes your weather.\nserve three corrections.",4200)
			_communications_ref.get_ref().broadcast("SUCCESSION NOTICE FILED. THREE COURTS OBJECT. ONE DITCH IS LISTENING.")
			_feed("answered the radio. blue tarp court says the sky belongs to a rope.","@crackheadcent"); _save()
		_: return _fail("unknown_action")
	return {"ok":true,"closed":true}
func use_door(id: String) -> Dictionary:
	var reason: String = _common_reason()
	if not reason.is_empty(): return _fail(reason)
	for door: Dictionary in doors:
		if id != "kingdom:"+str(door.id): continue
		if host.player_center().distance_squared_to(Vector2(door.x+door.w*0.5,door.y+door.h*0.5)) >= 44.0*44.0: return _fail("out_of_reach")
		var reach: Dictionary = session.probe(id)
		if not reach.ok: return reach
		if door.id == "wire": _memory_ref.get_ref().record("choir_office","bother","wire_door")
		_toast(door.line); return {"ok":true,"target":id}
	return _fail("unknown_door")
func active_targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if host == null: return result
	var k: Dictionary = host.s.kingdom; var clan: Dictionary = _clan(str(k.get("stage","locked")))
	if not clan.is_empty() and k.stage == clan.marksStage:
		for index: int in range(3):
			if int(k.marks)&(1<<index): continue
			result.append({"id":"kingdom_mark:%s:%d" % [clan.id,index],"x":clan.marks[index].x,"y":clan.marks[index].y,"reach":58.0,"clan":clan.id,"index":index})
		if k.marks == 7: result.append({"id":"kingdom_banner:"+str(clan.id),"x":clan.banner.x,"y":clan.banner.y,"reach":72.0,"clan":clan.id})
	elif k.get("stage") == "emperor_gate": result.append({"id":"kingdom_banner:throne","x":emperor.banner.x,"y":emperor.banner.y,"reach":72.0,"clan":"emperor"})
	return result
func action_hint() -> String:
	if host == null: return ""
	for target: Dictionary in active_targets():
		if host.player_center().distance_squared_to(Vector2(target.x,target.y)) >= target.reach*target.reach: continue
		if target.has("index"): return "serve the curb correction"
		return "challenge the curb emperor" if target.clan == "emperor" else "challenge "+str(_by_id[target.clan].bossName).to_lower()
	return ""
func use_target(id: String,context: Dictionary = {}) -> Dictionary:
	if not _sync_epoch() or not ready(): return _fail("missing_dependency")
	if host.s.mode != "playing" or context.get("hidden",false) or host.p.stunT > 0 or host.s.get("bossActive",false) or host.s.get("brutusOlderActive",false): return _fail("target_unavailable")
	var target: Dictionary = {}
	for candidate: Dictionary in active_targets():
		if candidate.id == id: target = candidate; break
	if target.is_empty(): return _fail("inactive_target")
	if host.player_center().distance_squared_to(Vector2(target.x,target.y)) >= target.reach*target.reach: return _fail("out_of_reach")
	var reach: Dictionary = session.probe(id)
	if not reach.ok: return reach
	if not target.has("index"): return {"ok":start_boss(target.clan),"target":id}
	var k: Dictionary = _ensure(); var clan: Dictionary = _by_id[target.clan]; var index: int = target.index
	k.marks = int(k.marks)|(1<<index); _sound("coin")
	_toast(str(clan.marks[index].stamp)+"\n[%d/3 corrections served]" % _bits(int(k.marks)),3000)
	if k.marks == 7: _toast("all three corrections entered.\n"+str(clan.bossName).to_lower()+" is accepting one appeal.",3600)
	_save(); return {"ok":true,"target":id}
func _battle_records(definition: Dictionary,is_emperor: bool) -> Array[Dictionary]:
	var clan: String = "throne" if is_emperor else str(definition.id)
	var result: Array[Dictionary] = [Campaign._actor(definition,definition.boss,{"id":definition.bossId,"name":definition.bossName,"sprite":definition.bossSprite,"hp":definition.bossHp,"dmg":definition.bossDmg,"speed":definition.bossSpeed,"archetype":definition.archetype,"showHp":true,"aggro":true,"kingdomBoss":true,"kingdomClan":clan,"kingdomPhase":1})]
	for index: int in range(2):
		result.append(Campaign._actor(definition,definition.adds[index],{"id":"kingdom_add_%s_%d" % [definition.bossId,index],"name":"KNIGHT EMERITUS" if is_emperor else definition.guardName,"sprite":["blue_tarp_guard","receipt_guard"][index] if is_emperor else definition.guardSprite,"hp":45,"dmg":6,"speed":1.35,"archetype":"swarmer" if index else "charger","aggro":true,"kingdomAdd":true,"kingdomClan":clan}))
	return result
func start_boss(id: String) -> bool:
	if not _sync_epoch() or not ready() or host.s.get("bossActive",false) or host.s.get("brutusOlderActive",false): return false
	var is_emperor: bool = id == "emperor"; var definition: Dictionary = emperor if is_emperor else _by_id.get(id,{})
	if definition.is_empty(): return false
	var k: Dictionary = _canonical()
	var stage_valid: bool = k.stage == "emperor_gate" if is_emperor else (k.stage == definition.marksStage and k.marks == 7)
	if not stage_valid: return false
	var records: Array[Dictionary] = _battle_records(definition,is_emperor)
	for body: Dictionary in records:
		var origin := Vector2(body.x,body.y)
		if not _combat_ref.get_ref().clear_actor(body): return false
		var point := Vector2(body.x,body.y)
		if not point.is_finite() or point.distance_to(origin) > 100.00001 or point.x < 0 or point.y < 0 or point.x+body.w > 8600 or point.y+body.h > 5600: return false
	var clan: String = "throne" if is_emperor else id
	if not _days_ref.get_ref().discard_pending_campaign_clan(clan,false): return false
	for index: int in range(host.npcs.size()-1,-1,-1):
		if host.npcs[index].get("kingdomGuard",false) and host.npcs[index].get("kingdomClan") == clan:
			host.emit_event("actor_removed",{"actor_id":host.npcs[index].id}); host.npcs.remove_at(index)
	host.s.kingdom = k; host.p.lifetime.pretendersDefeated = k.pretendersDefeated
	for body: Dictionary in records: host.npcs.append(body); host.emit_event("actor_spawned",{"actor_id":body.id})
	k.stage = "emperor_boss" if is_emperor else definition.bossStage; k.bossId = definition.bossId
	host.s.kingdomBattle = {"id":definition.bossId,"zoneId":definition.zoneId,"escapeT":0}
	host.s.bossActive = true; host.s.bossKind = "kingdom"; host.s.bossPhase = 1; host.s.bossNPC = records[0]
	_sound("bossRoar"); host.s.shake = 10
	_toast("the curb emperor stands from the chair.\nthe chair keeps the title." if is_emperor else str(definition.bossName).to_lower()+" accepts the appeal.\ntwo clerks stand with him.",4000); _save(); return true
func _clear_globals() -> void:
	host.s.bossActive = false; host.s.bossKind = ""; host.s.bossPhase = 0; host.s.bossNPC = null; host.s.kingdomBattle = null; host.s.kingdom.bossId = ""
func _remove_encounter(boss_id: String = "") -> void:
	var doomed: Dictionary = {}
	for index: int in range(host.npcs.size()-1,-1,-1):
		var actor: Dictionary = host.npcs[index]
		if actor.get("kingdomAdd",false) or (actor.get("kingdomBoss",false) if boss_id.is_empty() else actor.id == boss_id):
			doomed[actor.id] = true; host.emit_event("actor_removed",{"actor_id":actor.id}); host.npcs.remove_at(index)
	for index: int in range(host.projectiles.size()-1,-1,-1):
		var source: Variant = host.projectiles[index].get("from")
		if source is Dictionary and (source.get("kingdomBoss",false) or source.get("kingdomAdd",false) or (boss_id.is_empty() and doomed.has(source.get("id")))): host.projectiles.remove_at(index)
func _retry_kingdom() -> Dictionary:
	var k: Dictionary = _canonical()
	if Campaign.RETRIES.has(k.stage): k.marks = 0 if k.stage == "emperor_boss" else 7; k.stage = Campaign.RETRIES[k.stage]
	k.bossId = ""; return k
func abort(show_receipt: bool = false,refresh: bool = false) -> bool:
	if not _sync_epoch() or not ready() or (host.s.get("bossKind") != "kingdom" and host.s.get("kingdomBattle") == null): return false
	var k: Dictionary = _retry_kingdom()
	if refresh and not _days_ref.get_ref().can_replace_campaign_forces(k,k.pretendersDefeated): return false
	host.s.kingdom = k; host.p.lifetime.pretendersDefeated = k.pretendersDefeated
	_remove_encounter(); _clear_globals(); _campaign_ref.get_ref().sync_quests()
	if show_receipt: _toast("the appeal is recessed.\nall three corrections remain entered.\nfull hearing available.",2800)
	if refresh:
		_campaign_ref.get_ref().refresh_forces(); _save()
	return true
func _victory_state(body: Dictionary) -> Dictionary:
	var k: Dictionary = _canonical(); var id: String = str(body.get("id","")); var clan: Dictionary = {}
	if not body.get("kingdomBoss",false) or host.s.get("bossKind") != "kingdom" or k.bossId != id or id in k.defeats: return {}
	var is_emperor: bool = id == "curb_emperor"
	if is_emperor:
		if k.stage != "emperor_boss": return {}
	else:
		for definition: Dictionary in clans:
			if definition.bossId == id: clan = definition; break
		if clan.is_empty() or k.stage != clan.bossStage: return {}
	k.defeats.append(id); k.stage = "complete" if is_emperor else clan.nextStage; k.marks = 0; k.bossId = ""
	if is_emperor: k.pretenderDefeatedDay = host.s.day
	return k
func can_finish_actor(detached_body: Dictionary) -> bool:
	if not ready() or detached_body.is_empty() or detached_body.get("dead",false): return false
	var body: Dictionary = _actor(str(detached_body.get("id","")))
	if body.is_empty() or body.get("dead",false): return false
	if body.get("kingdomPretender",false):
		var k: Dictionary = _canonical()
		return detached_body.get("kingdomPretender",false) and k.stage == "complete" and k.pretenderDefeatedDay != host.s.day
	if not detached_body.get("kingdomBoss",false): return false
	var next: Dictionary = _victory_state(body)
	return not next.is_empty() and _days_ref.get_ref().can_replace_campaign_forces(next,next.pretendersDefeated)
func finish_actor(id: String) -> bool:
	if not _sync_epoch(): return false
	var body: Dictionary = _actor(id)
	if body.is_empty() or body.get("hp",1) > 0 or not can_finish_actor(body): return false
	var pretender: bool = body.get("kingdomPretender",false)
	var k: Dictionary = _canonical() if pretender else _victory_state(body)
	body.dead = true; _sound("hurt"); host.emit_event("actor_died",{"actor_id":id}); host.s.kingdom = k
	if pretender:
		k.pretenderDefeatedDay = host.s.day; k.pretendersDefeated += 1; host.p.lifetime.pretendersDefeated = k.pretendersDefeated; host.p.cash += 10; host.p.cred += 2
		_toast("· PRETENDER DENIED ·\n+ $10 · + 2 cred\nfiling %d remains nonprecedential." % k.pretendersDefeated,3400); _feed("today's curb pretender withdrew in person."); _save(); return true
	var is_emperor: bool = id == "curb_emperor"; var definition: Dictionary = emperor
	if not is_emperor:
		for clan: Dictionary in clans:
			if clan.bossId == id: definition = clan; break
	host.p.cash += int(definition.rewardCash); host.p.cred += int(definition.rewardCred)
	_remove_encounter(id); _clear_globals()
	if not is_emperor:
		host.s.flags[definition.clearFlag] = true
		_toast("· QUEST COMPLETE ·\n"+str(definition.seal)); _sound("rankUp"); _sound("rankUp")
		_toast("· %s ENTERED ·\n+ $%d · + %d cred\n%s retains two objectors." % [definition.seal,definition.rewardCash,definition.rewardCred,str(definition.name).to_lower()],4400)
		_feed(str(definition.bossName).to_lower()+" is down. the seal is bent but legible.")
		_campaign_ref.get_ref().sync_quests(); _campaign_ref.get_ref().refresh_forces(); _save(); return true
	host.s.flags.throneDitchCleared = true; host.p.lifetime.pretendersDefeated = k.pretendersDefeated
	if host.s.quests.has("one_cracklord"): host.s.quests.one_cracklord.available = true; host.s.quests.one_cracklord.done = true
	host.unlock_achievement("one_cracklord"); _campaign_ref.get_ref().sync_quests(); _campaign_ref.get_ref().refresh_forces(); _sound("rankUp")
	_toast("· ONE CRACKLORD ·\n+ $60 · + 40 cred\nthe throne remains a folding chair.",4800); _save(); _ending_at = _wall_ms+2600.0; _ending_due = false; return true
func tick_active(dt_ms: float) -> bool:
	if not _sync_epoch() or not ready() or not is_finite(dt_ms) or dt_ms <= 0 or dt_ms > 50: return false
	if host.s.mode != "playing" or host.s.get("hitPause",0) > 0: return true
	var boss: Variant = host.s.get("bossNPC")
	if host.s.get("bossKind") != "kingdom" or not boss is Dictionary or boss.is_empty() or boss.get("dead",false): return true
	var battle: Variant = host.s.get("kingdomBattle"); var zone: Dictionary = {}
	if not battle is Dictionary: return true
	for candidate: Dictionary in host.content.world.zones:
		if candidate.id == battle.get("zoneId"): zone = candidate; break
	if zone.is_empty(): return true
	var point: Vector2 = host.player_center()
	var inside: bool = point.x >= zone.x and point.x <= zone.x+zone.w and point.y >= zone.y and point.y <= zone.y+zone.h
	battle.escapeT = 0 if inside else float(battle.get("escapeT",0))+dt_ms
	if battle.escapeT > 5000: return abort(true,true)
	if boss.id == "curb_emperor":
		var fraction: float = float(boss.hp)/float(boss.maxHp)
		if fraction < 0.66 and boss.kingdomPhase == 1:
			boss.kingdomPhase = 2; boss.archetype = "ranged"; boss.speed = 1.2; _toast("the emperor cites the curb from a distance.\nthe citation is airborne.",2400)
		elif fraction < 0.33 and boss.kingdomPhase == 2:
			boss.kingdomPhase = 3; boss.archetype = "charger"; boss.berserk = true; boss.speed = 2.6; boss.dmg = 15; _toast("the emperor breaks the ruler.\nmeasurement is now personal.",2600); _sound("bossRoar")
	return true
func tick_wall(monotonic_ms: float) -> bool:
	if not _sync_epoch() or not is_finite(monotonic_ms) or monotonic_ms < _wall_ms: return false
	_wall_ms = monotonic_ms
	if _ending_at >= 0 and monotonic_ms >= _ending_at:
		_ending_at = -1.0; _ending_due = true; host.emit_event("kingdom_ending_due",{"kind":"kingdom"})
	return true
func commit_ending() -> bool:
	if not _sync_epoch() or not _ending_due or host.s.kingdom.stage != "complete" or host.s.mode not in ["title","ending"]: return false
	_ending_due = false; host.s.endingContinue = true
	host.emit_event("ending_requested",{"kind":"kingdom","title":"ONE CRACKLORD","text":"the kingdom is four curbs and a ditch · the throne is a folding chair"}); _save(); return true
func after_tony_defeat() -> bool:
	if not _sync_epoch() or not ready(): return false
	_campaign_ref.get_ref().maybe_unlock_kingdom(false,true); _campaign_ref.get_ref().sync_quests(); return true
func _objective_boss(id: String) -> Dictionary:
	for body: Dictionary in host.npcs:
		if body.get("kingdomBoss",false) and body.get("id") == id and not body.get("dead",false): return body
	return {}
func objective() -> Dictionary:
	if host == null: return {}
	var k: Dictionary = host.s.kingdom; var stage: String = str(k.get("stage","locked"))
	if stage == "locked":
		var fallen: Dictionary = host.s.quests.get("fallen_king",{})
		if host.s.office.get("owned",false) and _office_ref.get_ref()._claimed().size() >= 4 and not fallen.is_empty() and not fallen.get("done",false) and fallen.get("available") != false: return {"kind":"kingdom","text":"settle the corner with tre bag tony. the regional envelope needs one local vacancy.","x":1634,"y":886}
		return {}
	if stage == "summons": return {"kind":"kingdom","text":"answer the hostile radio summons at the office." if host.s.office.upgrades.get("radio",false) else "install the office radio. hostile postage is waiting.","x":4920,"y":3210}
	var clan: Dictionary = _clan(stage)
	if not clan.is_empty():
		if stage == clan.bossStage:
			var boss: Dictionary = _objective_boss(clan.bossId); var point: Vector2 = Vector2(boss.x+boss.w*0.5,boss.y+boss.h*0.5) if not boss.is_empty() else Vector2(clan.boss.x,clan.boss.y)
			return {"kind":"kingdom","text":"defeat "+str(clan.bossName).to_lower()+". his court has no appeals.","x":point.x,"y":point.y}
		if k.marks == 7: return {"kind":"kingdom","text":"challenge "+str(clan.bossName).to_lower()+" at the court banner.","x":clan.banner.x,"y":clan.banner.y}
		for index: int in range(3):
			if int(k.marks)&(1<<index): continue
			var mark: Dictionary = clan.marks[index]
			return {"kind":"kingdom","text":str(clan.name).to_lower()+" · %d/3 · " % _bits(int(k.marks))+str(mark.task),"x":mark.x,"y":mark.y}
	if stage == "anoint": return {"kind":"kingdom","text":"smoke one real rock at the block. the crown requires bad reception.","x":1064,"y":882}
	if stage == "emperor_gate": return {"kind":"kingdom","text":"challenge the curb emperor in the throne ditch.","x":emperor.banner.x,"y":emperor.banner.y}
	if stage == "emperor_boss":
		var boss: Dictionary = _objective_boss("curb_emperor"); var point: Vector2 = Vector2(boss.x+boss.w*0.5,boss.y+boss.h*0.5) if not boss.is_empty() else Vector2(emperor.boss.x,emperor.boss.y)
		return {"kind":"kingdom","text":"defeat the curb emperor. measure nothing.","x":point.x,"y":point.y}
	if stage == "complete":
		for body: Dictionary in host.npcs:
			if body.get("kingdomPretender",false) and not body.get("dead",false): return {"kind":"pretender","text":"today's curb pretender has filed in person.","x":body.x+body.w*0.5,"y":body.y+body.h*0.5}
	return {}
