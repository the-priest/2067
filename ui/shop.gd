extends UIPanel
## The Xhuul Horn Exchange, over the radio. Their drone takes what you sell and
## drops what you buy on the porch.

var tabs: TabContainer
var money: Label


func panel_title() -> String:
	return "XHUUL HORN EXCHANGE"


func panel_size() -> Vector2:
	return Vector2(1080, 700)


func build() -> void:
	money = UIStyle.label("", 20, Color(1.0, 0.85, 0.45), UIStyle.bold())
	box.add_child(money)
	box.add_child(UIStyle.label("L1 / R1: switch tabs" if Game.using_pad else "X: next tab", 13, UIStyle.DIM))
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	refresh()
	Game.changed.connect(_on_changed)


func _on_changed() -> void:
	if is_inside_tree():
		refresh.call_deferred()


func close() -> void:
	if Game.changed.is_connected(_on_changed):
		Game.changed.disconnect(_on_changed)
	super.close()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("next_gun") or e.is_action_pressed("blink"):
		tabs.current_tab = (tabs.current_tab + 1) % tabs.get_tab_count()
		focus_first.call_deferred()
		get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("breath") and e is InputEventJoypadButton:
		tabs.current_tab = (tabs.current_tab - 1 + tabs.get_tab_count()) % tabs.get_tab_count()
		focus_first.call_deferred()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(e)


func refresh() -> void:
	var cur := tabs.current_tab
	for c in tabs.get_children():
		tabs.remove_child(c)
		c.queue_free()
	money.text = "%d scrip   ·   Rank %d %s   ·   Pack %d/%d" % [Game.scrip, Game.rank(), Catalog.RANK_NAMES[Game.rank() - 1], Game.carried.size(), Game.capacity()]
	_sell_tab()
	_guns_tab()
	_ammo_tab()
	_gear_tab()
	_contracts_tab()
	tabs.current_tab = clampi(cur, 0, tabs.get_tab_count() - 1)
	focus_first.call_deferred()


func _tab(name: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = name
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	return v


func _row(v: VBoxContainer, title: String, sub: String, right: String, buttons: Array, col: Color = UIStyle.BONE) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.panel(Color(0.12, 0.1, 0.08, 0.85), Color(0.3, 0.25, 0.2, 0.6)))
	v.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	tv.add_child(UIStyle.label(title, 20, col, UIStyle.title()))
	if sub != "":
		var s := UIStyle.label(sub, 15, UIStyle.DIM, UIStyle.body())
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.custom_minimum_size = Vector2(600, 0)
		tv.add_child(s)
	if right != "":
		var r := UIStyle.label(right, 18, Color(1.0, 0.85, 0.45), UIStyle.bold())
		r.custom_minimum_size = Vector2(120, 0)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(r)
	for b in buttons:
		h.add_child(b)


func _sell_tab() -> void:
	var v := _tab("SELL")
	var hot: Array = []
	for k in Game.hot_species():
		hot.append("%s x%.2f" % [Catalog.SPECIES[k]["name"], Game.market_mult(k)])
	var cold: Array = []
	for k in Game.market.keys():
		if Game.market_mult(k) < 0.9:
			cold.append("%s x%.2f" % [Catalog.SPECIES[k]["name"], Game.market_mult(k)])
	v.add_child(UIStyle.label("TODAY ON THE EXCHANGE   ·   HOT: %s   ·   OUT OF FASHION: %s" % [", ".join(hot), ", ".join(cold)], 15, Color(1.0, 0.85, 0.45), UIStyle.bold()))
	if Game.carried.is_empty():
		v.add_child(UIStyle.label("You're not carrying anything. Hunt, then hold E over the carcass to harvest the hide and horns.", 18, UIStyle.DIM))
		return
	var total := 0
	for i in Game.carried.size():
		var t: Dictionary = Game.carried[i]
		var sp: Dictionary = Catalog.SPECIES[t["species"]]
		var val := Game.value_of(t)
		total += val
		var idx := i
		var btns := [UIStyle.button("SELL", func() -> void:
			var got := Game.sell(idx)
			Sfx.play("cash", -4.0)
			Game.say("Sold for %d scrip." % got, Color(1.0, 0.85, 0.45)))]
		if t["kind"] == "horn":
			var title := "%s %s  ·  %.1f  %s" % [sp["name"], "fangs" if t["species"] == "howler" else "horns", float(t["score"]), t["class"]]
			btns.append(UIStyle.button("MOUNT ON WALL", func() -> void:
				Game.mount(idx)
				world.structures.refresh_wall()
				Game.say("Mounted in the farmhouse. Every visitor will ask about it.", Color(0.9, 0.85, 0.6))))
			_row(v, title, "Trophy horns. Mount them for prestige (rank XP) or sell them to the Xhuul.", "%d" % val, btns, Catalog.class_color(t["class"]))
		else:
			_row(v, "%s hide  ·  %s (%d%%)" % [sp["name"], Catalog.hide_grade(float(t["quality"])), int(t["quality"])], "Every hole costs. Heart and brain shots keep a hide whole; plasma cooks it.", "%d" % val, btns)
	v.add_child(UIStyle.button("SELL EVERYTHING  (%d scrip)" % total, func() -> void:
		var sum := 0
		while not Game.carried.is_empty():
			sum += Game.sell(0)
		Sfx.play("cash", -2.0)
		Game.say("Sold the lot for %d scrip." % sum, Color(1.0, 0.85, 0.45))))


