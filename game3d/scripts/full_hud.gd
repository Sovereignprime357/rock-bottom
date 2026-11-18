extends "res://scripts/hud.gd"
## Pure full-model view. No timers, resources, transactions or save ownership.
const Content = preload("res://scripts/content_catalog.gd")
var menu_scroll: ScrollContainer
var feed_panel: PanelContainer
var feed_scroll: ScrollContainer
var feed_copy: Label
var ticker: Label
var _feed_requested: bool = false

func _ready() -> void:
	super._ready()
	var margin: Node = menu_box.get_parent()
	margin.remove_child(menu_box)
	menu_scroll = ScrollContainer.new()
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.custom_minimum_size = Vector2(520,520)
	margin.add_child(menu_scroll)
	menu_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_scroll.add_child(menu_box)
	get_viewport().size_changed.connect(_fit_menu)
	menu_box.minimum_size_changed.connect(_fit_menu)
	_fit_menu()
	pocket.offset_left = -490
	pocket.offset_right = -32
	pocket.add_theme_font_size_override("font_size",16)
	for child: Node in root.get_children():
		if child is Panel and child.anchor_left == 1.0:
			child.offset_left = -508; child.offset_right = -20
	feed_panel = PanelContainer.new(); root.add_child(feed_panel)
	feed_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	feed_panel.offset_left = -338; feed_panel.offset_right = -20
	feed_panel.offset_top = 104; feed_panel.offset_bottom = 490
	feed_panel.add_theme_stylebox_override("panel",_style(Color(0.075,0.08,0.06,0.95),Color("777044"),1))
	feed_scroll = ScrollContainer.new(); feed_panel.add_child(feed_scroll)
	feed_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	feed_scroll.custom_minimum_size = Vector2(286,350)
	feed_copy = _label("",15); feed_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feed_copy.custom_minimum_size.x = 270; feed_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feed_scroll.add_child(feed_copy); feed_panel.hide()
	ticker = _label("",13,Color("a79e75")); root.add_child(ticker)
	ticker.position = Vector2(32,89); ticker.size = Vector2(620,20); ticker.clip_text = true

func _fit_menu() -> void:
	var maximum: float = clampf(get_viewport().get_visible_rect().size.y-150.0,300.0,560.0)
	menu_scroll.custom_minimum_size.y = clampf(menu_box.get_combined_minimum_size().y,160.0,maximum)

func menu(title: String,body: String,options: Array,big: bool = false) -> void:
	super.menu(title,body,options,big)
	menu_scroll.scroll_vertical = 0
	call_deferred("_fit_menu")

func update_runtime(runtime: RefCounted) -> void:
	var p: Dictionary = runtime.p
	var s: Dictionary = runtime.s
	feed_panel.visible = _feed_requested and s.mode == "playing"
	ticker.visible = s.mode == "playing"
	var zone: Dictionary = runtime.progression.current_zone()
	status.text = "%s  /  DAY %d" % [str(zone.get("name",zone.get("id","THE BLOCK"))).to_upper(),int(s.day)]
	pocket.text = "$%d  ·  rocks %d  ·  copper %d\nbrain %d  ·  cred %d  ·  wanted %d" % [p.cash,int(p.rocks)+int(p.soapRocks),p.copper,p.brain,p.cred,p.wanted]
	health.max_value = float(p.maxHp); health.value = float(p.hp)
	shakes.value = float(p.shakes)
	if float(p.rockedT) > 0:
		objective.text = "%s   %.1fs" % ["THE EMERGENCY HITTER" if p.hitterHigh else "ROCKED UP",float(p.rockedT)/1000.0]
		objective.modulate = GOLD; tint.color = Color(0.8,0.61,0.12,0.035)
	elif float(p.crashT) > 0:
		objective.text = "THE CRASH   %.1fs" % (float(p.crashT)/1000.0)
		objective.modulate = Color("d488d4"); tint.color = Color(0.35,0.17,0.36,0.09)
	else:
		objective.modulate = CREAM; tint.color = Color(0,0,0,0)
		if int(p.rocks)+int(p.soapRocks) > 0:
			var spot: Dictionary = runtime.memory.bad_idea_spot(runtime.state.player_center())
			objective.text = "BAD IDEA   %s" % str(spot.get("feedName","the block"))
		elif int(p.cash) >= runtime.state.vendor_price(9 if int(p.faction.street) >= 10 else 10):
			objective.text = "BAD IDEA   tre bag tony."
		else: objective.text = "BAD IDEA   find ten dollars."

func activate_choice(index: int) -> bool:
	if not modal.visible or index < 0 or index > 8: return false
	var current: int = 0
	for child: Node in menu_box.get_children():
		if not child is Button: continue
		if current == index:
			if child.disabled or not child.is_visible_in_tree(): return false
			child.pressed.emit(); return true
		current += 1
	return false

func update_communications(snapshot: Dictionary) -> void:
	_feed_requested = snapshot.get("visible",false)
	ticker.text = str(snapshot.get("news_text",""))
	var lines: Array[String] = ["THE FEED    [P]",""]
	for post: Dictionary in snapshot.get("posts",[]):
		lines.append(str(post.h)+"\n"+str(post.t)+"\n")
	feed_copy.text = "\n".join(lines)
	feed_scroll.scroll_vertical = 0
	feed_panel.visible = snapshot.get("displayed",false)

func scroll_feed(direction: int) -> void:
	if feed_panel.visible: feed_scroll.scroll_vertical += direction*48

func inventory_copy(runtime: RefCounted) -> String:
	var p: Dictionary = runtime.p
	var s: Dictionary = runtime.s
	var ranks: Array = Content.definition("src/data/world.js","RANKS",[])
	var rank_name: String = str(ranks[clampi(int(p.rank),0,ranks.size()-1)].name) if not ranks.is_empty() else ""
	var lines: Array[String] = [rank_name,"cash $%d · rocks %d · pure copper %d" % [p.cash,int(p.rocks)+int(p.soapRocks),p.copper],
		"raw supplies %d · house cut %d · hitters %d" % [p.supplies,p.dirtySupplies,p.hitters],
		"body %d/%d · shakes %d · brain %d" % [p.hp,p.maxHp,p.shakes,p.brain],"", "equipment"]
	lines.append("weapon: " + str(runtime.state.content.catalogs.weapons.get(p.weapon,{}).get("n",p.weapon)))
	for slot: String in ["hat","coat","shoes","tool"]:
		lines.append(slot+": "+str(runtime.state.content.catalogs.equipment.get(p.equip.get(slot),{}).get("n","(none)")))
	lines.append("\nitems")
	if p.inventory.is_empty(): lines.append("nothing (yet)")
	for item: Dictionary in p.inventory: lines.append("%s ×%d" % [item.get("n",item.id),item.get("q",1)])
	lines.append("\nlifetime")
	for key: String in ["rocksSmoked","rocksCooked","rocksFenced","routesCompleted","officeJobs","territoriesClaimed","copsKilled","arrests"]:
		lines.append("%s: %d" % [key.to_snake_case().replace("_"," "),p.lifetime.get(key,0)])
	lines.append("day %d · %s\n\ncursed accolades %d/%d" % [s.day,s.weather,s.achievements.size(),runtime.state.content.catalogs.achievements.size()])
	for id: String in runtime.state.content.catalogs.achievements:
		var entry: Dictionary = runtime.state.content.catalogs.achievements[id]
		lines.append(("✓ " if s.achievements.has(id) else "· ")+str(entry.name)+" — "+str(entry.flav))
	return "\n".join(lines)
