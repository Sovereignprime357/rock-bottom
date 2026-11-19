extends RefCounted
## Diagnostic only. No gameplay/pose/resource owner references.
const MAX_DEPTH := 16
const HELPERS: Array[String] = ["reset","apply","attachments","contacts"]
static var times: Dictionary = {}
static var counts: Dictionary = {}
static var frames: Array[Dictionary] = []
static var depth: int = 0

static func _prepare() -> void:
	if not times.is_empty(): return
	for key: String in ["tick_root_inclusive","tick_all_rigs_inclusive","tick_exclusive","tick_direct_children_inclusive"]: times[key] = 0
	for key: String in ["ticks","root_ticks","exit_hidden","exit_distant","exit_inert","exit_posed","overflow","imbalance","negative_span","unknown_key"]: counts[key] = 0
	for helper: String in HELPERS:
		for boundary: String in ["in_tick","outside_tick"]:
			var key: String = helper+"_"+boundary
			times[key] = 0
			for suffix: String in ["calls","slots","writes","queries"]: counts[key+"_"+suffix] = 0

static func begin_tick(at: int = -1) -> void:
	var now: int = Time.get_ticks_usec() if at < 0 else at
	_prepare(); depth += 1; counts.ticks += 1
	if depth > MAX_DEPTH: counts.overflow += 1; return
	frames.append({"start":now,"children":0})

static func finish_tick(reason: String,at: int = -1) -> void:
	var now: int = Time.get_ticks_usec() if at < 0 else at
	_prepare()
	if depth <= 0: counts.imbalance += 1; return
	if depth > MAX_DEPTH: depth -= 1; return
	if frames.is_empty(): counts.imbalance += 1; depth -= 1; return
	var frame: Dictionary = frames.pop_back()
	var elapsed: int = now-int(frame.start)
	var exclusive: int = elapsed-int(frame.children)
	if elapsed < 0 or exclusive < 0: counts.negative_span += 1
	times.tick_all_rigs_inclusive += elapsed
	times.tick_direct_children_inclusive += int(frame.children)
	times.tick_exclusive += exclusive
	if depth == 1: times.tick_root_inclusive += elapsed; counts.root_ticks += 1
	if counts.has("exit_"+reason): counts["exit_"+reason] += 1
	else: counts.unknown_key += 1
	depth -= 1
	if not frames.is_empty(): frames.back().children += elapsed

static func helper(name: String,started: int,slots: int = 0,writes: int = 0,queries: int = 0,at: int = -1) -> void:
	var now: int = Time.get_ticks_usec() if at < 0 else at
	_prepare()
	if name not in HELPERS: counts.unknown_key += 1; return
	var key: String = name+("_in_tick" if depth > 0 else "_outside_tick")
	var elapsed: int = now-started
	if elapsed < 0: counts.negative_span += 1
	times[key] += elapsed
	counts[key+"_calls"] += 1; counts[key+"_slots"] += slots
	counts[key+"_writes"] += writes; counts[key+"_queries"] += queries

static func snapshot() -> Dictionary:
	_prepare()
	return {"us":times.duplicate(),"counts":counts.duplicate(),"depth":depth,"stack_size":frames.size()}

static func reset_for_contract() -> void:
	times.clear(); counts.clear(); frames.clear(); depth = 0; _prepare()
