extends SceneTree
## Source replay and lifecycle authority for persisted wall decoration.
const State = preload("res://scripts/game_state.gd")
const Markings = preload("res://scripts/wall_markings.gd")
const Content = preload("res://scripts/content_catalog.gd")
var checks: int = 0
var completed: int = 0
var completed_steps: int = 0
var failures: Array[String] = []

class SequenceState:
	extends "res://scripts/game_state.gd"
	var rolls: Array = []
	var cursor: int = 0
	var draws: int = 0
	var fallback: float = 0.0
	var has_fallback: bool = false
	var replace_at: int = -1
	var replace_kind: String = ""
	var replacement: Dictionary = {}
	var invalid_at: int = -1
	var invalid_value: float = NAN
	func configure(options: Dictionary) -> void:
		rng_seed = int(options.get("seed",DEFAULT_SEED)); draws = 0
		rolls.assign(options.get("rolls",[])); cursor = 0
		has_fallback = options.has("fallback") and options.fallback != null
		if has_fallback: fallback = float(options.fallback)
	func change(options: Dictionary) -> void:
		if options.has("rolls"): rolls.assign(options.rolls); cursor = 0
		if options.has("fallback"):
			has_fallback = options.fallback != null
			if has_fallback: fallback = float(options.fallback)
	func random_float() -> float:
		# The real shared generator always advances, including scripted outputs.
		var value: float = super.random_float(); draws += 1
		if cursor < rolls.size(): value = float(rolls[cursor]); cursor += 1
		elif has_fallback: value = fallback
		if draws == replace_at:
			if replace_kind == "player": p = p.duplicate(true); p.cash += 7
			else:
				s = s.duplicate(true); s.graffiti = [{"replacement":"chalk"}]; s.posters = [{"replacement":"paper"}]
			replacement = {"p":p.duplicate(true),"s":s.duplicate(true)}
		return invalid_value if draws == invalid_at else value
	func next_lcg() -> float:
		return float((rng_seed*1664525+1013904223)&0xffffffff)/4294967296.0
	func next_value() -> float:
		if cursor < rolls.size(): return float(rolls[cursor])
		return fallback if has_fallback else next_lcg()

class MemorySave:
	extends RefCounted
	var writes: int = 0
	var data: Dictionary = {}
	func write(game: RefCounted) -> void:
		writes += 1; data = game.snapshot()

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value
func _same(a: Variant,b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b)) < 0.000001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not _same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index: int in range(a.size()):
			if not _same(a[index],b[index]): return false
		return true
	return a == b
func _fields(game: RefCounted) -> Dictionary:
	return {"graffiti":_copy(game.s.get("graffiti")),"posters":_copy(game.s.get("posters"))}
func _protected(game: RefCounted) -> Dictionary:
	var state: Dictionary = game.s.duplicate(true); state.erase("graffiti"); state.erase("posters")
	return {"player":game.p.duplicate(true),"state":state,"actors":game.npcs.duplicate(true),"cash":game.cash_piles.duplicate(true),"projectiles":game.projectiles.duplicate(true),"events":game.events.duplicate(true)}
func _valid_layout() -> Dictionary:
	var initial: Dictionary = Content.load_content().initial.state
	return {"graffiti":initial.graffiti.duplicate(true),"posters":initial.posters.duplicate(true)}

func _metrics() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/courier_canvas_metrics.json"))
	_check(data is Dictionary,"real Canvas measurement fixture exists")
	if not data is Dictionary: return
	_check(data.evidence.method == "canvas-measureText" and data.evidence.fontSetStatus == "loaded" and data.evidence.fontCheck == true and data.evidence.defaultKerning == "auto","actual browser Canvas measurement provenance retained")
	_check(data.entries.size() == 198 and data.counts.lines == 66,"complete66-line/three-size measurement census")
	var seen: Dictionary = {}; var changed: int = 0
	var catalogs: Dictionary = Content.load_content().catalogs
	for row: Dictionary in data.entries:
		var key: String = row.text+"/"+str(int(row.size))
		_check(not seen.has(key) and catalogs[row.pool][int(row.index)] == row.text and int(row.size) in [8,9,10],"captured width maps exact source text and size")
		seen[key] = true
		_check(is_finite(float(row.width)) and row.width > 0 and ceili(float(row.width)) == int(row.ceil),"captured Canvas width rounds exactly as source")
		if int(row.ceil) != ceili(row.text.length()*float(row.size)*0.6): changed += 1
	_check(changed == 90,"measured table preserves90 differences from former approximate harness")

