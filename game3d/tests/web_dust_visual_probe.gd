extends "res://tests/world_dust_visual_probe.gd"
## IO only. Native and Web execute the exact same inherited contexts/captures.
func _run() -> void:
	if not OS.has_feature("web"):
		push_error("Dust Web wrapper requires a real Web export."); quit(1); return
	JavaScriptBridge.eval("window.rbDustBooted()")
	await super._run()

func _publish_frame(id: String,evidence: Dictionary,bytes: PackedByteArray) -> void:
	_check(not bytes.is_empty() and bytes.size() <= 8388608,"bounded original Web PNG payload")
	if bytes.is_empty() or bytes.size() > 8388608: return
	var record := {"index":captures.size()-1,"id":id,"file":evidence.file,"framebuffer":[width,int(width*9/16)],"png_bytes":bytes.size(),"png_sha256":evidence.sha256,"evidence":_json(evidence)}
	JavaScriptBridge.eval("window.rbDustFrame(%d,%s,%s,%s)" % [record.index,JSON.stringify(id),JSON.stringify(Marshalls.raw_to_base64(bytes)),JSON.stringify(record)])

func _publish_report(_report: Dictionary,text: String,sha256: String) -> void:
	JavaScriptBridge.eval("window.rbDustReport(%s,%s)" % [JSON.stringify(text),JSON.stringify(sha256)])