func _guns_tab() -> void:
	var v := _tab("GUNS")
	for k in Catalog.WEAPONS.keys():
		var w: Dictionary = Catalog.WEAPONS[k]
		var why := Game.can_buy_weapon(k)
		var key: String = k
		var b := UIStyle.button("OWNED" if why == "owned" else ("BUY" if why == "" else why.to_upper()), func() -> void:
			if Game.buy_weapon(key):
				Sfx.play("cash", -4.0)
				world.player.equip(key)
				Game.say("%s delivered to the porch." % w["name"], UIStyle.GOOD), 130)
		b.disabled = why != ""
		var z: Array = w["zoom"]
		var stats := "DMG %d · %d m/s · mag %d · %s · noise %d m · hide damage %s" % [int(w["dmg"]), int(w["vel"]), int(w["mag"]), "iron sights" if z.is_empty() else ("scope " + "/".join(z.map(func(x: float) -> String: return "%dx" % int(x)))), int(w["noise"]), "low" if float(w["hide"]) < 8.0 else ("high" if float(w["hide"]) > 20.0 else "medium")]
		_row(v, "%s   ·   rank %d" % [w["name"], int(w["rank"])], String(w["desc"]) + "\n" + stats, "%d" % int(w["price"]) if int(w["price"]) > 0 else "", [b], UIStyle.BONE if why != "" and why != "owned" else Color(1.0, 0.9, 0.7))


func _ammo_tab() -> void:
	var v := _tab("AMMO")
	for k in Catalog.AMMO.keys():
		var a: Dictionary = Catalog.AMMO[k]
		var usable := false
		for w in Game.weapons:
			if Catalog.WEAPONS[w]["ammo"] == k:
				usable = true
		if not usable:
			continue
		var key: String = k
		var b := UIStyle.button("BUY %d" % int(a["pack"]), func() -> void:
			if Game.buy_ammo(key):
				Sfx.play("cash", -6.0), 130)
		b.disabled = Game.scrip < int(a["price"])
		_row(v, String(a["name"]), "You have %d." % int(Game.ammo.get(k, 0)), "%d" % int(a["price"]), [b])


func _gear_tab() -> void:
	var v := _tab("GEAR")
	for k in Catalog.GEAR.keys():
		var g: Dictionary = Catalog.GEAR[k]
		if int(g["price"]) == 0:
			continue
		var why := Game.can_buy_gear(k)
		var key: String = k
		var label := "OWNED" if why == "owned" else ("BUY" if why == "" else why.to_upper())
		if g.has("uses") and Game.gear.has(k):
			label = ("BUY (have %d)" % int(Game.gear[k])) if why == "" else label
		var b := UIStyle.button(label, func() -> void:
			if Game.buy_gear(key):
				Sfx.play("cash", -4.0)
				world.call("_tracker_glow")
				Game.say("%s: delivered." % g["name"], UIStyle.GOOD), 150)
		b.disabled = why != ""
		_row(v, "%s   ·   rank %d" % [g["name"], int(g["rank"])], String(g["desc"]), "%d" % int(g["price"]), [b])


func _contracts_tab() -> void:
	var v := _tab("CONTRACTS")
	v.add_child(UIStyle.label("The Exchange's clients want these. Bring the goods to this radio (sell or mount them) and it's paid on the spot. Heart-shot jobs pay the moment the animal drops.", 16, UIStyle.DIM))
	for c in Game.contracts:
		_row(v, String(c["text"]), "+%d XP" % int(c["xp"]), "%d" % int(c["pay"]), [])
	if Game.contracts.is_empty():
		v.add_child(UIStyle.label("Nothing on the board. Check back tomorrow.", 18, UIStyle.DIM))
