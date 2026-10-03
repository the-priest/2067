extends CanvasLayer
## Everything on screen while you hunt: the compass and the wind, the glass
## and the scope, what your shot hit, your pack, your rank, Blorvak on the radio, Dale in your ear.

var world: Node
var root: Control
var draw: Control
var toasts: VBoxContainer
var prompt: Label
var hold_bar: ProgressBar
var info: Label
var hit_lbl: Label
var banner: Label
var banner_sub: Label
var radio_box: PanelContainer
var radio_lbl: Label
var goal_lbl: Label
var clock_lbl: Label
var ammo_lbl: Label
var gun_lbl: Label
var pack_lbl: Label
var scrip_lbl: Label
var rank_lbl: Label
var hp_bar: ProgressBar
var st_bar: ProgressBar
var xp_bar: ProgressBar
var fade_rect: ColorRect
var tint: ColorRect
var hint_lbl: Label
var _hit_t := 0.0
var _banner_t := 0.0
var _radio_t := 0.0
var _radio_full := ""
var _radio_shown := 0.0
var _thermal := false
var _cloak := false
var _panel: Control = null


func setup(w: Node) -> void:
	world = w
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	add_child(root)
	tint = ColorRect.new()
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.color = Color(0, 0, 0, 0)
	root.add_child(tint)
	draw = Control.new()
	draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw.draw.connect(_draw_overlay)
	root.add_child(draw)
	# Top left: what you're doing.
	var tl := VBoxContainer.new()
	tl.position = Vector2(24, 18)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tl)
	clock_lbl = UIStyle.label("", 16, UIStyle.DIM, UIStyle.bold())
	tl.add_child(clock_lbl)
	goal_lbl = UIStyle.label("", 18, UIStyle.BONE, UIStyle.body())
	goal_lbl.custom_minimum_size = Vector2(420, 0)
	goal_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.add_child(goal_lbl)
	# Toasts, top right.
	toasts = VBoxContainer.new()
	toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toasts.position = Vector2(-520, 70)
	toasts.custom_minimum_size = Vector2(500, 0)
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toasts)
	# Bottom left: you.
	var bl := VBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.position = Vector2(24, -150)
	bl.add_theme_constant_override("separation", 4)
	root.add_child(bl)
	rank_lbl = UIStyle.label("", 18, UIStyle.BONE, UIStyle.title())
	bl.add_child(rank_lbl)
	xp_bar = _bar(Color(0.95, 0.75, 0.35), 260, 5)
	bl.add_child(xp_bar)
	hp_bar = _bar(Color(0.85, 0.3, 0.25), 260, 9)
	bl.add_child(hp_bar)
	st_bar = _bar(Color(0.8, 0.8, 0.7), 260, 5)
	bl.add_child(st_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	bl.add_child(row)
	scrip_lbl = UIStyle.label("", 18, Color(1.0, 0.85, 0.45), UIStyle.bold())
	row.add_child(scrip_lbl)
	pack_lbl = UIStyle.label("", 18, UIStyle.BONE, UIStyle.bold())
	row.add_child(pack_lbl)
	# Bottom right: the gun.
	var br := VBoxContainer.new()
	br.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br.position = Vector2(-380, -110)
	br.custom_minimum_size = Vector2(356, 0)
	root.add_child(br)
	gun_lbl = UIStyle.label("", 20, UIStyle.BONE, UIStyle.title())
	gun_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(gun_lbl)
	ammo_lbl = UIStyle.label("", 30, UIStyle.BONE, UIStyle.title())
	ammo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(ammo_lbl)
	hint_lbl = UIStyle.label("", 14, UIStyle.DIM, UIStyle.body())
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(hint_lbl)
	# Centre: prompt, info, hits.
	prompt = UIStyle.label("", 20, UIStyle.BONE, UIStyle.bold())
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_preset(Control.PRESET_CENTER)
	prompt.position = Vector2(-400, 70)
	prompt.custom_minimum_size = Vector2(800, 0)
	root.add_child(prompt)
	hold_bar = _bar(UIStyle.TEAL, 240, 6)
	hold_bar.set_anchors_preset(Control.PRESET_CENTER)
	hold_bar.position = Vector2(-120, 104)
	hold_bar.visible = false
	root.add_child(hold_bar)
	info = UIStyle.label("", 18, UIStyle.BONE, UIStyle.bold())
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.set_anchors_preset(Control.PRESET_CENTER)
	info.position = Vector2(-400, 36)
	info.custom_minimum_size = Vector2(800, 0)
	root.add_child(info)
	hit_lbl = UIStyle.label("", 26, Color.WHITE, UIStyle.title())
	hit_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hit_lbl.set_anchors_preset(Control.PRESET_CENTER)
	hit_lbl.position = Vector2(-300, -90)
	hit_lbl.custom_minimum_size = Vector2(600, 0)
	root.add_child(hit_lbl)
	banner = UIStyle.label("", 46, Color(1.0, 0.85, 0.4), UIStyle.title())
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.position = Vector2(-500, 150)
	banner.custom_minimum_size = Vector2(1000, 0)
	root.add_child(banner)
	banner_sub = UIStyle.label("", 20, UIStyle.BONE, UIStyle.body())
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_sub.position = Vector2(-500, 214)
	banner_sub.custom_minimum_size = Vector2(1000, 0)
	root.add_child(banner_sub)
	# Blorvak, on the radio.
	radio_box = PanelContainer.new()
	radio_box.add_theme_stylebox_override("panel", UIStyle.panel(Color(0.05, 0.08, 0.07, 0.9), Color(0.3, 0.8, 0.6, 0.7)))
	radio_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	radio_box.position = Vector2(-380, -250)
	radio_box.custom_minimum_size = Vector2(760, 0)
	radio_box.visible = false
	root.add_child(radio_box)
	var rv := VBoxContainer.new()
	radio_box.add_child(rv)
	rv.add_child(UIStyle.label("COMMISSIONER BLORVAK  ·  XHUUL HORN EXCHANGE", 14, UIStyle.TEAL, UIStyle.bold()))
	radio_lbl = UIStyle.label("", 18, UIStyle.BONE, UIStyle.body())
	radio_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	radio_lbl.custom_minimum_size = Vector2(730, 0)
	rv.add_child(radio_lbl)
	fade_rect = ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)
	Game.toast.connect(_toast)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _bar(c: Color, w: float, h: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(w, h)
	b.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(2)
	var fg := StyleBoxFlat.new()
	fg.bg_color = c
	fg.set_corner_radius_all(2)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _toast(t: String, c: Color) -> void:
	var p := PanelContainer.new()
	var sb := UIStyle.panel(Color(0.06, 0.05, 0.04, 0.82), Color(c.r, c.g, c.b, 0.5))
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	var l := UIStyle.label(t, 17, c, UIStyle.bold())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(470, 0)
	p.add_child(l)
	toasts.add_child(p)
	while toasts.get_child_count() > 6:
		toasts.get_child(0).queue_free()
	var tw := p.create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.8)
	tw.tween_callback(p.queue_free)