func _replay(fixture: Dictionary) -> void:
	_check(fixture.counts.cases == 37 and fixture.counts.steps == 66 and fixture.counts.metrics == 198,"source fixture census remains bounded and complete")
	for row: Dictionary in fixture.cases:
		var game := SequenceState.new(); game.s.mode = "playing"; game.events.clear()
		game.s.erase("graffiti"); game.s.erase("posters")
		for key: String in row.setup: game.s[key] = _copy(row.setup[key])
		game.configure(row.rng)
		var owner := Markings.new(game); var saves := MemorySave.new()
		_check(owner.ready() and game.draws == 0,"ready validates metrics without spending source RNG: "+row.id)
		var step_index: int = 0
		for step: Dictionary in row.steps:
			var operation: Dictionary = step.operation; var label: String = "%s/%d/%s"%[row.id,step_index,operation.kind]
			if operation.has("rng"): game.change(operation.rng)
			for key: String in operation.get("replace",{}): game.s[key] = _copy(operation.replace[key])
			var before: Dictionary = _protected(game); var draws_before: int = game.draws
			var raw: Dictionary = operation.get("raw_state",{}).duplicate(true); var raw_before: Dictionary = raw.duplicate(true)
			var accepted: bool = true
			match operation.kind:
				"start_fresh": accepted = owner.prepare_start("fresh")
				"start_restore": accepted = owner.prepare_start("restore",raw)
				"before_draw": accepted = owner.before_world_draw()
				"save": saves.write(game)
				_: accepted = false
			_check(accepted,label+" accepted")
			_check(_same(_fields(game),step.expected),label+" exact unchanged-source arrays")
			_check(_same(_protected(game),before) and raw == raw_before,label+" no unrelated state/input mutation or gameplay events")
			_check(game.draws == int(step.rng.draws) and game.draws-draws_before == int(step.rng.stepDraws),label+" exact shared RNG draw count")
			_check(game.rng_seed == int(step.rng.seed) and _same(game.next_lcg(),step.rng.next_lcg) and _same(game.next_value(),step.rng.next),label+" exact RNG continuation")
			_check(saves.writes == int(step.writes),label+" saves occur only through explicit caller")
			if step.has("saved"):
				_check(_same({"graffiti":saves.data.state.get("graffiti"),"posters":saves.data.state.get("posters")},step.saved),label+" actual State codec preserves source save fields")
			_check(Markings.current_graffiti_layout(game.s.get("graffiti")) == step.sourceValid,label+" source startup layout predicate")
			var snapshot: Dictionary = owner.snapshot()
			_check(_same({"graffiti":snapshot.get("graffiti"),"posters":snapshot.get("posters")},step.expected),label+" detached projection carries current records")
			completed_steps += 1; step_index += 1
		completed += 1

func _continuity() -> void:
	var game := SequenceState.new(); game.events.clear(); game.configure({"seed":4401})
	var owner := Markings.new(game); var initial: Dictionary = _valid_layout()
	_check(owner.prepare_start("restore",initial),"existing measured source save prepares")
	_check(game.draws == 0 and owner.inspect().graffiti_builds == 0 and owner.inspect().poster_builds == 0,"valid restore consumes no layout builds or RNG")
	var records: Dictionary = owner.snapshot(); var revision: int = records.revision
	_check(owner.projection_revision() == revision,"read-only projection revision matches prepared epoch")
	records.graffiti[0].text = "detached chalk"; records.posters[0].text = "detached paper"
	_check(_same(_fields(game),initial),"projection copies cannot alter authoritative saved layouts")
	var protected_before: Dictionary = _protected(game)
	for frame: int in range(120): _check(owner.before_world_draw(),"stable active draw remains accepted")
	_check(game.draws == 0 and owner.inspect().revision == revision and _same(_protected(game),protected_before),"unchanged draw does not rebuild, consume RNG, tick clocks or alter gameplay")
	for frame: int in range(120): _check(owner.projection_revision() == revision,"stable projection revision needs no detached array copy")
	var save: Dictionary = game.snapshot(); var before_save: Dictionary = save.duplicate(true)
	var loaded := SequenceState.new(); _check(loaded.restore(save).ok,"actual schema2 save restoration succeeds")
	var load_owner := Markings.new(loaded); var saved_seed: int = loaded.rng_seed
	_check(load_owner.prepare_start("restore",save.state),"restored owner accepts raw saved fields")
	_check(loaded.draws == 0 and loaded.rng_seed == saved_seed and _same(_fields(loaded),initial) and save == before_save,"save/load preserves exact layout and next shared random draw")
	var missing: Dictionary = save.duplicate(true); missing.state.erase("graffiti"); missing.state.erase("posters")
	var absent := SequenceState.new(); _check(absent.restore(missing).ok,"old schema2 envelope without layouts restores")
	var absent_owner := Markings.new(absent)
	_check(absent_owner.prepare_start("restore",missing.state) and absent.draws > 0,"raw missing fields rebuild instead of trusting inherited export defaults")
	var fresh_before: Dictionary = game.p.duplicate(true)
	_check(owner.prepare_start("fresh") and game.draws > 0 and _same(game.p,fresh_before),"fresh owns new layout generation only")
	_check(owner.projection_revision() > revision,"fresh layout invalidates caller projection cache")
	_check(owner.inspect().graffiti_builds == 1 and owner.inspect().poster_builds == 1,"fresh performs the two source builders once in order")
	var after: Dictionary = _fields(game); var draws_after: int = game.draws
	_check(not owner.prepare_start("unsupported",{}) and _same(_fields(game),after) and game.draws == draws_after,"invalid lifecycle reason refuses without side effects")
	var cold := SequenceState.new(); cold.s.mode = "title"; cold.configure({"seed":553})
	var cold_owner := Markings.new(cold); var cold_before: Dictionary = cold.s.duplicate(true)
	_check(cold_owner.before_world_draw() and cold.draws == 0 and cold.s == cold_before and cold_owner.snapshot().is_empty(),"title projection cannot build an unprepared epoch")
	cold.s.mode = "playing"
	_check(not cold_owner.before_world_draw() and cold.draws == 0,"active draw rejects an unprepared epoch")
	_check(cold_owner.projection_revision() == -1,"unprepared epoch exposes no cacheable projection revision")

