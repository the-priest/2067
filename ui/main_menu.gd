extends Node3D
## Title screen: a Moorhorn herd and a Crownelk on a ridge at dusk, ash
## falling, the Ring in the sky.

var cam: Camera3D
var atmo: Atmosphere
var _t := 0.0
var ui: Control
var sub: Control = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var keep_time := Game.time_of_day
	Game.time_of_day = 18.3
	atmo = Atmosphere.new()
	add_child(atmo)
	atmo.paused = true
	atmo.apply_quality()
	Game.time_of_day = keep_time
	atmo.sky_mat.set_shader_parameter("haze", 1.2)
	_ground()
	var fake := MenuWorld.new()
	add_child(fake)
	var spots := [["moorhorn", Vector3(-3, 0, -14), 0.5], ["moorhorn", Vector3(2, 0, -17), -0.4], ["moorhorn", Vector3(6, 0, -12), 2.4], ["crownelk", Vector3(-9, 0, -24), 1.2], ["stagwraith", Vector3(11, 0, -22), -1.9]]
	for i in spots.size():
		var s: Array = spots[i]
		var c := Creature.new()
		add_child(c)
		c.setup(fake, s[0], s[1], 100 + i * 7, i)
		c.rotation.y = s[2]
		c._heading = s[2]
		c.set_physics_process(false)
		c.state = Creature.S.GRAZE if i != 3 else Creature.S.ALERT
		c.threat = Vector3(0, 0, 0)
	cam = Camera3D.new()
	cam.fov = 55.0
	add_child(cam)
	cam.make_current()
	_build_ui()
	Sfx.ambience(true, false)


func _ground() -> void:
	var k := MeshKit.new()
	var n := 60
	var sz := 160.0
	var fn := FastNoiseLite.new()
	fn.frequency = 0.03
	for z in n + 1:
		for x in n + 1:
			var px := -sz * 0.5 + x * sz / n
			var pz := -sz * 0.5 + z * sz / n - 30.0
			var h := fn.get_noise_2d(px, pz) * 2.0 - maxf(0.0, -pz - 40.0) * 0.0
			k.verts.append(Vector3(px, h, pz))
			k.norms.append(Vector3.UP)
			k.cols.append(Color(0.05, 0.15, 0.45, 0))
			k.uvs.append(Vector2(px, pz))
			k.uv2s.append(Vector2.ZERO)
	for z in n:
		for x in n:
			var a := z * (n + 1) + x
			k.idx.append_array([a, a + 1, a + n + 1, a + 1, a + n + 2, a + n + 1])
	k.smooth_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/terrain.gdshader")
	m.set_shader_parameter("noise_a", Tex.get_tex("detail"))
	m.set_shader_parameter("noise_n", Tex.get_tex("detail_n"))
	m.set_shader_parameter("macro", Tex.get_tex("macro"))
	mi.material_override = m
	add_child(mi)


func _process(dt: float) -> void:
	_t += dt
	var a := sin(_t * 0.05) * 0.35
	cam.position = Vector3(sin(a) * 12.0, 2.2, 6.0 + cos(a) * 3.0)
	cam.look_at(Vector3(0, 1.4, -18), Vector3.UP)
	atmo.follow(cam.global_position)


func _build_ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.theme = UIStyle.theme()
	cl.add_child(ui)
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.85))
	g.set_color(1, Color(0, 0, 0, 0.0))
	gt.gradient = g
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	grad.custom_minimum_size = Vector2(760, 0)
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ui.add_child(grad)
	var v := VBoxContainer.new()
	v.position = Vector2(80, 120)
	v.add_theme_constant_override("separation", 12)
	ui.add_child(v)
	v.add_child(UIStyle.label("2067", 120, Color(0.96, 0.87, 0.68), UIStyle.title()))
	v.add_child(UIStyle.label("H O R N F A L L", 30, UIStyle.RUST, UIStyle.title()))
	var tag := UIStyle.label("2031: they came in peace. 2034: we found out what they did to the cows.\n2067: you farm the wasteland, hunt what they made, and sell them the horns.", 22, UIStyle.BONE, UIStyle.body())
	v.add_child(tag)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 24)
	v.add_child(sp)
	if Game.has_save:
		v.add_child(UIStyle.button("CONTINUE THE HUNT", _continue, 340))
	v.add_child(UIStyle.button("NEW HUNT", _new, 340))
	v.add_child(UIStyle.button("WATCH THE INTRO", func() -> void:
		IntroScene.then_scene = "res://ui/main_menu.tscn"
		get_tree().change_scene_to_file("res://ui/intro.tscn"), 340))
	v.add_child(UIStyle.button("SETTINGS", func() -> void: _sub("res://ui/settings_panel.gd"), 340))
	v.add_child(UIStyle.button("FIELD GUIDE", func() -> void: _sub("res://ui/help.gd"), 340))
	v.add_child(UIStyle.button("QUIT", func() -> void: get_tree().quit(), 340))
	for c in v.get_children():
		if c is Button:
			(c as Button).grab_focus.call_deferred()
			break
	var ver := UIStyle.label("v%s   ·   %s" % [ProjectSettings.get_setting("application/config/version"), "Forward+" if not Settings.compat() else "Compatibility renderer"], 14, UIStyle.DIM)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.position = Vector2(20, -34)
	ui.add_child(ver)


func _sub(path: String) -> void:
	var s: Control = load(path).new()
	s.call("setup", null)
	ui.add_child(s)


func _continue() -> void:
	if Game.load_game():
		get_tree().change_scene_to_file("res://ui/game.tscn")


func _new() -> void:
	Game.new_game()
	Game.save_game()
	IntroScene.then_scene = "res://ui/game.tscn"
	get_tree().change_scene_to_file("res://ui/intro.tscn")
