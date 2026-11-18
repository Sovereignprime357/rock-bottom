extends "res://scripts/hud.gd"
## Pure full-model view. No gameplay timers, resources, transactions or save ownership.
const Content = preload("res://scripts/content_catalog.gd")
var menu_scroll: ScrollContainer
var feed_panel: PanelContainer
var feed_scroll: ScrollContainer
var feed_copy: Label
var ticker: Label
var _feed_requested: bool = false
var _guidance_ref: WeakRef
var _guidance_elapsed: float = 0.0
var _guidance_playing: bool = false
var _view_heading: float = 0.0
var _loop_status: Label
var _objective_plate: Panel
var guidance_map: GuidanceMap
var guidance_refresh_count: int = 0
var _receipt_default_offsets := Vector4.ZERO

class GuidanceMap:
	extends Control
	var static_commands: Array = []
	var dynamic_view: Dictionary = {}
	var heading: float = 0.0
	func _draw() -> void:
		if static_commands.is_empty(): return
		var scale_xy := Vector2(size.x/120.0,size.y/96.0)
		draw_set_transform(Vector2.ZERO,0.0,scale_xy)
		for commands: Array in [static_commands,dynamic_view.get("commands",[])]:
			for command: Dictionary in commands:
				var values: Array = command.values; var color := Color(str(command.color)); var width: float = float(command.width)
				if command.op == "line": draw_line(Vector2(values[0],values[1]),Vector2(values[2],values[3]),color,width)
				elif command.op == "fill": draw_rect(Rect2(values[0],values[1],values[2],values[3]),color)
				else: draw_rect(Rect2(values[0],values[1],values[2],values[3]),color,false,width)
		if dynamic_view.has("player"):
			var player := Vector2(dynamic_view.player[0],dynamic_view.player[1]); var forward := Vector2(-sin(heading),-cos(heading)); var side := Vector2(-forward.y,forward.x)
			draw_colored_polygon(PackedVector2Array([player+forward*5.0,player-forward*2.0+side*2.0,player-forward*2.0-side*2.0]),Color("e8c040"))

func _ready() -> void:
	super._ready()
	_receipt_default_offsets = Vector4(receipt.offset_left,receipt.offset_top,receipt.offset_right,receipt.offset_bottom)
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
	_loop_status = _label("",18); root.add_child(_loop_status); _loop_status.position = Vector2(32,55)
	_objective_plate = Panel.new(); root.add_child(_objective_plate)
	_objective_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_plate.add_theme_stylebox_override("panel",_style(Color(0.06,0.065,0.045,0.82),Color("5c5942"),1))
	root.move_child(_objective_plate,root.get_children().find(objective))
	_objective_plate.hide()
	guidance_map = GuidanceMap.new(); root.add_child(guidance_map)
	guidance_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guidance_map.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	guidance_map.offset_left = -260; guidance_map.offset_right = -20
	guidance_map.offset_top = -246; guidance_map.offset_bottom = -54; guidance_map.hide()
	get_viewport().size_changed.connect(_fit_guidance)
	if _guidance_ref != null: _configure_guidance()

func bind_guidance(view: RefCounted) -> void:
	_guidance_ref = weakref(view) if view != null else null
	_guidance_elapsed = 0.0
	if guidance_map != null: _configure_guidance()
func _configure_guidance() -> void:
	var view: Object = _guidance_ref.get_ref() if _guidance_ref != null else null
	guidance_map.static_commands = view.map_static() if view != null else []
	if view != null:
		objective.add_theme_font_size_override("font_size",16)
		objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		receipt.offset_left = -680; receipt.offset_right = -280
		_fit_guidance(); _refresh_guidance()
	else:
		objective.position = Vector2(32,55); objective.autowrap_mode = TextServer.AUTOWRAP_OFF
		objective.add_theme_font_size_override("font_size",18); _objective_plate.hide(); guidance_map.hide(); _loop_status.hide()
		objective.visible = _guidance_playing
		receipt.offset_left = _receipt_default_offsets.x; receipt.offset_top = _receipt_default_offsets.y
		receipt.offset_right = _receipt_default_offsets.z; receipt.offset_bottom = _receipt_default_offsets.w
