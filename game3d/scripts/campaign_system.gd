class_name RockBottomCampaign
extends RefCounted
## P13a source state repair and deterministic force plans. Menus/battles remain P13b/c.
const Content = preload("res://scripts/content_catalog.gd")
const MODULE := "src/systems/campaigns.js"
const LIMIT := 1000000000
const DEFEATS := ["darryl_under_blue","general_receipt","bishop_wire","curb_emperor"]
const CLEAR_FLAGS := ["blueTarpCleared","cartKeepCleared","copperChoirCleared","throneDitchCleared"]
const DEFEAT_QUESTS := ["blue_weather","cart_appeal","copper_mass","one_cracklord"]
const RETRIES := {"tarp_boss":"tarp_marks","cart_boss":"cart_marks","wire_boss":"wire_marks","emperor_boss":"emperor_gate"}
var _host_ref: WeakRef
var _progression_ref: WeakRef
var _day_ref: WeakRef
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null

func _init(owner: RefCounted,_spatial: Object = null,progression: RefCounted = null,_travel: Object = null,_communications: Object = null,_recognition: Object = null) -> void:
	_host_ref = weakref(owner)
	_progression_ref = weakref(progression) if progression != null else null
	owner.register_state_normalizer("districtClaims",normalize_claims)
	owner.register_state_normalizer("office",_normalize_owner_office)
	owner.register_state_normalizer("kingdom",_normalize_owner_kingdom)

static func _data(name: String,fallback: Variant = null) -> Variant: return Content.definition(MODULE,name,fallback)
static func _dict(raw: Variant) -> Dictionary: return raw if raw is Dictionary else {}
static func _true(value: Variant) -> bool: return value is bool and value
static func _truthy(value: Variant) -> bool:
	if value == null: return false
	if value is bool: return value
	if value is int or value is float: return not is_nan(float(value)) and float(value) != 0.0
	if value is String: return not value.is_empty()
	return true
static func _number(value: Variant) -> float:
	if value == null: return 0.0
	if value is bool: return 1.0 if value else 0.0
	if value is int or value is float: return float(value)
	if value is String:
		var text: String = value.strip_edges()
		if text.is_empty(): return 0.0
		if text.is_valid_float(): return text.to_float()
		if text.begins_with("0x") or text.begins_with("0X"):
			return float(text.hex_to_int()) if text.is_valid_hex_number(true) else NAN
		if text.begins_with("0b") or text.begins_with("0B"): return _radix(text.substr(2),2)
		if text.begins_with("0o") or text.begins_with("0O"): return _radix(text.substr(2),8)
		return NAN
	if value is Array:
		if value.is_empty(): return 0.0
		if value.size() == 1: return _number(value[0]) if not value[0] is Dictionary and not value[0] is bool else NAN
	return NAN
static func _radix(text: String,base: int) -> float:
	if text.is_empty(): return NAN
	var result: float = 0.0
	for character: String in text:
		var digit: int = "0123456789".find(character)
		if digit < 0 or digit >= base: return NAN
		result = result*base+digit
	return result
static func office_nat(value: Variant,maximum: int = LIMIT) -> int:
	var number: float = _number(value)
	return int(clampf(floor(number),0.0,float(maximum))) if is_finite(number) else 0
static func fresh_office() -> Dictionary:
	var upgrades: Dictionary = {}
	for definition: Dictionary in _data("OFFICE_UPGRADE_DEFS",[]): upgrades[definition.id] = false
	return {"owned":false,"upgrades":upgrades,"claimJob":null,"workJob":null,"workDay":0,"workToday":0,"jobsCompleted":0,"orderSerial":0,"rerollDay":0,"lastWorkId":""}
static func fresh_kingdom() -> Dictionary:
	return {"stage":"locked","marks":0,"bossId":"","defeats":[],"pretenderDay":0,"pretenderDefeatedDay":0,"pretendersDefeated":0}
static func normalize_claims(raw: Variant) -> Dictionary:
	var result: Dictionary = {}
	var source: Dictionary = _dict(raw)
	for definition: Dictionary in _data("CLAIM_SITES",[]):
		if _true(source.get(definition.id)): result[definition.id] = true
	return result