func hit_marker(res: Dictionary, dist: float) -> void:
	var o: String = res.get("organ", "")
	var col := {"HEADSHOT": Color(1.0, 0.3, 0.3), "HEART": Color(1.0, 0.25, 0.35), "BRAIN": Color(1.0, 0.3, 0.9), "SPINE": Color(1.0, 0.6, 0.2), "LUNGS": Color(0.4, 0.8, 1.0), "GUT": Color(0.8, 0.75, 0.3), "NECK": Color(1.0, 0.7, 0.5)}.get(o, Color(0.9, 0.9, 0.85)) as Color
	hit_lbl.text = "%s   %d m" % [o, int(dist)]
	hit_lbl.add_theme_color_override("font_color", col)
	_hit_t = 2.0


func kill_banner(verdict: String, c: Node) -> void:
	banner.text = verdict
	var cr := c as Creature
	var cls := Catalog.horn_class(float(cr.horn["score"]), cr.species)
	banner_sub.text = "%s  ·  hide %s  ·  %s %.1f %s" % [cr.name_text(), Catalog.hide_grade(cr.hide_q), "fangs" if cr.species == "howler" else "horns", float(cr.horn["score"]), cls]
	banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4) if verdict.contains("HEART") or verdict.contains("CLEAN") else UIStyle.BONE)
	_banner_t = 4.5
	if verdict == "PERFECT HEART SHOT":
		Sfx.play("rank", -6.0)