func set_view_heading(yaw: float) -> void:
	if not is_finite(yaw): return
	_view_heading = wrapf(yaw,-PI,PI)
	if guidance_map != null: guidance_map.heading = _view_heading
func _fit_guidance() -> void:
	if _guidance_ref == null or _objective_plate == null: return
	var available: float = get_viewport().get_visible_rect().size.x-(400.0 if _feed_requested else 64.0)
	var width: float = clampf(available,280.0,800.0)
	objective.position = Vector2(32,119); objective.size = Vector2(width,66)
	_objective_plate.position = Vector2(20,111); _objective_plate.size = Vector2(width+24,82)
func _refresh_guidance() -> void:
	var view: Object = _guidance_ref.get_ref() if _guidance_ref != null else null
	if view == null or not view.ready():
		if guidance_map != null: guidance_map.hide()
		if _objective_plate != null: _objective_plate.hide()
		objective.hide()
		return
	var current: Dictionary = view.objective_view(_view_heading)
	var bearing: float = float(current.get("bearing",0.0))
	var facing: String = ["ahead","right","behind","left"][posmod(int(floor(bearing/(PI/2.0)+0.5)),4)]
	objective.text = "BAD IDEA · "+str(current.get("text",""))+"\n"+("HERE" if current.get("here",false) else "%d paces · %s" % [current.get("paces",1),facing])
	objective.modulate = CREAM
	guidance_map.dynamic_view = view.map_dynamic(); guidance_map.heading = _view_heading; guidance_map.queue_redraw()
	guidance_refresh_count += 1
func _process(delta: float) -> void:
	super._process(delta)
	if not _guidance_playing or _guidance_ref == null: return
	_guidance_elapsed += delta
	if _guidance_elapsed < 0.12: return
	_guidance_elapsed = 0.0; _refresh_guidance()

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
	_guidance_playing = s.mode == "playing"
	feed_panel.visible = _feed_requested and s.mode == "playing"
	ticker.visible = s.mode == "playing"
	var guidance: Object = _guidance_ref.get_ref() if _guidance_ref != null else null
	var has_guidance: bool = guidance != null and guidance.ready()
	var bound_guidance: bool = _guidance_ref != null
	_objective_plate.visible = has_guidance and _guidance_playing
	guidance_map.visible = has_guidance and _guidance_playing
	_loop_status.visible = has_guidance and _guidance_playing
	objective.visible = _guidance_playing and (not bound_guidance or has_guidance)
	var zone: Dictionary = runtime.progression.current_zone()
	status.text = "%s  /  DAY %d" % [str(zone.get("name",zone.get("id","THE BLOCK"))).to_upper(),int(s.day)]
	pocket.text = "$%d  ·  rocks %d  ·  copper %d\nbrain %d  ·  cred %d  ·  wanted %d" % [p.cash,int(p.rocks)+int(p.soapRocks),p.copper,p.brain,p.cred,p.wanted]
	health.max_value = float(p.maxHp); health.value = float(p.hp)
	shakes.value = float(p.shakes)
	var loop_label: Label = _loop_status if bound_guidance else objective
	if float(p.rockedT) > 0:
		loop_label.text = "%s   %.1fs" % ["THE EMERGENCY HITTER" if p.hitterHigh else "ROCKED UP",float(p.rockedT)/1000.0]
		loop_label.modulate = GOLD; tint.color = Color(0.8,0.61,0.12,0.035)
	elif float(p.crashT) > 0:
		loop_label.text = "THE CRASH   %.1fs" % (float(p.crashT)/1000.0)
		loop_label.modulate = Color("d488d4"); tint.color = Color(0.35,0.17,0.36,0.09)
	else:
		loop_label.modulate = CREAM; tint.color = Color(0,0,0,0)
		if bound_guidance: loop_label.text = "[Q] bad ideas"
		elif int(p.rocks)+int(p.soapRocks) > 0:
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
	var previous: bool = _feed_requested
	_feed_requested = snapshot.get("visible",false)
	if previous != _feed_requested: _fit_guidance()
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
