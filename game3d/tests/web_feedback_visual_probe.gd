extends "res://tests/world_feedback_visual_probe.gd"
## Thin Web IO wrapper. All fixtures, transitions and captures are inherited.
func _run() -> void:
	if not OS.has_feature("web"):
		push_error("Web feedback wrapper requires a real Web export."); quit(1); return
	JavaScriptBridge.eval("window.rbFeedbackBooted()")
	await super._run()

func _capture(id: String,extra: Dictionary = {}) -> Dictionary:
	if finishing: return {}
	var result: Dictionary = await super._capture(id,extra)
	if result.is_empty() or finishing: return result
	var evidence: Dictionary = result.evidence
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(output.path_join(evidence.file))
	var record := {"index":captures.size()-1,"id":id,"file":evidence.file,"framebuffer":[width,int(width*9/16)],"png_bytes":bytes.size(),"png_sha256":evidence.sha256,"evidence":_json(evidence)}
	_check(not bytes.is_empty() and bytes.size() <= 8388608,"bounded original actual-frame PNG bytes")
	if not bytes.is_empty() and bytes.size() <= 8388608:
		JavaScriptBridge.eval("window.rbFeedbackFrame(%d,%s,%s,%s)" % [record.index,JSON.stringify(id),JSON.stringify(Marshalls.raw_to_base64(bytes)),JSON.stringify(record)])
	return result

func _source_hashes() -> Dictionary:
	var result: Dictionary = super._source_hashes()
	result["res://tests/world_feedback_visual_probe.gd"] = FileAccess.get_sha256("res://tests/world_feedback_visual_probe.gd")
	result["res://tests/web_feedback_visual_probe.gd"] = FileAccess.get_sha256("res://tests/web_feedback_visual_probe.gd")
	return result

func _finish(complete: bool) -> void:
	if finishing: return
	finishing = true
	if game != null: suspend_callbacks(game,game.hud)
	var hashes: Dictionary = _source_hashes()
	var unavailable: Array[String] = []
	for path: String in hashes:
		if str(hashes[path]).is_empty(): unavailable.append(path)
	var report := {"schema":1,"format":"rock-bottom-domain-feedback-web-visual","complete":complete,"finished":true,"acceptance":complete and failures.is_empty(),"scope":"staged actual-domain Web rendering only; no input/campaign/performance acceptance","packet":packet,"width":width,"height":int(width*9/16),"wall_ms":Time.get_ticks_msec()-started,"checks":checks,"failures":failures,"expected_cases":CASES.get(packet,[]),"completed_cases":completed_cases,"contexts":contexts,"captures":captures,"fixtures":fixtures,"source_hashes":hashes,"source_hashes_available":unavailable.is_empty(),"unavailable_source_hashes":unavailable,"source_content_hash_available":not str(hashes.get("res://data/source_content.json","")).is_empty(),"source_hash_note":"Compiled script hashes may be unavailable. Retain external source/archive/export-pack hashes.","visual_review_required":true,"web":OS.has_feature("web"),"renderer":RenderingServer.get_current_rendering_method(),"engine":Engine.get_version_info().string}
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("feedback-visual.json"),FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(_json(report),"\t")); file.close()
	JavaScriptBridge.eval("window.rbFeedbackReport(%s)" % JSON.stringify(_json(report)))
	print("ACTUAL DOMAIN FEEDBACK WEB VISUAL: ","PASS" if report.acceptance else "FAIL"," ",packet,"; human visual review pending")
	# Leave the real paused framebuffer available. DOM shows separately labeled
	# original PNGs, never a fabricated or redrawn replacement canvas.