func radio(msg: String) -> void:
	_radio_full = msg
	_radio_shown = 0.0
	_radio_t = 8.0 + msg.length() * 0.05
	radio_box.visible = true


var _sub_lbl: Label = null
var _sub_t := 0.0
var _alert_t := 0.0


## Someone talking: a subtitle at the bottom of the screen.
func subtitle(who: String, text: String, col: Color, secs: float = 0.0) -> void:
	if _sub_lbl == null:
		_sub_lbl = UIStyle.label("", 20, UIStyle.BONE, UIStyle.body())
		_sub_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_sub_lbl.position = Vector2(-520, -150)
		_sub_lbl.custom_minimum_size = Vector2(1040, 0)
		_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sub_lbl.add_theme_constant_override("outline_size", 6)
		_sub_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		root.add_child(_sub_lbl)
	_sub_lbl.text = "%s:  %s" % [who, text]
	_sub_lbl.add_theme_color_override("font_color", col)
	_sub_t = secs if secs > 0.0 else 3.0 + text.length() * 0.06
	_sub_lbl.visible = true


## A big moment at the carcass: a record, or a diamond or mythic set.
func record_banner(kind: String, sp_name: String, score: float, cls: String) -> void:
	match kind:
		"hall":
			banner.text = "NEW ALL-TIME RECORD"
		"species":
			banner.text = "NEW %s RECORD" % sp_name.to_upper()
		_:
			banner.text = "%s TROPHY" % cls
	banner_sub.text = "%s  ·  %.1f  ·  %s" % [sp_name, score, cls]
	banner.add_theme_color_override("font_color", Catalog.class_color(cls))
	_banner_t = 6.0
	Sfx.play("rank", -2.0)


func radio_alert(t: String) -> void:
	banner.text = t
	banner.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	banner_sub.text = "Something is drawing them to the farm."
	_banner_t = 5.0
	Sfx.play("scanner", 0.0, 0.5)


func fade() -> void:
	var tw := create_tween()
	fade_rect.color.a = 1.0
	tw.tween_property(fade_rect, "color:a", 0.0, 1.6)


func thermal(on: bool) -> void:
	_thermal = on


func cloak(on: bool) -> void:
	_cloak = on


# ---------------------------------------------------------------- per frame

