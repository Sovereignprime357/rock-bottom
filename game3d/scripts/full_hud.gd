extends "res://scripts/hud.gd"
## Pure full-model view. No gameplay timers, resources, transactions or save ownership.
const Content = preload("res://scripts/content_catalog.gd")
const GuideProjection = preload("res://scripts/guidance_projection.gd")
const ActorHud = preload("res://scripts/actor_hud_overlay.gd")
const DistrictBorder = preload("res://scripts/district_border_view.gd")
const DistrictGrade = preload("res://scripts/district_grade.gd")
const DistrictGradeView = preload("res://scripts/district_grade_view.gd")
var district_border: Control
var district_grade: ColorRect
var _status_plate: Panel
var _pocket_plate: Panel
var actor_overlay: Control
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
var _guidance_camera_ref: WeakRef
var _guidance_visibility: Callable
var _last_objective: Dictionary = {}
var _target_visibility: int = -1
var guidance_overlay: GuidanceOverlay
var guidance_projection_count: int = 0

class GuidanceOverlay:
	extends Control
	var marker: Dictionary = {}
	func _draw() -> void:
		if marker.is_empty(): return
		var color := Color("e8c040")
		if marker.kind == "arrow":
			color.a = float(marker.arrow_alpha)
			draw_set_transform(marker.center,float(marker.angle))
			draw_colored_polygon(PackedVector2Array(marker.arrow),color)
			return
		color.a = float(marker.alpha)
		if marker.dashed:
			for index: int in range(12):
				var start: float = float(index)*TAU/12.0
				draw_arc(marker.center,float(marker.radius),start,start+TAU/20.0,5,color,float(marker.width),true)
		else: draw_arc(marker.center,float(marker.radius),0.0,TAU,48,color,float(marker.width),true)
		if marker.square: draw_rect(Rect2(marker.square_position,Vector2.ONE*float(marker.square_size)),Color("e8c040"))

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
	var grade_model := DistrictGrade.new(Content.load_content().world)
	district_grade = DistrictGradeView.new(grade_model)
	district_grade.name = "DistrictGrade"
	root.add_child(district_grade); root.move_child(district_grade,0)
	district_grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
			_pocket_plate = child
		elif child is Panel and child.anchor_left == 0.0 and child.offset_top == 16.0:
			_status_plate = child
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
	guidance_overlay = GuidanceOverlay.new(); root.add_child(guidance_overlay)
	guidance_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	guidance_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE; guidance_overlay.hide()
	# Informational marker stays below every HUD control, even on compact viewports.
	root.move_child(guidance_overlay,root.get_children().find(tint)+1)
	actor_overlay = ActorHud.new(); root.add_child(actor_overlay)
	actor_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.move_child(actor_overlay,root.get_children().find(guidance_overlay)+1)
	district_border = DistrictBorder.new(); root.add_child(district_border)
	district_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.move_child(district_border,root.get_children().find(tint)+1)
	get_viewport().size_changed.connect(_fit_guidance)
	get_viewport().size_changed.connect(_fit_header)
	_fit_header()
	if _guidance_ref != null: _configure_guidance()

func _fit_header() -> void:
	var available: float = maxf(300.0,get_viewport().get_visible_rect().size.x-60.0)
	var left_width: float = minf(510.0,available*0.48)
	var right_width: float = minf(488.0,available*0.52)
	if _status_plate != null: _status_plate.offset_right = 20.0+left_width
	if _pocket_plate != null: _pocket_plate.offset_left = -20.0-right_width
	pocket.offset_left = -8.0-right_width
	status.size.x = left_width-24.0; status.clip_text = true
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if _loop_status != null:
		_loop_status.size.x = left_width-24.0; _loop_status.clip_text = true
		_loop_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func bind_actor_hud(state: RefCounted,camera: Camera3D,anchor: Callable,sight: Callable) -> bool:
	return actor_overlay != null and actor_overlay.bind_model(state,camera,anchor,sight)

func actor_hud_occupied_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for node: Node in root.get_children():
		if not node is Control or not node.is_visible_in_tree() or node in [tint,actor_overlay,guidance_overlay,district_border,district_grade]: continue
		# Modal's full-screen CenterContainer is only layout, not an occupied plate.
		if node is CenterContainer: continue
		if node is Label and node.text.is_empty(): continue
		var rect: Rect2 = (node as Control).get_global_rect()
		if rect.has_area(): result.append(rect)
	if modal.visible: result.append(modal.get_global_rect())
	return result

func update_actor_hud(visual_ms: float) -> void:
	if actor_overlay != null: actor_overlay.update_frame(visual_ms,actor_hud_occupied_rects())

func bind_guidance(view: RefCounted) -> void:
	_guidance_ref = weakref(view) if view != null else null
	_guidance_elapsed = 0.0
	_last_objective.clear(); _target_visibility = -1
	if guidance_overlay != null: guidance_overlay.marker = {}; guidance_overlay.hide()
	if guidance_map != null: _configure_guidance()
func bind_guidance_camera(camera: Camera3D) -> void:
	_guidance_camera_ref = weakref(camera) if camera != null else null
	_target_visibility = -1
	if guidance_overlay != null: guidance_overlay.marker = {}; guidance_overlay.hide()
func bind_guidance_visibility(callback: Callable) -> void:
	_guidance_visibility = callback; _target_visibility = -1
func guidance_safe_rect() -> Rect2:
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var left: float = 24.0; var right: float = viewport.x-(362.0 if _feed_requested else 24.0)
	var top: float = minf(220.0,viewport.y*0.42); var bottom: float = viewport.y-264.0
	return Rect2(left,top,maxf(0.0,right-left),maxf(0.0,bottom-top))
