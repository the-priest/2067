extends UIPanel
## Your records: the best of every species, and everything on the wall.


func panel_title() -> String:
	return "TROPHY ROOM"


func build() -> void:
	var v := scroll()
	v.add_child(UIStyle.label("RECORDS", 22, UIStyle.RUST, UIStyle.title()))
	for k in Catalog.SPECIES.keys():
		var sp: Dictionary = Catalog.SPECIES[k]
		var best := Game.best_on_wall(k)
		var kills := int(Game.stats.get("kill_" + k, 0))
		var seen := Game.seen_species.has(k) or kills > 0
		var name := String(sp["name"]) if seen else "???"
		var line := "%s  ·  %s" % [name, ("best mounted %.1f %s" % [best, Catalog.horn_class(best, k)]) if best > 0.0 else "nothing mounted"]
		line += "  ·  taken: %d" % kills
		var l := UIStyle.label(line, 18, Catalog.class_color(Catalog.horn_class(best, k)) if best > 0.0 else UIStyle.BONE, UIStyle.bold())
		v.add_child(l)
		if seen:
			var d := UIStyle.label("%s. %s" % [sp["latin"], sp["blurb"]], 14, UIStyle.DIM, UIStyle.body())
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.custom_minimum_size = Vector2(900, 0)
			v.add_child(d)
	v.add_child(HSeparator.new())
	v.add_child(UIStyle.label("ON THE WALL (%d)" % Game.wall.size(), 22, UIStyle.RUST, UIStyle.title()))
	for t in Game.wall:
		var sp2: Dictionary = Catalog.SPECIES[t["species"]]
		v.add_child(UIStyle.label("%s  %.1f  %s   (day %d)" % [sp2["name"], float(t["score"]), t["class"], int(t.get("day", 0))], 17, Catalog.class_color(t["class"]), UIStyle.body()))
	v.add_child(HSeparator.new())
	var s := Game.stats
	v.add_child(UIStyle.label("Shots %d · hits %d · kills %d · perfect heart shots %d · contracts %d · scrip earned from trophies %d" % [int(s.get("shots", 0)), int(s.get("hits", 0)), int(s.get("kills", 0)), int(s.get("heart_shots", 0)), int(s.get("contracts", 0)), Game.sold_total], 15, UIStyle.DIM))