func _process(dt: float) -> void:
	var p: Player = world.player
	if p == null:
		return
	clock_lbl.text = "DAY %d  ·  %s%s" % [Game.day, Game.clock(), "  ·  NIGHT" if Game.is_night() else ""]
	goal_lbl.text = world.story_goal() + ("\nContracts on the board: %d" % Game.contracts.size())
	var r := Game.rank()
	rank_lbl.text = "%s  ·  RANK %d" % [Catalog.RANK_NAMES[r - 1].to_upper(), r]
	var lo := int(Catalog.RANKS[r - 1])
	var hi := int(Catalog.RANKS[mini(r, Catalog.RANKS.size() - 1)])
	xp_bar.value = 100.0 if hi <= lo else float(Game.xp - lo) / float(hi - lo) * 100.0
	hp_bar.value = p.health
	st_bar.value = p.stamina
	scrip_lbl.text = "%d scrip" % Game.scrip
	pack_lbl.text = "PACK %d/%d" % [Game.carried.size(), Game.capacity()]
	if p.binos:
		gun_lbl.text = "BINOCULARS"
		ammo_lbl.text = ""
	else:
		var w := p.weapon()
		gun_lbl.text = String(w.get("name", "")).to_upper()
		var a: String = w.get("ammo", "")
		ammo_lbl.text = "%d  /  %d" % [int(Game.mag.get(p.gun_kind, 0)), int(Game.ammo.get(a, 0))]
		if p.reloading > 0.0:
			ammo_lbl.text = "RELOADING"
	var hints := ["%s glass" % Game.key("binos"), "%s reload" % Game.key("reload"), "%s next gun" % Game.key("next_gun")]
	if Game.has("caller"):
		hints.append("%s caller" % Game.key("caller"))
	if Game.has("scent"):
		hints.append("%s scent x%d" % [Game.key("scent"), int(Game.gear["scent"])])
	if Game.has("cloak"):
		hints.append("%s cloak %d%%" % [Game.key("cloak"), int(p.cloak_energy)])
	if Game.has("drone"):
		hints.append("%s drone" % Game.key("drone"))
	if Game.has("thermal"):
		hints.append("%s thermal" % Game.key("thermal"))
	hints.append("%s light" % Game.key("flash"))
	hints.append("%s map / fast travel / shop" % Game.key("map"))
	hint_lbl.text = "  ".join(hints)
	# Prompt.
	var it: Object = p.interact_target
	if it != null and not world.ui_open():
		prompt.text = "[%s] %s" % [Game.key("use"), String(it.call("interact_text"))]
		var hold: float = it.call("interact_hold")
		hold_bar.visible = hold > 0.0 and p.harvest_t > 0.0
		if hold_bar.visible:
			hold_bar.value = p.harvest_t / hold * 100.0
	else:
		prompt.text = ""
		hold_bar.visible = false
	# What you're looking at.
	var t := ""
	if p.aiming > 0.8 and p.aim_creature != null:
		t = p.aim_creature.glass_info()
		if Game.has("rangefinder"):
			t += "   %d m" % int(p.cam.global_position.distance_to(p.aim_creature.center()))
		var aw := p.aim_creature.awareness
		if aw > 0.35 and not p.aim_creature.dead:
			t += "   [ALERT]" if aw < 1.0 else "   [SPOOKED]"
	elif p.aiming > 0.8 and Game.has("rangefinder") and p.range_m > 0.0:
		t = "%d m" % int(p.range_m)
	info.text = t
	if _sub_lbl != null:
		_sub_t -= dt
		_sub_lbl.visible = _sub_t > 0.0 and radio_box.visible == false
	var f: Farm = world.farm
	if f != null and f.raid_on:
		goal_lbl.text = "RAID ON THE FARM: %d left  ·  wall %d/%d\n%s" % [f.raid_ghouls.size(), int(Game.wall_hp), int(f.max_wall()), world.story_goal()]
	_hit_t -= dt
	hit_lbl.visible = _hit_t > 0.0
	_banner_t -= dt
	banner.visible = _banner_t > 0.0
	banner_sub.visible = _banner_t > 0.0
	if _radio_t > 0.0:
		_radio_t -= dt
		_radio_shown += dt * 55.0
		radio_lbl.text = _radio_full.substr(0, int(_radio_shown))
		if _radio_t <= 0.0:
			radio_box.visible = false
	var tc := Color(0, 0, 0, 0)
	if _cloak:
		tc = Color(0.2, 0.6, 0.7, 0.12)
	if p.hurt_flash > 0.0:
		tc = Color(0.6, 0.0, 0.0, p.hurt_flash * 0.5)
	elif p.health < 35.0:
		tc = Color(0.5, 0.0, 0.0, (35.0 - p.health) / 35.0 * 0.3 * (0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.006)))
	tint.color = tc
	draw.queue_redraw()