func _epoch_guards() -> void:
	for kind: String in ["player","state"]:
		var game := SequenceState.new(); game.configure({"seed":321}); var owner := Markings.new(game)
		_check(owner.prepare_start("restore",_valid_layout()),"epoch test establishes saved layout")
		if kind == "player": game.p = game.p.duplicate(true)
		else: game.s = game.s.duplicate(true)
		var before: Dictionary = {"p":game.p.duplicate(true),"s":game.s.duplicate(true)}; var prior_draws: int = game.draws
		_check(not owner.before_world_draw() and owner.snapshot().is_empty() and not owner.inspect().bound,"new "+kind+" identity cannot use stale layout binding")
		_check(owner.projection_revision() == -1,"replaced "+kind+" identity invalidates projection revision")
		_check(game.draws == prior_draws and game.p == before.p and game.s == before.s,"stale "+kind+" refusal cannot modify either epoch")
		_check(owner.prepare_start("restore",_valid_layout()) and owner.inspect().bound,"explicit prepare binds new "+kind+" epoch")
		_check(owner.projection_revision() > 1,"prepared replacement "+kind+" changes revision even with identical arrays")
		for at: int in [1,30,86]:
			var changing := SequenceState.new(); changing.configure({"fallback":0.0}); changing.replace_kind = kind; changing.replace_at = at
			var interrupted := Markings.new(changing)
			_check(not interrupted.prepare_start("fresh"),"mid-generation "+kind+" replacement aborts at draw"+str(at))
			_check(changing.draws == at and changing.p == changing.replacement.p and changing.s == changing.replacement.s,"partial arrays never overwrite replacement epoch")
			_check(interrupted.snapshot().is_empty() and not interrupted.inspect().bound and changing.events.is_empty(),"interrupted generation exposes no stale presentation or save event")
	for invalid: float in [NAN,INF,-0.01,1.0]:
		var game := SequenceState.new(); game.configure({"seed":33}); game.invalid_at = 1; game.invalid_value = invalid
		var owner := Markings.new(game); var before: Dictionary = _fields(game)
		_check(not owner.prepare_start("fresh") and game.draws == 1 and _same(_fields(game),before) and game.events.is_empty(),"malformed shared RNG result cannot commit partial layouts")
	var released: SequenceState = SequenceState.new(); var observer: WeakRef = weakref(released)
	var abandoned := Markings.new(released); _check(abandoned.prepare_start("restore",_valid_layout()),"weak-owner test prepares")
	released = null
	_check(observer.get_ref() == null and not abandoned.ready() and not abandoned.before_world_draw() and abandoned.snapshot().is_empty(),"owner lifetime is weak and expired state refuses all work")
	var absent := Markings.new(null)
	_check(not absent.ready() and not absent.prepare_start("fresh") and not absent.before_world_draw(),"missing authority fails closed before RNG")

func _run() -> void:
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://fixtures/wall_markings_reference.json"))
	if not fixture is Dictionary: push_error("Missing wall-markings source fixture."); quit(1); return
	_metrics(); _replay(fixture); _continuity(); _epoch_guards()
	_check(completed == 37 and completed_steps == 66,"all37 source cases and66 steps completed without script abort")
	if failures.is_empty(): print("3D WALL MARKINGS GATE: PASS (%d checks;37 cases/66 source steps/198 Canvas measurements)"%checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D WALL MARKINGS GATE: FAIL (%d failures/%d checks)"%[failures.size(),checks]); quit(1)
