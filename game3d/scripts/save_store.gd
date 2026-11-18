extends Node

const SAVE_PATH := "user://rockbottom_3d_slice_v1.json"
var save_path := SAVE_PATH
var busy := false
var last_error := ""

func write_save(data: Dictionary) -> bool:
	if busy:
		last_error = "the file is still open."
		return false
	busy = true
	last_error = ""
	var payload := JSON.stringify(data)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.rb3dSave(%s)" % JSON.stringify(payload))
		var result: Dictionary = await _wait_web()
		busy = false
		last_error = str(result.get("error", ""))
		return bool(result.get("ok", false))
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		busy = false
		last_error = "the drawer will not open."
		return false
	file.store_string(payload)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		busy = false
		last_error = "the paper did not take."
		return false
	var moved := DirAccess.rename_absolute(save_path + ".tmp", save_path)
	busy = false
	if moved != OK:
		last_error = "the drawer would not close."
	return moved == OK

func read_save() -> Dictionary:
	if busy:
		return {}
	busy = true
	last_error = ""
	var payload := ""
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.rb3dLoad()")
		var result: Dictionary = await _wait_web()
		busy = false
		last_error = str(result.get("error", ""))
		if not bool(result.get("ok", false)):
			return {}
		payload = str(result.get("data", ""))
	else:
		busy = false
		if not FileAccess.file_exists(save_path):
			return {}
		var file := FileAccess.open(save_path, FileAccess.READ)
		if file == null:
			last_error = "the drawer will not open."
			return {}
		payload = file.get_as_text()
		file.close()
	var parsed: Variant = JSON.parse_string(payload)
	if not parsed is Dictionary:
		if not payload.is_empty():
			last_error = "the paper is unreadable."
		return {}
	return parsed

func _wait_web() -> Dictionary:
	for tick in range(200):
		await get_tree().create_timer(0.05).timeout
		var value: Variant = JavaScriptBridge.eval("window.rb3dStorageResult || ''")
		if value is String and not value.is_empty():
			var result: Variant = JSON.parse_string(value)
			if result is Dictionary:
				return result
	return {"ok": false, "error": "the drawer is not answering."}
