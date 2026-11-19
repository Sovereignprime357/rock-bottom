extends SceneTree
const Metrics = preload("res://scripts/pose_cost_metrics.gd")
var checks := 0
var failures := 0
var groups := 0
func _initialize() -> void: call_deferred("_run")
func _check(value: bool,label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		if failures <= 12: push_error("Pose diagnostic: "+label)
func _run() -> void:
	Metrics.reset_for_contract()
	Metrics.begin_tick(100); Metrics.begin_tick(120); Metrics.finish_tick("posed",150); Metrics.finish_tick("posed",190)
	var first: Dictionary = Metrics.snapshot()
	_check(first.us.tick_root_inclusive == 90 and first.us.tick_all_rigs_inclusive == 120,"root and overlapping all-rig inclusive spans distinct")
	_check(first.us.tick_exclusive == 90 and first.us.tick_direct_children_inclusive == 30,"nested child counted once in exclusive sum")
	_check(first.counts.ticks == 2 and first.counts.root_ticks == 1 and first.counts.exit_posed == 2,"per-rig and root denominators")
	_check(first.depth == 0 and first.stack_size == 0,"balanced stack")
	first.us.tick_exclusive = -100
	_check(Metrics.snapshot().us.tick_exclusive == 90,"snapshot detached")
	groups += 1
	Metrics.reset_for_contract()
	Metrics.begin_tick(0); Metrics.begin_tick(10); Metrics.begin_tick(20)
	Metrics.finish_tick("inert",30); Metrics.finish_tick("distant",50)
	Metrics.begin_tick(60); Metrics.finish_tick("hidden",70); Metrics.finish_tick("posed",100)
	var nested: Dictionary = Metrics.snapshot()
	_check(nested.us.tick_exclusive == 100 and nested.us.tick_root_inclusive == 100,"grandchild and sibling exclusive time not double counted")
	_check(nested.counts.exit_hidden == 1 and nested.counts.exit_distant == 1 and nested.counts.exit_inert == 1,"all actual early exits counted")
	Metrics.helper("reset",200,32,0,0,210)
	Metrics.begin_tick(300); Metrics.helper("apply",310,32,7,0,320); Metrics.helper("attachments",320,0,2,4,330); Metrics.finish_tick("posed",350)
	var helpers: Dictionary = Metrics.snapshot()
	_check(helpers.us.reset_outside_tick == 10 and helpers.us.reset_in_tick == 0,"explicit reset/construction distinct from actor tick")
	_check(helpers.us.apply_in_tick == 10 and helpers.counts.apply_in_tick_slots == 32 and helpers.counts.apply_in_tick_writes == 7,"actual scan/write denominator preserved")
	_check(helpers.counts.attachments_in_tick_queries == 4 and helpers.counts.attachments_in_tick_writes == 2,"attachment query/write counters")
	groups += 1
	Metrics.reset_for_contract()
	for i: int in range(19): Metrics.begin_tick(i)
	for i: int in range(19): Metrics.finish_tick("posed",100+i)
	var capped: Dictionary = Metrics.snapshot()
	_check(capped.counts.overflow == 3 and capped.depth == 0 and capped.stack_size == 0,"bounded diagnostic stack reports overflow without limiting actual call depth")
	Metrics.finish_tick("posed",200); Metrics.begin_tick(300); Metrics.finish_tick("posed",299); Metrics.helper("unknown",400,0,0,0,401)
	var invalid: Dictionary = Metrics.snapshot()
	_check(invalid.counts.imbalance == 1 and invalid.counts.negative_span == 1 and invalid.counts.unknown_key == 1,"invalid accounting stays explicit")
	_check(invalid.us.size() == 12 and invalid.counts.size() == 42,"fixed bounded numeric-key cardinality")
	groups += 1
	_check(groups == 3,"all three diagnostic contract groups completed")
	print("POSE EXCLUSIVE COST CONTRACT: ","PASS" if failures == 0 else "FAIL","; ",checks," checks; ",groups,"/3 groups; no performance claim")
	quit(0 if failures == 0 else 1)