func _unhandled_input(e: InputEvent) -> void:
	if world == null or not world.ready_done:
		return
	if _panel != null and is_instance_valid(_panel):
		if e.is_action_pressed("pause") or e.is_action_pressed("map") and _panel.name == "Map" or e.is_action_pressed("journal") and _panel.name == "Journal" or e.is_action_pressed("help") and _panel.name == "Help":
			_close_panel()
			get_viewport().set_input_as_handled()
		return
	if world.ui_open():
		return
	if e.is_action_pressed("pause"):
		_open_panel(load("res://ui/pause.gd").new())
	elif e.is_action_pressed("map"):
		_open_panel(load("res://ui/map.gd").new())
	elif e.is_action_pressed("journal") or e.is_action_pressed("inv"):
		_open_panel(load("res://ui/journal.gd").new())
	elif e.is_action_pressed("help"):
		_open_panel(load("res://ui/help.gd").new())


func _open_panel(n: Control) -> void:
	_panel = n
	n.call("setup", world)
	add_child(n)
	n.tree_exited.connect(func() -> void: _panel = null)


func _close_panel() -> void:
	if _panel != null:
		_panel.call("close")
		_panel = null


# ---------------------------------------------------------------- drawing

func _draw_overlay() -> void:
	var p: Player = world.player
	var sz := draw.size
	var c := sz * 0.5
	if p.in_drone:
		_draw_drone(sz)
		return
	if p.scoped:
		if p.binos:
			_draw_binos(sz)
		else:
			_draw_scope(sz, p)
	elif not world.ui_open():
		var a := 1.0 - p.aiming * 0.7
		var col := Color(1, 1, 1, 0.75 * a)
		if p.aim_creature != null and p.aiming > 0.5:
			col = Color(1.0, 0.85, 0.5, 0.9)
		draw.draw_circle(c, 2.0, col)
		if p.aiming < 0.5:
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw.draw_line(c + d * 8.0, c + d * 15.0, Color(1, 1, 1, 0.5 * a), 1.5)
	_draw_compass(sz, p)
	_draw_tags(p)


func _draw_scope(sz: Vector2, p: Player) -> void:
	var c := sz * 0.5
	var r := minf(sz.x, sz.y) * 0.46
	var black := Color(0, 0, 0, 1)
	# Black outside the glass.
	draw.draw_rect(Rect2(0, 0, c.x - r, sz.y), black)
	draw.draw_rect(Rect2(c.x + r, 0, sz.x - c.x - r, sz.y), black)
	draw.draw_arc(c, r + 500.0, 0, TAU, 180, black, 1000.0)
	# Vignette ring.
	for i in 14:
		draw.draw_arc(c, r - i * 2.5, 0, TAU, 128, Color(0, 0, 0, 0.42 - i * 0.03), 3.0)
	var rc := Color(0.02, 0.02, 0.02, 0.95) if not _thermal else Color(0.1, 1.0, 0.4, 0.9)
	# Duplex reticle with mil dots.
	draw.draw_line(Vector2(c.x - r, c.y), Vector2(c.x - r * 0.18, c.y), rc, 5.0)
	draw.draw_line(Vector2(c.x + r * 0.18, c.y), Vector2(c.x + r, c.y), rc, 5.0)
	draw.draw_line(Vector2(c.x, c.y + r * 0.18), Vector2(c.x, c.y + r), rc, 5.0)
	draw.draw_line(Vector2(c.x, c.y - r), Vector2(c.x, c.y - r * 0.18), rc, 5.0)
	draw.draw_line(Vector2(c.x - r * 0.18, c.y), Vector2(c.x + r * 0.18, c.y), rc, 1.2)
	draw.draw_line(Vector2(c.x, c.y - r * 0.18), Vector2(c.x, c.y + r * 0.18), rc, 1.2)
	for i in range(1, 5):
		var o := r * 0.04 * i
		draw.draw_circle(Vector2(c.x, c.y + o), 2.0, rc)
		draw.draw_circle(Vector2(c.x + o, c.y), 1.6, rc)
		draw.draw_circle(Vector2(c.x - o, c.y), 1.6, rc)
	# Illuminated centre dot.
	draw.draw_circle(c, 2.2, Color(1.0, 0.2, 0.1, 0.9))
	var f := UIStyle.bold()
	var w := p.weapon()
	var zooms: Array = w.get("zoom", [])
	if not zooms.is_empty():
		draw.draw_string(f, Vector2(c.x + r * 0.55, c.y + r * 0.75), "%dx" % int(zooms[mini(p.zoom_i, zooms.size() - 1)]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 0.9, 0.85))
		if zooms.size() > 1:
			draw.draw_string(f, Vector2(c.x + r * 0.55, c.y + r * 0.75 + 22), "D-pad: zoom" if Game.using_pad else "wheel: zoom", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.7, 0.65))
	# Breath.
	var bw := 160.0
	var by := c.y + r * 0.88
	draw.draw_rect(Rect2(c.x - bw * 0.5, by, bw, 5), Color(0, 0, 0, 0.6))
	draw.draw_rect(Rect2(c.x - bw * 0.5, by, bw * p.breath / 100.0, 5), Color(0.8, 0.9, 1.0, 0.9) if not p.holding_breath else Color(1.0, 0.9, 0.5, 0.95))
	draw.draw_string(f, Vector2(c.x - 90, by - 8), ("%s: hold breath" % Game.key("breath")) if not p.holding_breath else "holding...", HORIZONTAL_ALIGNMENT_CENTER, 180, 14, Color(0.85, 0.85, 0.8))
	if Game.scanner_level() > 0:
		draw.draw_string(f, Vector2(c.x - r * 0.75, c.y + r * 0.75), "HEART SCAN Mk %d" % Game.scanner_level(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.4, 0.5))