static func normalize_office(raw: Variant,claims: Dictionary) -> Dictionary:
	var source: Dictionary = _dict(raw)
	var result: Dictionary = fresh_office()
	var known: Dictionary = _data("CLAIM_SITE_BY_ID",{})
	result.owned = _truthy(source.get("owned"))
	for id: String in result.upgrades: result.upgrades[id] = _true(_dict(source.get("upgrades")).get(id))
	var claim: Dictionary = _dict(source.get("claimJob"))
	if known.has(claim.get("id")) and claim.get("stage") in ["survey","file","install"] and not _truthy(claims.get(claim.id)):
		result.claimJob = {"id":claim.id,"stage":claim.stage}
	var work: Dictionary = _dict(source.get("workJob"))
	if known.has(work.get("id")) and work.get("stage") in ["inspect","file"] and _truthy(claims.get(work.id)):
		result.workJob = {"id":work.id,"stage":work.stage,"serial":maxi(1,office_nat(work.get("serial")))}
	result.workDay = office_nat(source.get("workDay")); result.workToday = office_nat(source.get("workToday"),3)
	result.jobsCompleted = office_nat(source.get("jobsCompleted"))
	result.orderSerial = maxi(result.jobsCompleted,maxi(office_nat(source.get("orderSerial")),int(result.workJob.serial) if result.workJob is Dictionary else 0))
	result.rerollDay = office_nat(source.get("rerollDay"))
	result.lastWorkId = source.lastWorkId if known.has(source.get("lastWorkId")) else ""
	if result.claimJob != null: result.workJob = null
	var claimed: bool = false
	for definition: Dictionary in _data("CLAIM_SITES",[]):
		if _truthy(claims.get(definition.id)): claimed = true
	if not result.owned:
		result.owned = result.claimJob != null or result.workJob != null or result.jobsCompleted > 0 or claimed
		for value: bool in result.upgrades.values(): result.owned = result.owned or value
	if result.claimJob != null or claimed: result.upgrades.desk = true
	if result.workJob != null or result.jobsCompleted > 0: result.upgrades.radio = true
	if not result.owned:
		for key: String in ["workDay","workToday","orderSerial","rerollDay"]: result[key] = 0
		result.lastWorkId = ""
	return result
static func normalize_kingdom(raw: Variant,demote_boss: bool = false) -> Dictionary:
	var source: Dictionary = _dict(raw)
	var result: Dictionary = fresh_kingdom()
	var ranks: Dictionary = _data("KINGDOM_STAGE_RANK",{})
	result.stage = source.stage if ranks.has(source.get("stage")) else "locked"
	result.marks = office_nat(source.get("marks"),7)
	if source.get("defeats") is Array:
		for id: String in DEFEATS:
			if id in source.defeats: result.defeats.append(id)
	for key: String in ["pretenderDay","pretenderDefeatedDay","pretendersDefeated"]: result[key] = office_nat(source.get(key))
	if demote_boss and RETRIES.has(result.stage):
		result.marks = 0 if result.stage == "emperor_boss" else 7; result.stage = RETRIES[result.stage]
	var rank: int = int(ranks.get(result.stage,0))
	if "curb_emperor" in result.defeats: result.stage = "complete"
	elif "bishop_wire" in result.defeats and rank < ranks.anoint: result.stage = "anoint"
	elif "general_receipt" in result.defeats and rank < ranks.wire_marks: result.stage = "wire_marks"
	elif "darryl_under_blue" in result.defeats and rank < ranks.cart_marks: result.stage = "cart_marks"
	rank = int(ranks.get(result.stage,0))
	for index: int in range(3):
		var minimum: int = [int(ranks.cart_marks),int(ranks.wire_marks),int(ranks.anoint)][index]
		if rank >= minimum and DEFEATS[index] not in result.defeats: result.defeats.append(DEFEATS[index])
	if result.stage == "complete" and "curb_emperor" not in result.defeats: result.defeats.append("curb_emperor")
	var ordered: Array = []
	for id: String in DEFEATS:
		if id in result.defeats: ordered.append(id)
	result.defeats = ordered
	if result.stage not in ["tarp_marks","cart_marks","wire_marks"]: result.marks = 0
	var bosses := {"tarp_boss":"darryl_under_blue","cart_boss":"general_receipt","wire_boss":"bishop_wire","emperor_boss":"curb_emperor"}
	var expected: String = bosses.get(result.stage,"")
	if not demote_boss and not expected.is_empty() and source.get("bossId") == expected: result.bossId = expected
	return result

func _normalize_owner_office(raw: Variant) -> Dictionary: return normalize_office(raw,normalize_claims(host.s.get("districtClaims")))
func _normalize_owner_kingdom(raw: Variant) -> Dictionary: return normalize_kingdom(raw,true)
func bind_day_owner(days: Object) -> void: _day_ref = weakref(days) if days != null else null
func _emit(kind: String,payload: Dictionary = {}) -> void: host.emit_event(kind,payload)
func _toast(text: String,ms: int = 2200) -> void: _emit("toast",{"text":text,"duration_ms":ms})

