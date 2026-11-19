extends RefCounted
## Pure receipt copy for source-owned ending events.
static func receipt(payload: Dictionary) -> Dictionary:
	if str(payload.get("title","")) == "THE BUS":
		return {"title":"THE BUS","text":"you got on the bus.\nthe bus left.\nyou survived rock bottom.\nthe bus has a destination. it has not told you.\n\ndays: %s · rocks smoked: %s · cred: %d\n\nvibekoded · the possum stayed" % [payload.get("day",0),payload.get("rocks_smoked",0),int(payload.get("cred",0))]}
	var kind: String = str(payload.get("kind",""))
	if kind == "kingdom" or str(payload.get("title","")) == "ONE CRACKLORD":
		return {"title":"ONE CRACKLORD","text":"the kingdom is four curbs and a ditch · the throne is a folding chair\n\nvibekoded · the possum still knows"}
	if kind == "coop":
		return {"title":"TUESDAYS AND THURSDAYS","text":"you and stripe split the corner · you get the slow days\n\nvibekoded · the possum still knows"}
	return {"title":"CRACK LORD SUPREME","text":"the corner is yours · you get tuesdays and thursdays\n\nvibekoded · the possum still knows"}
