extends SceneTree

const Store = preload("res://scripts/save_store.gd")
var checks: int = 0
var groups: int = 0
var failures: Array[String] = []
var directory: String = ""
var save_path: String = ""

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func _write_payload(payload: String) -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		_check(false, "QA payload file opens")
		return false
	file.store_string(payload)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	_check(error == OK, "QA payload writes exact bytes")
	return error == OK

func _run() -> void:
	if OS.has_feature("web"):
		push_error("This focused filesystem gate requires native; actual Web is separate.")
		quit(1)
		return
	directory = "user://save_store_read_qa_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	save_path = directory + "/test.json"
	if DirAccess.dir_exists_absolute(directory) or DirAccess.make_dir_absolute(directory) != OK:
		push_error("Refuse existing or unavailable QA directory.")
		quit(1)
		return
	var store := Store.new()
	root.add_child(store)
	store.save_path = save_path
	if "--characterize-malformed" in OS.get_cmdline_user_args():
		if _write_payload("{"):
			var invalid: Dictionary = await store.read_save()
			_check(invalid.is_empty(), "malformed nonempty payload remains refused")
			_check(store.last_error == "the paper is unreadable.", "malformed nonempty keeps exact error")
			_check(not store.busy, "malformed nonempty releases busy")
			_check(FileAccess.get_file_as_string(save_path) == "{", "malformed bytes remain untouched")
		_cleanup(store)
		if failures.is_empty():
			print("SAVE STORE EXPECTED INVALID: OBSERVED (%d checks; engine parser error REQUIRED; not a clean gate)" % checks)
			quit(0)
		else:
			_fail()
		return

	store.last_error = "old error"
	var absent: Dictionary = await store.read_save()
	_check(absent.is_empty() and store.last_error.is_empty() and not store.busy, "absent file returns clean empty result")
	_check(not FileAccess.file_exists(save_path), "absent read creates no save")
	groups += 1

	if not _write_payload(""):
		_cleanup(store)
		_fail()
		return
	store.last_error = "old error"
	var empty: Dictionary = await store.read_save()
	_check(empty.is_empty() and store.last_error.is_empty() and not store.busy, "zero-byte payload returns clean empty result")
	_check(FileAccess.get_file_as_string(save_path).is_empty(), "empty payload remains untouched")
	groups += 1

	var expected: Dictionary = {"schema": 2, "player": {"cash": 7, "label": "kept"}, "state": {"rows": [1, false, null]}}
	_check(await store.write_save(expected), "real store writes Dictionary")
	var valid: Dictionary = await store.read_save()
	_check(valid.size() == 3 and valid.get("schema") == 2 and valid.get("player") is Dictionary and valid.player.cash == 7 and valid.player.label == "kept" and valid.get("state") is Dictionary and valid.state.rows is Array and valid.state.rows.size() == 3 and valid.state.rows[0] == 1 and valid.state.rows[1] == false and valid.state.rows[2] == null and store.last_error.is_empty() and not store.busy, "Dictionary payload roundtrips unchanged")
	_check(not FileAccess.file_exists(save_path + ".tmp"), "successful native transaction closes temporary file")
	groups += 1

	for payload: String in ["[]", "null", "0", "false", "\"paper\""]:
		if not _write_payload(payload):
			_cleanup(store)
			_fail()
			return
		var wrong_type: Dictionary = await store.read_save()
		_check(wrong_type.is_empty() and store.last_error == "the paper is unreadable." and not store.busy, "non-Dictionary JSON refuses: " + payload)
		_check(FileAccess.get_file_as_string(save_path) == payload, "non-Dictionary bytes remain exact: " + payload)
	groups += 1

	store.busy = true
	store.last_error = "existing operation"
	var busy_result: Dictionary = await store.read_save()
	_check(busy_result.is_empty() and store.busy and store.last_error == "existing operation", "busy refusal preserves current operation")
	store.busy = false
	groups += 1
	_cleanup(store)
	_check(groups == 5, "all five groups completed")
	if failures.is_empty():
		print("SAVE STORE READ GATE: PASS (%d checks; %d/5 groups)" % [checks, groups])
		quit(0)
	else:
		_fail()

func _cleanup(store: Node) -> void:
	store.free()
	for path: String in [save_path + ".tmp", save_path]:
		if FileAccess.file_exists(path):
			_check(DirAccess.remove_absolute(path) == OK, "remove owned QA file")
	_check(DirAccess.remove_absolute(directory) == OK, "remove owned QA directory")

func _fail() -> void:
	for failure: String in failures:
		push_error(failure)
	print("SAVE STORE READ GATE: FAIL (%d/%d checks; %d/5 groups)" % [failures.size(), checks, groups])
	quit(1)