func _draw_binos(sz: Vector2) -> void:
	var c := sz * 0.5
	var r := minf(sz.x, sz.y) * 0.4
	var black := Color(0, 0, 0, 1)
	var img_steps := 48
	# Two overlapping circles; paint black around them by bands.
	for y in range(0, int(sz.y), 4):
		var fy := float(y) + 2.0
		var dy := fy - c.y
		if absf(dy) >= r:
			draw.draw_rect(Rect2(0, y, sz.x, 4), black)
			continue
		var hw := sqrt(r * r - dy * dy)
		var l := c.x - r * 0.55 - hw
		var rr := c.x + r * 0.55 + hw
		draw.draw_rect(Rect2(0, y, l, 4), black)
		draw.draw_rect(Rect2(rr, y, sz.x - rr, 4), black)
	draw.draw_line(Vector2(c.x - 30, c.y), Vector2(c.x + 30, c.y), Color(0, 0, 0, 0.5), 1.0)
	for i in range(-3, 4):
		draw.draw_line(Vector2(c.x + i * 10, c.y - 4), Vector2(c.x + i * 10, c.y + 4), Color(0, 0, 0, 0.5), 1.0)


func _draw_drone(sz: Vector2) -> void:
	var c := sz * 0.5
	var col := Color(0.6, 1.0, 0.9, 0.8)
	for k: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var o := c + k * Vector2(sz.x * 0.4, sz.y * 0.38)
		draw.draw_line(o, o - Vector2(k.x * 40, 0), col, 2.0)
		draw.draw_line(o, o - Vector2(0, k.y * 40), col, 2.0)
	draw.draw_arc(c, 24, 0, TAU, 40, col, 1.5)
	draw.draw_string(UIStyle.bold(), Vector2(40, sz.y - 40), "RECON DRONE  ·  %ds  ·  G to land" % int(world._drone_t), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
	_draw_tags(world.player)


func _draw_compass(sz: Vector2, p: Player) -> void:
	var w := 520.0
	var x0 := sz.x * 0.5 - w * 0.5
	var y := 26.0
	var cam := p.get_viewport().get_camera_3d()
	var fwd := -cam.global_transform.basis.z
	var yaw := atan2(fwd.x, -fwd.z) # 0 = north (-z), clockwise
	draw.draw_rect(Rect2(x0, y - 14, w, 30), Color(0, 0, 0, 0.35))
	var f := UIStyle.bold()
	var span := deg_to_rad(110.0)
	for i in 72:
		var a := deg_to_rad(i * 5.0)
		var d := wrapf(a - yaw, -PI, PI)
		if absf(d) > span * 0.5:
			continue
		var x := sz.x * 0.5 + d / span * w
		var major := i % 9 == 0
		draw.draw_line(Vector2(x, y + 8), Vector2(x, y + (2 if major else 5)), Color(1, 1, 1, 0.6), 1.0)
		if major:
			var names := {0: "N", 9: "E", 18: "S", 27: "W"}
			var t: String = names.get(i, "%d" % (i * 5))
			draw.draw_string(f, Vector2(x - 20, y - 0), t, HORIZONTAL_ALIGNMENT_CENTER, 40, 16 if names.has(i) else 12, UIStyle.BONE if names.has(i) else UIStyle.DIM)
	draw.draw_line(Vector2(sz.x * 0.5, y + 10), Vector2(sz.x * 0.5, y + 16), UIStyle.RUST, 2.0)
	# The farm on the compass.
	var fp := Vector3(Terrain.FARM.x, 0, Terrain.FARM.y) - p.global_position
	_compass_mark(sz, w, y, yaw, span, atan2(fp.x, -fp.z), Color(1.0, 0.8, 0.4), "HOME")
	# The wind.
	if Game.has("wind"):
		var wd: Vector2 = world.atmo.wind_dir
		var wa := atan2(wd.x, -wd.y)
		var d2 := wrapf(wa - yaw, -PI, PI)
		var wc := Vector2(sz.x * 0.5 + w * 0.5 + 40, y + 2)
		var dirv := Vector2(sin(d2), -cos(d2))
		draw.draw_circle(wc, 16, Color(0, 0, 0, 0.4))
		draw.draw_line(wc - dirv * 12, wc + dirv * 12, UIStyle.TEAL, 2.5)
		draw.draw_line(wc + dirv * 12, wc + dirv * 6 + dirv.orthogonal() * 5, UIStyle.TEAL, 2.5)
		draw.draw_line(wc + dirv * 12, wc + dirv * 6 - dirv.orthogonal() * 5, UIStyle.TEAL, 2.5)
		draw.draw_string(f, wc + Vector2(22, 6), "WIND %d" % int(world.atmo.wind_strength * 30.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.TEAL)
		if Time.get_ticks_msec() / 1000.0 < Game.scent_until:
			draw.draw_string(f, wc + Vector2(22, 22), "SCENT MASKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.GOOD)


func _compass_mark(sz: Vector2, w: float, y: float, yaw: float, span: float, a: float, col: Color, t: String) -> void:
	var d := wrapf(a - yaw, -PI, PI)
	d = clampf(d, -span * 0.5, span * 0.5)
	var x := sz.x * 0.5 + d / span * w
	draw.draw_colored_polygon(PackedVector2Array([Vector2(x, y + 12), Vector2(x - 5, y + 20), Vector2(x + 5, y + 20)]), col)
	draw.draw_string(UIStyle.bold(), Vector2(x - 30, y + 34), t, HORIZONTAL_ALIGNMENT_CENTER, 60, 11, col)


## Animals your drone tagged: a marker over each one.
func _draw_tags(p: Player) -> void:
	var cam := p.get_viewport().get_camera_3d()
	var now := Time.get_ticks_msec() / 1000.0
	for c in world.creatures:
		var cr := c as Creature
		if not is_instance_valid(cr) or cr.dead or cr.tagged_until < now:
			continue
		var wp := cr.center() + Vector3(0, 2.0 * cr.size, 0)
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		var col := Color(0.4, 1.0, 0.85, 0.85)
		draw.draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -7), sp + Vector2(6, 0), sp + Vector2(0, 7), sp + Vector2(-6, 0)]), col)
		draw.draw_string(UIStyle.bold(), sp + Vector2(-60, -12), "%s %dm" % [cr.name_text(), int(cam.global_position.distance_to(wp))], HORIZONTAL_ALIGNMENT_CENTER, 120, 12, col)
