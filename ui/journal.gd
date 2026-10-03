extends UIPanel
## What you're carrying, the contracts, and the hunting journal.


func panel_title() -> String:
	return "JOURNAL"


func build() -> void:
	var v := scroll()
	v.add_child(UIStyle.label("PACK  %d/%d" % [Game.carried.size(), Game.capacity()], 22, UIStyle.RUST, UIStyle.title()))
	for t in Game.carried:
		var sp: Dictionary = Catalog.SPECIES[t["species"]]
		if t["kind"] == "hide":
			v.add_child(UIStyle.label("%s hide · %s · worth %d" % [sp["name"], Catalog.hide_grade(float(t["quality"])), Game.value_of(t)], 17))
		else:
			v.add_child(UIStyle.label("%s horns · %.1f %s · worth %d" % [sp["name"], float(t["score"]), t["class"], Game.value_of(t)], 17, Catalog.class_color(t["class"])))
	if Game.carried.is_empty():
		v.add_child(UIStyle.label("Empty.", 16, UIStyle.DIM))
	v.add_child(UIStyle.label("CONTRACTS", 22, UIStyle.RUST, UIStyle.title()))
	for c in Game.contracts:
		v.add_child(UIStyle.label("%s  ·  %d scrip" % [c["text"], int(c["pay"])], 17))
	v.add_child(UIStyle.label("MAE SAYS", 22, UIStyle.RUST, UIStyle.title()))
	v.add_child(UIStyle.label(world.story_goal(), 17, UIStyle.TEAL))
	v.add_child(UIStyle.label("LOG", 22, UIStyle.RUST, UIStyle.title()))
	for e in Game.log_entries:
		var l := UIStyle.label(String(e), 15, UIStyle.DIM, UIStyle.body())
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(900, 0)
		v.add_child(l)