func reconcile_loaded_state() -> Dictionary:
	if host == null: return {"ok":false,"reason":"missing_owner"}
	var progression: Object = _progression_ref.get_ref() if _progression_ref != null else null
	if progression == null or not progression.has_method(&"maybe_unlock_office"): return {"ok":false,"reason":"missing_progression"}
	host.s.districtClaims = normalize_claims(host.s.get("districtClaims"))
	host.s.office = normalize_office(host.s.get("office"),host.s.districtClaims)
	var office: Dictionary = host.s.office
	office.jobsCompleted = maxi(office_nat(host.p.lifetime.get("officeJobs")),int(office.jobsCompleted))
	office.orderSerial = maxi(int(office.orderSerial),maxi(int(office.jobsCompleted),int(office.workJob.serial) if office.workJob is Dictionary else 0))
	if office.jobsCompleted > 0: office.upgrades.radio = true
	host.p.lifetime.officeJobs = office.jobsCompleted
	var paper_witness: bool = office_nat(host.p.lifetime.get("territoriesClaimed"),11) > 0
	for id: String in ["paper_empire","regional_office","all_business"]: paper_witness = paper_witness or _truthy(_dict(host.s.quests.get(id)).get("done"))
	for id: String in ["zoning_error","regional_office","middle_management","paper_everywhere"]: paper_witness = paper_witness or host.s.achievements.has(id)
	var purchased: bool = office.owned or office.jobsCompleted > 0 or paper_witness or _truthy(_dict(host.s.quests.get("office_space")).get("done")) or host.s.achievements.has("squatters_rights")
	if purchased:
		office.owned = true
		if paper_witness: office.upgrades.desk = true
		if host.s.quests.has("office_space"): host.s.quests.office_space.done = true; host.s.quests.office_space.available = true
		if host.s.quests.has("paper_empire") and not _truthy(host.s.quests.paper_empire.get("done")): host.s.quests.paper_empire.available = true
		if not host.s.achievements.has("squatters_rights"): host.s.achievements.append("squatters_rights")
	host.p.lifetime.territoriesClaimed = claimed_ids().size()
	var raw: Dictionary = _dict(host.s.get("kingdom")).duplicate(true)
	var witnessed: Array = raw.defeats.duplicate() if raw.get("defeats") is Array else []
	var ranks: Dictionary = _data("KINGDOM_STAGE_RANK",{})
	for index: int in range(4):
		if _truthy(_dict(host.s.quests.get(DEFEAT_QUESTS[index])).get("done")) or _truthy(host.s.flags.get(CLEAR_FLAGS[index])):
			if DEFEATS[index] not in witnessed: witnessed.append(DEFEATS[index])
	if host.s.achievements.has("one_cracklord") and "curb_emperor" not in witnessed: witnessed.append("curb_emperor")
	raw.defeats = witnessed
	for pair: Array in [["hostile_correspondence","tarp_marks"],["royal_static","emperor_gate"]]:
		if _truthy(_dict(host.s.quests.get(pair[0])).get("done")) and int(ranks.get(raw.get("stage"),0)) < int(ranks[pair[1]]): raw.stage = pair[1]
	if "curb_emperor" in witnessed: raw.stage = "complete"
	host.s.kingdom = normalize_kingdom(raw,true)
	var pretenders: int = maxi(office_nat(host.p.lifetime.get("pretendersDefeated")),int(host.s.kingdom.pretendersDefeated))
	host.s.kingdom.pretendersDefeated = pretenders; host.p.lifetime.pretendersDefeated = pretenders
	for index: int in range(4): host.s.flags[CLEAR_FLAGS[index]] = _truthy(host.s.flags.get(CLEAR_FLAGS[index])) or DEFEATS[index] in host.s.kingdom.defeats
	for key: String in ["bossNPC","kingdomBattle"]: host.s[key] = null
	host.s.bossActive = false; host.s.bossKind = ""; host.s.bossPhase = 0
	if host.s.office.workDay != host.s.day: host.s.office.workDay = host.s.day; host.s.office.workToday = 0
	progression.call(&"maybe_unlock_office")
	update_office_milestones()
	maybe_unlock_kingdom(true,false)
	sync_quests()
	return {"ok":true,"forces_plan":prepare_day(int(host.s.day)),"needs_force_refresh":true}

