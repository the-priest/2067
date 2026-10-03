extends UIPanel
## The book: the Hall of Horns (the best sets you've ever taken), every
## species' record, how many of each class, and what's on the wall.


func panel_title() -> String:
	return "TROPHY ROOM  ·  HALL OF HORNS"


func panel_size() -> Vector2:
	return Vector2(1240, 760)


func build() -> void:
	var s := Game.stats
	var counts := HBoxContainer.new()
	counts.add_theme_constant_override("separation", 22)
	box.add_child(counts)
	for c in ["MYTHIC", "DIAMOND", "GOLD", "SILVER", "BRONZE"]:
		counts.add_child(UIStyle.label("%s  %d" % [c, int(s.get("class_" + c.to_lower(), 0))], 20, Catalog.class_color(c), UIStyle.title()))
	counts.add_child(UIStyle.label("·  %d kills  ·  %d perfect hearts" % [int(s.get("kills", 0)), int(s.get("heart_shots", 0))], 18, UIStyle.DIM, UIStyle.bold()))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	# Left: the hall.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(560, 0)
	left.add_theme_constant_override("separation", 4)
	row.add_child(left)
	left.add_child(UIStyle.label("HALL OF HORNS", 24, UIStyle.RUST, UIStyle.title()))
	if Game.hall.is_empty():
		left.add_child(UIStyle.label("Nothing yet. Every set of horns you take is scored and ranked here.", 16, UIStyle.DIM))
	for i in Game.hall.size():
		var t: Dictionary = Game.hall[i]
		var sp: Dictionary = Catalog.SPECIES.get(t["species"], {})
		var line := HBoxContainer.new()
		line.add_child(_cell("#%d" % (i + 1), 46, UIStyle.DIM if i > 2 else Color(1.0, 0.85, 0.4)))
		line.add_child(_cell(String(sp.get("name", t["species"])), 200, UIStyle.BONE))
		line.add_child(_cell("%.1f" % float(t["score"]), 90, UIStyle.BONE))
		line.add_child(_cell(String(t["class"]), 110, Catalog.class_color(t["class"])))
		line.add_child(_cell("day %d" % int(t.get("day", 0)), 80, UIStyle.DIM))
		left.add_child(line)
	# Right: every species.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(UIStyle.label("RECORDS", 24, UIStyle.RUST, UIStyle.title()))
	var head := HBoxContainer.new()
	for h in [["SPECIES", 190], ["BEST", 80], ["CLASS", 100], ["TAKEN", 70], ["AVERAGE", 90], ["WALL", 70]]:
		head.add_child(_cell(h[0], h[1], UIStyle.DIM))
	right.add_child(head)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	sc.add_child(list)
	for k in Catalog.SPECIES.keys():
		var sp2: Dictionary = Catalog.SPECIES[k]
		var r: Dictionary = Game.records.get(k, {})
		var seen := Game.seen_species.has(k) or not r.is_empty()
		var line2 := HBoxContainer.new()
		line2.add_child(_cell(String(sp2["name"]) if seen else "???", 190, UIStyle.BONE if seen else UIStyle.DIM))
		if r.is_empty():
			line2.add_child(_cell("-", 80, UIStyle.DIM))
			line2.add_child(_cell("", 100, UIStyle.DIM))
			line2.add_child(_cell("0", 70, UIStyle.DIM))
			line2.add_child(_cell("-", 90, UIStyle.DIM))
		else:
			line2.add_child(_cell("%.1f" % float(r["best"]), 80, UIStyle.BONE))
			line2.add_child(_cell(String(r["cls"]), 100, Catalog.class_color(r["cls"])))
			line2.add_child(_cell("%d" % int(r["count"]), 70, UIStyle.BONE))
			line2.add_child(_cell("%.1f" % (float(r["total"]) / maxf(1.0, float(r["count"]))), 90, UIStyle.DIM))
		var wb := Game.best_on_wall(k)
		line2.add_child(_cell("%.0f" % wb if wb > 0.0 else "-", 70, UIStyle.DIM))
		list.add_child(line2)
	box.add_child(UIStyle.label("Shots %d · hits %d · ghouls %d · raids held %d · contracts %d · scrip from trophies %d" % [int(s.get("shots", 0)), int(s.get("hits", 0)), int(s.get("ghouls", 0)), Game.raids_done, int(s.get("contracts", 0)), Game.sold_total], 15, UIStyle.DIM))


func _cell(t: String, w: float, c: Color) -> Label:
	var l := UIStyle.label(t, 17, c, UIStyle.bold())
	l.custom_minimum_size = Vector2(w, 0)
	l.clip_text = true
	return l