func _target_world() -> Vector3:
	if not _last_objective.has("x") or not _last_objective.has("y"): return Vector3.INF
	return Content.to_world(Vector2(float(_last_objective.x),float(_last_objective.y)),0.08)
func _sample_guidance_visibility() -> void:
	_target_visibility = -1
	var camera: Camera3D = _guidance_camera_ref.get_ref() if _guidance_camera_ref != null else null
	var target: Vector3 = _target_world()
	if not _guidance_playing or camera == null or not target.is_finite() or not _guidance_visibility.is_valid(): return
	var result: Variant = _guidance_visibility.call(target)
	if result is bool: _target_visibility = 1 if result else 0
func _project_guidance() -> void:
	if guidance_overlay == null: return
	var camera: Camera3D = _guidance_camera_ref.get_ref() if _guidance_camera_ref != null else null
	if not _guidance_playing or camera == null or not camera.is_inside_tree() or _last_objective.is_empty():
		guidance_overlay.marker = {}; guidance_overlay.hide(); return
	guidance_overlay.marker = GuideProjection.project(_target_world(),camera.global_transform,camera.get_camera_projection(),get_viewport().get_visible_rect().size,guidance_safe_rect(),float(Time.get_ticks_msec()),_target_visibility)
	guidance_overlay.visible = not guidance_overlay.marker.is_empty()
	guidance_overlay.queue_redraw(); guidance_projection_count += 1
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
		_last_objective.clear(); _target_visibility = -1
		if guidance_overlay != null: guidance_overlay.marker = {}; guidance_overlay.hide()
		return
	var current: Dictionary = view.objective_view(_view_heading)
	_last_objective = current.duplicate(true)
	var bearing: float = float(current.get("bearing",0.0))
	var facing: String = ["ahead","right","behind","left"][posmod(int(floor(bearing/(PI/2.0)+0.5)),4)]
	objective.text = "BAD IDEA · "+str(current.get("text",""))+"\n"+("HERE" if current.get("here",false) else "%d paces · %s" % [current.get("paces",1),facing])
	objective.modulate = CREAM
	guidance_map.dynamic_view = view.map_dynamic(); guidance_map.heading = _view_heading; guidance_map.queue_redraw()
	_sample_guidance_visibility()
	guidance_refresh_count += 1
func _process(delta: float) -> void:
	super._process(delta)
	if not _guidance_playing or _guidance_ref == null:
		if guidance_overlay != null: guidance_overlay.hide()
		return
	_guidance_elapsed += delta
	if _guidance_elapsed >= 0.12: _guidance_elapsed = 0.0; _refresh_guidance()
	_project_guidance()

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
	district_grade.sync(float(p.x)+float(p.w)*0.5,float(p.y)+float(p.h)*0.5,str(s.mode))
	var border_rect: Variant = s.get("borderGlowRect",{})
	district_border.sync({"remaining_ms":s.get("borderGlowT",0),"color":s.get("borderGlowColor",""),"visible":s.mode != "title" and border_rect is Dictionary and not border_rect.is_empty()})
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
	if not _guidance_playing or not has_guidance: guidance_overlay.hide()
	if not has_guidance: _last_objective.clear(); _target_visibility = -1
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
	var lines: Array[String] = [rank_name,"cash $%d · rocks %d · pure copper %d" % [p.cash,int(p.rocks)+int(p.soapRocks),p.copper]]
	if p.hitters > 0: lines.append("emergency hitter %d" % p.hitters)
	lines.append("raw supplies %d" % p.supplies+(" (%d house cut)" % p.dirtySupplies if p.dirtySupplies > 0 else ""))
	lines.append("hp %d / %d · shakes %d · brain %d" % [floori(float(p.hp)+0.5),p.maxHp,floori(float(p.shakes)+0.5),floori(float(p.brain)+0.5)])
	lines.append("cred %d" % p.cred+(" (+%d)" % p.credBonus if p.credBonus != 0 else ""))
	lines.append("wanted "+("★".repeat(int(p.wanted)) if p.wanted > 0 else "-"))
	lines.append("cart "+("mounted" if p.cartMounted else "-"))
	lines.append("\nequipment")
	lines.append("weapon: " + str(runtime.state.content.catalogs.weapons.get(p.weapon,{}).get("n",p.weapon)))
	for slot: String in ["hat","coat","shoes","tool"]:
		lines.append(slot+": "+str(runtime.state.content.catalogs.equipment.get(p.equip.get(slot),{}).get("n","(none)")))
	lines.append("\nitems")
	if p.inventory.is_empty(): lines.append("nothing (yet)")
	for item: Dictionary in p.inventory: lines.append("%s ×%d" % [item.get("n",item.id),item.get("q",1)])
	lines.append("\nlifetime")
	var lifetime_labels := {"rocksSmoked":"rocks smoked","rocksCooked":"rocks cooked","rocksFenced":"rocks fenced","routesCompleted":"block routes filed","officeJobs":"office orders filed","territoriesClaimed":"districts entered","copsKilled":"cops killed","arrests":"arrests"}
	for key: String in lifetime_labels:
		var denominator: String = "/%d" % Content.definition("src/systems/campaigns.js","CLAIM_SITES",[]).size() if key == "territoriesClaimed" else ""
		lines.append("%s: %d%s" % [lifetime_labels[key],p.lifetime.get(key,0),denominator])
	lines.append("day %d · %s\n\ncursed accolades %d/%d" % [s.day,s.weather,s.achievements.size(),runtime.state.content.catalogs.achievements.size()])
	for id: String in runtime.state.content.catalogs.achievements:
		var entry: Dictionary = runtime.state.content.catalogs.achievements[id]
		lines.append(("✓ " if s.achievements.has(id) else "· ")+str(entry.name)+" — "+str(entry.flav))
	return "\n".join(lines)