func claimed_ids() -> Array[String]:
	var result: Array[String] = []
	for definition: Dictionary in _data("CLAIM_SITES",[]):
		if _true(host.s.districtClaims.get(definition.id)): result.append(definition.id)
	return result
func update_office_milestones(persist: bool = true) -> bool:
	if host == null: return false
	var count: int = claimed_ids().size()
	var changed: bool = host.p.lifetime.get("territoriesClaimed",0) != count
	host.p.lifetime.territoriesClaimed = count
	var quests: Dictionary = host.s.quests
	var first: bool = count >= 1 and quests.has("paper_empire") and not _truthy(quests.paper_empire.get("done"))
	var regional: bool = count >= 4 and quests.has("regional_office") and not _truthy(quests.regional_office.get("done"))
	var all_claims: bool = count >= 11 and quests.has("all_business") and not _truthy(quests.all_business.get("done"))
	var updates: Array = []
	if count >= 1: updates.append_array([["paper_empire","done"],["paper_empire","available"],["regional_office","available"]])
	if count >= 4: updates.append_array([["regional_office","done"],["regional_office","available"],["all_business","available"]])
	if count >= 11: updates.append_array([["all_business","done"],["all_business","available"]])
	for pair: Array in updates:
		if quests.has(pair[0]) and not _true(quests[pair[0]].get(pair[1])): quests[pair[0]][pair[1]] = true; changed = true
	for pair: Array in [[first,"PAPER EMPIRE"],[regional,"REGIONAL OFFICE"],[all_claims,"ALL BUSINESS"]]:
		if pair[0]: _toast("· QUEST COMPLETE ·\n"+pair[1]); _emit("sound",{"id":"rankUp"})
	var earned: Array[String] = []
	for pair: Array in [[1,"zoning_error"],[4,"regional_office"],[8,"middle_management"],[11,"paper_everywhere"]]:
		if count >= pair[0] and not host.s.achievements.has(pair[1]): earned.append(pair[1])
	var definitions: Dictionary = Content.load_content().catalogs.achievements
	var fresh: Array[String] = []
	for id: String in earned:
		if definitions.has(id): host.s.achievements.append(id); changed = true; fresh.append(id)
	if not fresh.is_empty():
		_toast("· ACHIEVEMENT ·\n"+str(definitions[fresh[-1]].name)+("\n%d office records reconciled." % fresh.size() if fresh.size() > 1 else ""),3000)
		_emit("sound",{"id":"rankUp"})
	if changed and persist: _emit("save_requested")
	return changed
func maybe_unlock_kingdom(persist: bool = true,announce: bool = true) -> bool:
	if host == null: return false
	var normalized: Dictionary = normalize_kingdom(host.s.kingdom)
	var amount: int = maxi(office_nat(host.p.lifetime.get("pretendersDefeated")),int(normalized.pretendersDefeated))
	normalized.pretendersDefeated = amount; host.p.lifetime.pretendersDefeated = amount; host.s.kingdom = normalized
	if normalized.stage != "locked" or not host.s.office.get("owned",false) or claimed_ids().size() < 4 or not _truthy(_dict(host.s.quests.get("fallen_king")).get("done")): return false
	normalized.stage = "summons"; normalized.marks = 0
	if host.s.quests.has("hostile_correspondence"): host.s.quests.hostile_correspondence.available = true
	if announce:
		_toast("· HOSTILE CORRESPONDENCE ·\na radio frequency has billed your curb.\nthe office has the envelope.",4200)
		_emit("feed",{"text":"regional office received a kingdom notice. postage due.","author":"@blocklog"})
	if persist: _emit("save_requested")
	return true
func sync_quests() -> void:
	if host == null: return
	var kingdom: Dictionary = _dict(host.s.get("kingdom"))
	var rank: int = int(_data("KINGDOM_STAGE_RANK",{}).get(kingdom.get("stage"),0))
	var defeats: Array = kingdom.get("defeats",[])
	var pairs := [["hostile_correspondence",rank >= 1,rank >= 2],["blue_weather",rank >= 2,"darryl_under_blue" in defeats],["cart_appeal",rank >= 4,"general_receipt" in defeats],["copper_mass",rank >= 6,"bishop_wire" in defeats],["royal_static",rank >= 8,rank >= 9],["one_cracklord",rank >= 9,kingdom.get("stage") == "complete"]]
	for row: Array in pairs:
		if host.s.quests.has(row[0]): host.s.quests[row[0]].available = row[1]; host.s.quests[row[0]].done = row[2]

