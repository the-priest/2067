extends UIPanel
## The workbench in the barn: what keeps the ghouls out.


func panel_title() -> String:
	return "FARM DEFENSES"


func panel_size() -> Vector2:
	return Vector2(1000, 680)


func build() -> void:
	refresh()


func refresh() -> void:
	clear_box(box)
	var f: Farm = world.farm
	box.add_child(UIStyle.label("%d scrip   ·   Wall %d / %d   ·   Raids held off: %d   ·   Next raid expected: night of day %d" % [Game.scrip, int(Game.wall_hp), int(f.max_wall()), Game.raids_done, Game.next_raid_day], 18, Color(1.0, 0.85, 0.45), UIStyle.bold()))
	var hint := "Something keeps drawing them here. Tonight's raid would be about %d strong." % f.raid_size()
	if Game.xyla:
		hint += "  Xyla's tuned the bench: everything's 20% cheaper."
	box.add_child(UIStyle.label(hint, 15, UIStyle.DIM))
	var rc := f.repair_cost()
	var rb := UIStyle.button("REPAIR THE WALL  (%d scrip)" % rc if rc > 0 else "WALL IS IN ONE PIECE", func() -> void:
		if f.repair():
			Sfx.play("cash", -4.0)
			Game.say("Wall patched up.", UIStyle.GOOD)
		refresh(), 400)
	rb.disabled = rc <= 0 or Game.scrip < rc
	box.add_child(rb)
	var v := scroll()
	for k in Farm.UPGRADES.keys():
		var u: Dictionary = Farm.UPGRADES[k]
		var lv := f.level(k)
		var maxl := (u["levels"] as Array).size()
		var why := f.why_not(k)
		var cost := f.next_cost(k)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UIStyle.panel(Color(0.12, 0.1, 0.08, 0.85), Color(0.3, 0.25, 0.2, 0.6)))
		v.add_child(p)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		p.add_child(h)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(tv)
		tv.add_child(UIStyle.label("%s   ·   level %d / %d" % [u["name"], lv, maxl], 20, UIStyle.BONE, UIStyle.title()))
		var d := UIStyle.label(String(u["desc"]), 15, UIStyle.DIM, UIStyle.body())
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(620, 0)
		tv.add_child(d)
		var key: String = k
		var b := UIStyle.button("MAXED" if why == "maxed" else ("BUILD  %d" % cost if why == "" else why.to_upper()), func() -> void:
			if f.buy(key):
				Sfx.play("cash", -4.0)
				Game.say("%s built." % u["name"], UIStyle.GOOD)
			refresh(), 200)
		b.disabled = why != ""
		h.add_child(b)
	focus_first.call_deferred()
