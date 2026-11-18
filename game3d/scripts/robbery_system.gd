class_name RockBottomRobbery
extends RefCounted
## Source sink, sharing the one model clock/RNG/resources/save event stream.
const COOLDOWN_MS := 60000.0
const DAILY_CAP := 2
const INVENTORY_IDS := ["junk","food","soap","detergent","cone","gold_tooth","lottery","license"]
const SLOTS := ["coat","hat","shoes"]
const EQUIP_IDS := ["trench","windbreaker","bathrobe","parka","mesh_cap","ski_mask","helmet","cowboy","crocs","walmart_sneak","vibrams","airpods"]
const BEATS := {"coat":"he does not put it on.\nhe just holds it.","hat":"he checks the size.\nhe says nothing.","shoes":"he holds them by the laces."}
var _host_ref: WeakRef
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null

func _init(owner: RefCounted) -> void: _host_ref = weakref(owner)
func clock_ms() -> float: return (float(host.s.day)+float(host.s.dayTime))*240000.0
func ready() -> bool:
	return host != null and host.s.counters.get("robberiesToday",0) < DAILY_CAP and clock_ms()-float(host.s.counters.get("robLastClockMs",0)) >= COOLDOWN_MS

func attempt(actor: Dictionary) -> bool:
	if actor.is_empty() or not actor.get("robs",false) or actor.get("dead",false) or not ready(): return false
	var candidates: Array[Dictionary] = []
	for slot: String in SLOTS:
		var id: Variant = host.p.equip.get(slot)
		if id in EQUIP_IDS: candidates.append({"kind":"equip","slot":slot,"id":id})
	for index: int in host.p.inventory.size():
		if host.p.inventory[index].get("id") in INVENTORY_IDS: candidates.append({"kind":"item","index":index})
	if host.p.hitters > 0: candidates.append({"kind":"hitter"})
	if host.p.cash > 0: candidates.append({"kind":"cash"})
	host.s.counters.robLastClockMs = clock_ms()
	host.s.counters.robberiesToday = host.s.counters.get("robberiesToday",0)+1
	var text: String
	var duration: int = 3200
	var post: String = ""
	var name: String = str(actor.get("name",""))
	if candidates.is_empty(): text = name+" checks your pockets.\nfinds a receipt.\nkeeps the receipt."
	else:
		var pick: Dictionary = candidates[host.random_index(candidates.size())]
		match pick.kind:
			"equip":
				var label: String = str(host.content.catalogs.equipment.get(pick.id,{}).get("n",pick.id))
				host.p.equip[pick.slot] = null
				host.apply_equip_stats()
				text = "- "+label+"\n"+name+" takes your "+pick.slot+".\n"+BEATS[pick.slot]
				duration = 3600
				post = "lurch is holding somebody's "+pick.slot+" on skid row. just holding it."
			"item":
				var item: Dictionary = host.p.inventory[pick.index]
				if item.get("q",1) > 1: item.q -= 1
				else: host.p.inventory.remove_at(pick.index)
				text = "- "+str(item.n)+"\n"+name+" takes it.\nhe does not ask what it is. neither did you."
			"hitter":
				host.p.hitters -= 1
				text = "- the emergency hitter\n"+name+" takes the pipe.\nhe knows what it is."
			"cash":
				var amount: int = mini(host.p.cash,5+host.random_index(11))
				host.p.cash -= amount
				text = "- $%d\n%s counts it in front of you.\nthe math is correct." % [amount,name]
	host.emit_event("toast",{"text":text,"duration_ms":duration})
	if not post.is_empty(): host.emit_event("feed",{"text":post,"author":"@local_eyewitness"})
	host.emit_event("save_requested")
	return true