static func _actor(definition: Dictionary,point: Dictionary,extra: Dictionary) -> Dictionary:
	var hp: int = int(extra.get("hp",55))
	var result := {"id":extra.id,"name":extra.get("name",definition.get("guardName","")),"sprite":extra.get("sprite",definition.get("guardSprite","")),"x":float(point.x)-16,"y":float(point.y)-16,"w":32,"h":32,"color":"#3a3028","hp":hp,"maxHp":hp,"speed":extra.get("speed",1.35),"dmg":extra.get("dmg",7),"hostile":true,"aggro":_true(extra.get("aggro")),"showHp":_truthy(extra.get("showHp")),"archetype":extra.get("archetype","charger"),"attackCd":0,"wanderT":0,"targetX":point.x,"targetY":point.y,"zoneOnly":definition.zoneOnly.duplicate(true),"kingdomClan":definition.get("id",extra.get("kingdomClan","")),"transient":true,"noComboReward":true}
	result.merge(extra,true)
	return result
func prepare_day(next_day: int) -> Dictionary:
	if host == null: return {"ok":false,"reason":"invalid_day"}
	return plan_for_state(next_day,host.s.get("kingdom"),host.p.lifetime.get("pretendersDefeated"))

static func plan_for_state(next_day: int,raw_kingdom: Variant,lifetime_pretenders: Variant) -> Dictionary:
	if next_day < 1 or next_day > LIMIT: return {"ok":false,"reason":"invalid_day"}
	var kingdom: Dictionary = normalize_kingdom(raw_kingdom)
	var pretenders: int = maxi(office_nat(lifetime_pretenders),int(kingdom.pretendersDefeated))
	kingdom.pretendersDefeated = pretenders
	var actors: Array[Dictionary] = []
	var clans: Array = _data("KINGDOM_CLAN_LIST",[])
	var posts: Dictionary = _data("KINGDOM_GUARD_POSTS",{})
	var emperor: Dictionary = _data("KINGDOM_EMPEROR",{})
	if clans.size() != 3 or posts.size() != 4 or emperor.is_empty(): return {"ok":false,"reason":"missing_definitions"}
	for clan: Dictionary in clans:
		if kingdom.stage == clan.bossStage: continue
		var defeated: bool = clan.bossId in kingdom.defeats
		for index: int in range(2 if defeated else 4):
			actors.append(_actor(clan,posts[clan.id][index],{"id":"kingdom_guard_%s_%d_%d" % [clan.id,next_day,index],"name":clan.guardName,"sprite":clan.guardSprite,"hp":48 if defeated else 58,"dmg":7,"speed":1.25,"archetype":"ranged" if index%3 == 2 else ("swarmer" if index%2 == 1 else "charger"),"kingdomGuard":true,"transient":false}))
	if kingdom.stage != "emperor_boss":
		var sprites := ["blue_tarp_guard","receipt_guard","wire_guard"]
		for index: int in range(2 if kingdom.stage == "complete" else 3):
			var definition := {"id":"throne","guardName":"KNIGHT EMERITUS","guardSprite":sprites[index%3],"zoneOnly":emperor.zoneOnly}
			actors.append(_actor(definition,posts.throne[index],{"id":"kingdom_guard_throne_%d_%d" % [next_day,index],"name":"KNIGHT EMERITUS","sprite":sprites[index%3],"hp":52,"dmg":7,"speed":1.25,"archetype":"ranged" if index == 2 else "charger","kingdomGuard":true,"kingdomClan":"throne","transient":false}))
	if kingdom.stage == "complete" and kingdom.pretenderDefeatedDay != next_day:
		var index: int = next_day%clans.size(); var clan: Dictionary = clans[index]
		kingdom.pretenderDay = next_day
		actors.append(_actor(clan,clan.boss,{"id":"curb_pretender_%d" % next_day,"name":"CURB PRETENDER No. %d" % (pretenders+1),"sprite":clan.guardSprite,"hp":100,"dmg":9,"speed":1.45,"archetype":"ranged" if index == 2 else ("grabber" if index == 1 else "charger"),"showHp":true,"kingdomPretender":true,"kingdomClan":clan.id,"transient":false}))
	return {"ok":true,"day":next_day,"kingdom":kingdom,"pretenders_defeated":pretenders,"actors":actors}
func refresh_forces() -> bool:
	var days: Object = _day_ref.get_ref() if _day_ref != null else null
	if host == null or days == null or not days.has_method(&"replace_campaign_forces"): return false
	var plan: Dictionary = prepare_day(int(host.s.day))
	return plan.ok and days.call(&"replace_campaign_forces",plan) == true
