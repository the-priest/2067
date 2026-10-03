class_name IntroScene
extends Node3D
## The intro. 2031 to 2067 in two minutes: the ships over Las Vegas, the
## press conference, the farm, the war, the bombs (and everyone, human and
## Xhuul, running from them), the wasteland, the valley, the farm, Dale.
## Hold A / Space / Enter to skip.

static var then_scene := "res://ui/game.tscn"

var atmo: Atmosphere
var cam: Camera3D
var stage: Node3D
var ui: Control
var caption: Label
var big: Label
var flash: ColorRect
var skip_lbl: Label
var skip_bar: ProgressBar
var _shot := -1
var _scene := ""
var _t := 0.0 # time in this shot
var _st := 0.0 # time in this scene
var _scene_len := 0.0
var _typed := 0.0
var _skip := 0.0
var _update: Callable
var _shake := 0.0
var _fake: MenuWorld
var _done := false
var _rng := RandomNumberGenerator.new()
var _keep_time := 7.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_rng.seed = 2031
	_keep_time = Game.time_of_day
	atmo = Atmosphere.new()
	add_child(atmo)
	atmo.paused = true
	atmo.apply_quality()
	_fake = MenuWorld.new()
	add_child(_fake)
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.far = 6000.0
	add_child(cam)
	cam.make_current()
	_ui()
	Sfx.ambience(true, true)
	_next()


func _ui() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 10
	add_child(cl)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UIStyle.theme()
	cl.add_child(ui)
	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(flash)
	for top: bool in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top:
			bar.custom_minimum_size = Vector2(0, 96)
		else:
			bar.offset_top = -150
		ui.add_child(bar)
	caption = UIStyle.label("", 30, Color(0.96, 0.9, 0.78), UIStyle.body())
	caption.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	caption.position = Vector2(-700, -128)
	caption.custom_minimum_size = Vector2(1400, 0)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.add_child(caption)
	big = UIStyle.label("", 96, Color(0.98, 0.88, 0.62), UIStyle.title())
	big.set_anchors_preset(Control.PRESET_CENTER)
	big.position = Vector2(-800, -120)
	big.custom_minimum_size = Vector2(1600, 0)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_constant_override("outline_size", 10)
	big.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	ui.add_child(big)
	skip_lbl = UIStyle.label("hold A / SPACE to skip", 14, Color(0.7, 0.66, 0.6), UIStyle.bold())
	skip_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_lbl.position = Vector2(-230, 40)
	ui.add_child(skip_lbl)
	skip_bar = ProgressBar.new()
	skip_bar.show_percentage = false
	skip_bar.custom_minimum_size = Vector2(160, 4)
	skip_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_bar.position = Vector2(-230, 62)
	ui.add_child(skip_bar)


func _process(dt: float) -> void:
	if _done:
		return
	_t += dt
	_st += dt
	var shot: Array = Story.INTRO[_shot]
	var txt: String = shot[1]
	var is_title := txt == txt.to_upper() and txt.length() > 0 and txt.length() < 26
	_typed += dt * 42.0
	if is_title:
		big.text = txt
		big.modulate.a = clampf(_t * 1.5, 0.0, 1.0) * clampf((float(shot[2]) - _t) * 2.0, 0.0, 1.0)
		caption.text = ""
	else:
		big.text = ""
		caption.text = txt.substr(0, int(_typed))
		if int(_typed) % 3 == 0 and int(_typed) <= txt.length() and int(_typed) != int(_typed - dt * 42.0):
			Sfx.play("ui", -24.0, 1.6)
	if _update.is_valid():
		_update.call(dt, _st / maxf(_scene_len, 0.01))
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - dt * 1.5)
		cam.position += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * _shake * 0.25
	flash.color.a = maxf(0.0, flash.color.a - dt * 1.2)
	atmo.follow(cam.global_position)
	# Skip.
	if Input.is_action_pressed("jump") or Input.is_action_pressed("ui_accept") or Input.is_action_pressed("use"):
		_skip += dt
	else:
		_skip = maxf(0.0, _skip - dt * 2.0)
	skip_bar.value = _skip / 1.0 * 100.0
	if _skip >= 1.0:
		_finish()
		return
	if _t >= float(shot[2]):
		_next()


func _next() -> void:
	_shot += 1
	if _shot >= Story.INTRO.size():
		_finish()
		return
	_t = 0.0
	_typed = 0.0
	var sc: String = Story.INTRO[_shot][0]
	if sc != _scene:
		_scene = sc
		_st = 0.0
		_scene_len = 0.0
		for i in range(_shot, Story.INTRO.size()):
			if Story.INTRO[i][0] != sc:
				break
			_scene_len += float(Story.INTRO[i][2])
		_build(sc)


func _finish() -> void:
	if _done:
		return
	_done = true
	Game.time_of_day = _keep_time
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(then_scene)


# ---------------------------------------------------------------- scenes

func _build(sc: String) -> void:
	if stage != null:
		stage.queue_free()
	stage = Node3D.new()
	add_child(stage)
	_update = Callable()
	match sc:
		"arrival":
			_time(21.3)
			_ground(Color(0.08, 0.07, 0.07))
			_city(Vector3(0, 0, -260), 1.0, true)
			var ships: Array = []
			for i in 9:
				var s := _saucer(18.0 + _rng.randf() * 30.0)
				s.position = Vector3(_rng.randf_range(-500, 500), 380.0 + _rng.randf() * 200.0, -300.0 - _rng.randf() * 600.0)
				ships.append(s)
			var mother := _saucer(260.0)
			mother.position = Vector3(0, 900.0, -1200.0)
			ships.append(mother)
			_update = func(dt: float, u: float) -> void:
				for s in ships:
					(s as Node3D).position.y -= dt * (6.0 if s != mother else 9.0)
					(s as Node3D).rotate_y(dt * 0.15)
				cam.position = Vector3(0, 2.0 + u * 6.0, 40.0 - u * 30.0)
				cam.look_at(Vector3(0, 60.0 + u * 260.0, -400.0), Vector3.UP)
		"podium":
			_time(13.5)
			_ground(Color(0.35, 0.33, 0.3))
			_city(Vector3(0, 0, -320), 0.6, false)
			var st := MeshKit.new()
			st.box(Vector3(0, 0.6, -14), Vector3(14, 1.2, 6), Color(0.15, 0.17, 0.25))
			st.box(Vector3(0, 1.8, -13), Vector3(1.4, 1.2, 0.8), Color(0.75, 0.75, 0.8))
			_mesh(st)
			for x: float in [-5.0, 5.0]:
				_flag(Vector3(x, 0, -16), "un")
			var g := Humanoid.make("grey", 1)
			stage.add_child(g)
			g.position = Vector3(0, 1.2, -13.8)
			g.rotation.y = PI
			g.set_anim("wave")
			for i in 46:
				var c := Humanoid.make("civilian", 100 + i)
				stage.add_child(c)
				c.position = Vector3(_rng.randf_range(-9, 9), 0, _rng.randf_range(-6, 6))
				c.rotation.y = PI + _rng.randf_range(-0.3, 0.3)
				c.set_anim("cheer" if _rng.randf() < 0.6 else "idle")
				c.speed = _rng.randf_range(0.8, 1.3)
			var sc2 := _saucer(30.0)
			sc2.position = Vector3(0, 60, -90)
			_update = func(dt: float, u: float) -> void:
				sc2.rotate_y(dt * 0.3)
				cam.position = Vector3(-6.0 + u * 10.0, 3.0, 12.0 - u * 6.0)
				cam.look_at(Vector3(0, 2.2, -13), Vector3.UP)
		"farm":
			_time(17.4)
			_ground(Color(0.3, 0.27, 0.16))
			_fence(Vector3(0, 0, 0), 22.0)
			var cows: Array = []
			for i in 4:
				var c := Creature.new()
				stage.add_child(c)
				c.setup(_fake, "moorhorn", Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-10, 2)), 50 + i, i)
				c.set_physics_process(false)
				c.state = Creature.S.GRAZE
				cows.append(c)
			var alien := Humanoid.make("grey", 2)
			stage.add_child(alien)
			alien.position = Vector3(-9, 0, 4)
			alien.set_anim("walk")
			alien.speed = 0.6
			var hearts: Array = []
			for i in 6:
				var hm := _heart()
				hm.visible = false
				hearts.append(hm)
			var saucer := _saucer(14.0)
			saucer.position = Vector3(-30, 25, 30)
			_update = func(dt: float, u: float) -> void:
				var target: Vector3 = (cows[0] as Node3D).global_position
				var to := target - alien.position
				to.y = 0.0
				if to.length() > 2.6:
					alien.position += to.normalized() * dt * 1.2
					alien.rotation.y = atan2(-to.x, -to.z)
				else:
					alien.set_anim("wave")
				for i in hearts.size():
					var hh := hearts[i] as Node3D
					hh.visible = u > 0.45
					var ph := fmod(_st * 0.6 + i * 0.37, 1.0)
					hh.position = alien.position + Vector3(sin(i * 2.0) * 0.8, 2.0 + ph * 3.0, cos(i * 2.0) * 0.8)
					hh.scale = Vector3.ONE * (1.0 - ph) * 0.6
				saucer.rotate_y(dt * 0.4)
				var mid := alien.position.lerp(target, 0.5)
				cam.position = mid + Vector3(5.5 - u * 2.0, 1.6, 6.5 - u * 2.5)
				cam.look_at(mid + Vector3(0, 0.9, 0), Vector3.UP)
		"war":
			_time(11.0)
			_ground(Color(0.3, 0.29, 0.25))
			_flag(Vector3(4, 0, -6), "us")
			for i in 18:
				var s := Humanoid.make("soldier", 200 + i, true)
				stage.add_child(s)
				s.position = Vector3(-14 + (i % 9) * 3.2, 0, (i / 9) * 3.0)
				s.rotation.y = 0.0
				s.set_anim("aim")
			var ships: Array = []
			for i in 5:
				var sh := _saucer(20.0)
				sh.position = Vector3(-120 + i * 60, 90 + _rng.randf() * 40, -260)
				ships.append(sh)
			_update = func(dt: float, u: float) -> void:
				for sh in ships:
					(sh as Node3D).rotate_y(dt * 0.5)
				if _rng.randf() < dt * 6.0:
					var s0: Node3D = ships[_rng.randi() % ships.size()]
					_beam(Vector3(_rng.randf_range(-14, 14), 1.5, 0), s0.position)
					Sfx.play("rifle", -14.0, _rng.randf_range(0.9, 1.2))
				cam.position = Vector3(-18.0 + u * 8.0, 1.7, 9.0)
				cam.look_at(Vector3(0, 6.0 + u * 20.0, -60), Vector3.UP)
		"nukes":
			_time(17.8)
			_ground(Color(0.22, 0.2, 0.18))
			_city(Vector3(0, 0, -900), 1.4, false)
			var runners: Array = []
			for i in 40:
				var kind := "grey" if i % 4 == 0 else "civilian"
				var r := Humanoid.make(kind, 300 + i)
				stage.add_child(r)
				r.position = Vector3(_rng.randf_range(-14, 14), 0, _rng.randf_range(-70, -20))
				r.set_anim("run")
				r.speed = _rng.randf_range(0.9, 1.3)
				runners.append([r, _rng.randf_range(5.5, 8.0)])
			var booms: Array = []
			for i in 4:
				booms.append([_rng.randf_range(0.05, 0.75) if i > 0 else 0.04, Vector3(-500 + i * 330 + _rng.randf_range(-80, 80), 0, -900 - _rng.randf() * 300), null])
			_update = func(dt: float, u: float) -> void:
				for rr in runners:
					var r: Humanoid = rr[0]
					r.position.z += dt * float(rr[1])
					if r.position.z > 12.0:
						r.position.z = -70.0
				for bb in booms:
					if bb[2] == null and u >= float(bb[0]):
						bb[2] = _nuke(bb[1])
						flash.color.a = 1.0
						_shake = 1.6
						Sfx.play("big", 6.0, 0.35)
						Sfx.play("rail", 0.0, 0.3)
					if bb[2] != null:
						_grow_nuke(bb[2], dt)
				cam.position = Vector3(sin(u * 1.2) * 4.0, 1.4, 16.0)
				cam.look_at(Vector3(0, 14.0 + u * 50.0, -300), Vector3.UP)
		"wasteland":
			_time(17.9)
			_ground(Color(0.16, 0.14, 0.12))
			_ruins(1.6, 160.0)
			for i in 10:
				var fp := Vector3(_rng.randf_range(-60, 60), 0.5, _rng.randf_range(-90, -15))
				_fire(fp, _rng.randf_range(1.0, 3.0))
			_update = func(_dt: float, u: float) -> void:
				cam.position = Vector3(-25.0 + u * 40.0, 2.2 + u * 3.0, 12.0)
				cam.look_at(Vector3(0, 3.0, -45), Vector3.UP)
		"valley":
			_time(7.4)
			_ground(Color(0.3, 0.27, 0.17), 45.0)
			_ruins(0.25, 260.0, -90.0)
			var ship := MeshKit.new()
			var pts := PackedVector3Array()
			var rad := PackedFloat32Array()
			for i in 12:
				var uu := float(i) / 11.0
				pts.append(Vector3(0, 0, -100 + uu * 200))
				rad.append(40.0 * pow(sin(PI * clampf(uu, 0.03, 0.97)), 0.6))
			ship.tube(pts, rad, 24, Color(0.18, 0.18, 0.22), true, Vector3.UP, PackedFloat32Array([0.42, 0.42, 0.42, 0.42, 0.42, 0.42, 0.42, 0.42, 0.42, 0.42, 0.42, 0.42]))
			var smi := _mesh(ship)
			var hull := ShaderMaterial.new()
			hull.shader = load("res://shaders/hull.gdshader")
			hull.set_shader_parameter("detail", Tex.get_tex("detail"))
			smi.material_override = hull
			smi.position = Vector3(60, 6, -230)
			smi.rotation = Vector3(0.1, 0.6, 0.12)
			var beasts: Array = []
			for i in 3:
				var c := Creature.new()
				stage.add_child(c)
				c.setup(_fake, ["crownelk", "mammothar", "girafflux"][i], Vector3(-22 + i * 12, 0, -26 - i * 8), 70 + i, i)
				c.set_physics_process(false)
				c.state = Creature.S.WALK
				c._speed = 1.5
				c.rotation.y = -PI * 0.5
				beasts.append(c)
			_update = func(dt: float, u: float) -> void:
				for b in beasts:
					(b as Node3D).position.x += dt * 1.5
				cam.position = Vector3(-34.0 + u * 20.0, 3.0, 8.0)
				cam.look_at(Vector3(10, 6, -110), Vector3.UP)
		"farm2":
			_time(17.2)
			_ground(Color(0.3, 0.27, 0.16))
			var fk := MeshKit.new()
			fk.box(Vector3(0, 1.8, -10), Vector3(10, 3.6, 8), Color(0.6, 0.56, 0.48))
			fk.box(Vector3(0, 0.1, -5.2), Vector3(10, 0.2, 2.6), Color(0.45, 0.34, 0.24))
			fk.box(Vector3(18, 2.8, -14), Vector3(10, 5.6, 14), Color(0.48, 0.17, 0.12))
			for sd: float in [-1.0, 1.0]:
				fk.box(Vector3(0, 4.4, -10 + sd * 2.0), Vector3(10.8, 0.1, 5.0), Color(0.42, 0.3, 0.24), Basis(Vector3.RIGHT, -sd * 0.5))
			_mesh(fk)
			_fence(Vector3(4, 0, -6), 26.0)
			var lt := OmniLight3D.new()
			lt.light_color = Color(1.0, 0.75, 0.45)
			lt.light_energy = 1.2
			lt.omni_range = 6.0
			stage.add_child(lt)
			lt.position = Vector3(-2.5, 2.8, -5.5)
			var dale := Humanoid.make("dale", 7, true)
			stage.add_child(dale)
			dale.position = Vector3(1.5, 0.2, -5.0)
			dale.rotation.y = PI
			dale.set_anim("wave")
			_update = func(_dt: float, u: float) -> void:
				if u > 0.5:
					dale.set_anim("idle")
				cam.position = Vector3(0.2 + u * 0.6, 1.75, -1.2 - u * 0.8)
				cam.look_at(Vector3(1.5, 1.55, -5.0), Vector3.UP)
		"title":
			_time(19.4)
			_ground(Color(0.1, 0.09, 0.08))
			flash.color = Color(0, 0, 0, 0)
			var bg := ColorRect.new()
			bg.color = Color(0.02, 0.015, 0.01)
			bg.set_anchors_preset(Control.PRESET_FULL_RECT)
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ui.add_child(bg)
			ui.move_child(bg, 0)
			var t1 := UIStyle.label("2067", 170, Color(0.97, 0.87, 0.66), UIStyle.title())
			t1.set_anchors_preset(Control.PRESET_CENTER)
			t1.position = Vector2(-400, -170)
			t1.custom_minimum_size = Vector2(800, 0)
			t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ui.add_child(t1)
			var t2 := UIStyle.label("H O R N F A L L", 40, UIStyle.RUST, UIStyle.title())
			t2.set_anchors_preset(Control.PRESET_CENTER)
			t2.position = Vector2(-400, 50)
			t2.custom_minimum_size = Vector2(800, 0)
			t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ui.add_child(t2)
			for n in [t1, t2]:
				(n as Label).modulate.a = 0.0
				var tw := create_tween()
				tw.tween_property(n, "modulate:a", 1.0, 1.5)
			Sfx.play("big", 0.0, 0.5)


func _time(t: float) -> void:
	Game.time_of_day = t
	atmo.tick(0.0)


func _mesh(k: MeshKit) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.85
	mi.material_override = m
	stage.add_child(mi)
	return mi


func _ground(c: Color, mountains: float = 12.0) -> void:
	var k := MeshKit.new()
	var n := 40
	var sz := 3000.0
	var fn := FastNoiseLite.new()
	fn.frequency = 0.004
	for z in n + 1:
		for x in n + 1:
			var px := -sz * 0.5 + x * sz / n
			var pz := -sz * 0.8 + z * sz / n
			var hgt := (fn.get_noise_2d(px, pz) * 0.5 + 0.5) * mountains * 2.0 * smoothstep(80.0, 500.0, Vector2(px, pz).length())
			k.verts.append(Vector3(px, hgt - 0.05, pz))
			k.norms.append(Vector3.UP)
			k.cols.append(Color(0.05, 0.2, 0.5, 0))
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
	Tex.apply_terrain(m)
	mi.material_override = m
	stage.add_child(mi)


## A skyline: blocks with lit windows (Vegas gets neon).
func _city(at: Vector3, scale_: float, neon: bool) -> void:
	var k := MeshKit.new()
	var lit := MeshKit.new()
	for i in 90:
		var x := _rng.randf_range(-700, 700) * scale_
		var z := _rng.randf_range(-200, 200) * scale_
		var w := _rng.randf_range(14, 40) * scale_
		var hgt := _rng.randf_range(20, 160) * scale_ * (1.0 + 1.5 * exp(-x * x / 60000.0))
		var p := at + Vector3(x, hgt * 0.5, z)
		k.box(p, Vector3(w, hgt, w), Color(0.12, 0.12, 0.14).lerp(Color(0.3, 0.3, 0.32), _rng.randf()))
		for j in int(hgt / 8.0):
			if _rng.randf() < 0.45:
				var col := Color(1.0, 0.85, 0.5) if not neon or _rng.randf() < 0.6 else [Color(1.0, 0.2, 0.6), Color(0.2, 0.9, 1.0), Color(1.0, 0.8, 0.2)][_rng.randi() % 3] as Color
				lit.box(p + Vector3(_rng.randf_range(-w * 0.3, w * 0.3), -hgt * 0.5 + j * 8.0 + 4.0, w * 0.51), Vector3(w * 0.4, 1.5, 0.2), col)
	_mesh(k)
	var lm := MeshInstance3D.new()
	lm.mesh = lit.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true
	m.emission_energy_multiplier = 2.5
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.material_override = m
	stage.add_child(lm)


func _saucer(r: float) -> Node3D:
	var n := Node3D.new()
	stage.add_child(n)
	var k := MeshKit.new()
	k.blob(Vector3.ZERO, Vector3(r, r * 0.18, r), Color(0.2, 0.2, 0.24), 8, 24)
	k.blob(Vector3(0, r * 0.12, 0), Vector3(r * 0.4, r * 0.2, r * 0.4), Color(0.25, 0.25, 0.3), 6, 16)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var hull := ShaderMaterial.new()
	hull.shader = load("res://shaders/hull.gdshader")
	hull.set_shader_parameter("detail", Tex.get_tex("detail"))
	mi.material_override = hull
	n.add_child(mi)
	var ring := MeshKit.new()
	for i in 16:
		var a := TAU * i / 16.0
		ring.blob(Vector3(cos(a) * r * 0.85, -r * 0.08, sin(a) * r * 0.85), Vector3.ONE * r * 0.06, Color(0.4, 1.0, 0.85), 4, 6)
	var rm := MeshInstance3D.new()
	rm.mesh = ring.commit()
	var gm := StandardMaterial3D.new()
	gm.vertex_color_use_as_albedo = true
	gm.emission_enabled = true
	gm.emission = Color(0.4, 1.0, 0.85)
	gm.emission_energy_multiplier = 4.0
	rm.material_override = gm
	n.add_child(rm)
	# A light beam down.
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.2
	cm.bottom_radius = r * 0.6
	cm.height = r * 4.0
	beam.mesh = cm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color = Color(0.5, 1.0, 0.9, 0.08)
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = bm
	beam.position.y = -r * 2.0
	n.add_child(beam)
	return n


func _flag(at: Vector3, kind: String) -> void:
	var k := MeshKit.new()
	k.cyl(at, at + Vector3(0, 8, 0), 0.06, 0.05, 6, Color(0.7, 0.7, 0.7))
	_mesh(k)
	var img := Image.create(64, 40, false, Image.FORMAT_RGB8)
	for y in 40:
		for x in 64:
			var c := Color(0.25, 0.45, 0.8)
			if kind == "us":
				c = Color(0.75, 0.1, 0.12) if (y / 3) % 2 == 0 else Color(0.95, 0.95, 0.95)
				if x < 26 and y < 21:
					c = Color(0.12, 0.15, 0.4)
					if x % 4 == 2 and y % 4 == 2:
						c = Color.WHITE
			elif Vector2(x - 32, y - 20).length() < 9.0 and Vector2(x - 32, y - 20).length() > 7.0:
				c = Color.WHITE
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	var q := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3.2, 2.0)
	pm.subdivide_width = 8
	pm.orientation = PlaneMesh.FACE_Z
	q.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material_override = m
	stage.add_child(q)
	q.position = at + Vector3(1.65, 7.0, 0)


func _fence(c: Vector3, r: float) -> void:
	var k := MeshKit.new()
	for i in 40:
		var a := TAU * i / 40.0
		var b := TAU * (i + 1) / 40.0
		var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
		var q := c + Vector3(cos(b) * r, 0, sin(b) * r)
		k.cyl(p + Vector3(0, -0.2, 0), p + Vector3(0, 1.3, 0), 0.07, 0.06, 5, Color(0.36, 0.3, 0.24))
		for y: float in [0.5, 1.0]:
			k.cyl(p + Vector3(0, y, 0), q + Vector3(0, y, 0), 0.03, 0.03, 4, Color(0.4, 0.33, 0.26), false)
	_mesh(k)


func _heart() -> Node3D:
	var k := MeshKit.new()
	k.blob(Vector3(-0.22, 0.1, 0), Vector3(0.28, 0.28, 0.12), Color(1.0, 0.3, 0.55), 6, 8)
	k.blob(Vector3(0.22, 0.1, 0), Vector3(0.28, 0.28, 0.12), Color(1.0, 0.3, 0.55), 6, 8)
	k.cyl(Vector3(0, 0.1, 0), Vector3(0, -0.45, 0), 0.42, 0.02, 8, Color(1.0, 0.3, 0.55))
	var mi := _mesh(k)
	var m := mi.material_override as StandardMaterial3D
	m.emission_enabled = true
	m.emission = Color(1.0, 0.3, 0.55)
	m.emission_energy_multiplier = 2.0
	return mi


func _beam(a: Vector3, b: Vector3) -> void:
	var k := MeshKit.new()
	k.cyl(a, b, 0.15, 0.15, 5, Color(1.0, 0.85, 0.4), false)
	var mi := _mesh(k)
	var m := mi.material_override as StandardMaterial3D
	m.emission_enabled = true
	m.emission = Color(1.0, 0.8, 0.4)
	m.emission_energy_multiplier = 5.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var tw := mi.create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(mi.queue_free)


## A nuclear blast: the fireball, the stem, the cap, the shockwave.
func _nuke(at: Vector3) -> Dictionary:
	var root := Node3D.new()
	stage.add_child(root)
	root.position = at
	var fire := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	fire.mesh = sm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.85, 0.5)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.6, 0.2)
	fm.emission_energy_multiplier = 8.0
	fire.material_override = fm
	root.add_child(fire)
	var stem := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.5
	cm.bottom_radius = 1.0
	cm.height = 1.0
	stem.mesh = cm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.45, 0.35, 0.28)
	smat.emission_enabled = true
	smat.emission = Color(0.9, 0.4, 0.15)
	smat.emission_energy_multiplier = 1.2
	stem.material_override = smat
	root.add_child(stem)
	var cap := MeshInstance3D.new()
	var ck := MeshKit.new()
	ck.blob(Vector3.ZERO, Vector3(1.0, 0.45, 1.0), Color(0.55, 0.42, 0.33), 10, 18, 0.25, 9)
	cap.mesh = ck.commit()
	var cmat := StandardMaterial3D.new()
	cmat.vertex_color_use_as_albedo = true
	cmat.emission_enabled = true
	cmat.emission = Color(1.0, 0.45, 0.15)
	cmat.emission_energy_multiplier = 1.5
	cap.material_override = cmat
	root.add_child(cap)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	ring.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(0.85, 0.75, 0.6, 0.5)
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rmat
	root.add_child(ring)
	var lt := OmniLight3D.new()
	lt.light_color = Color(1.0, 0.6, 0.3)
	lt.light_energy = 16.0
	lt.omni_range = 2500.0
	lt.omni_attenuation = 0.5
	root.add_child(lt)
	return {"t": 0.0, "fire": fire, "stem": stem, "cap": cap, "ring": ring, "light": lt, "fm": fm, "rmat": rmat}


func _grow_nuke(n: Dictionary, dt: float) -> void:
	n["t"] = float(n["t"]) + dt
	var t := float(n["t"])
	var fire: Node3D = n["fire"]
	var stem: Node3D = n["stem"]
	var cap: Node3D = n["cap"]
	var ring: Node3D = n["ring"]
	var r := 40.0 + t * 55.0
	fire.scale = Vector3.ONE * minf(r, 140.0)
	fire.position.y = minf(t * 60.0, 360.0)
	(n["fm"] as StandardMaterial3D).emission_energy_multiplier = maxf(1.0, 8.0 - t * 1.2)
	var sh := minf(t * 60.0, 360.0)
	stem.scale = Vector3(30.0 + t * 4.0, sh, 30.0 + t * 4.0)
	stem.position.y = sh * 0.5
	cap.scale = Vector3.ONE * minf(60.0 + t * 45.0, 260.0)
	cap.position.y = sh + 20.0
	cap.visible = t > 1.0
	fire.visible = t < 4.0
	ring.scale = Vector3(1, 0.05, 1) * (t * 260.0)
	(n["rmat"] as StandardMaterial3D).albedo_color.a = maxf(0.0, 0.6 - t * 0.12)
	(n["light"] as OmniLight3D).light_energy = maxf(0.0, 16.0 - t * 3.0)


func _ruins(density: float = 1.0, spread: float = 300.0, near: float = -12.0) -> void:
	var k := MeshKit.new()
	for i in int(60 * density):
		var p := Vector3(_rng.randf_range(-spread, spread), 0, _rng.randf_range(-spread * 1.3, near))
		var hgt := _rng.randf_range(2.0, 14.0)
		k.box(p + Vector3(0, hgt * 0.5, 0), Vector3(_rng.randf_range(2, 9), hgt, _rng.randf_range(0.3, 6)), Color(0.18, 0.16, 0.14), Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.FORWARD, _rng.randf_range(-0.2, 0.2)))
	for i in int(80 * density):
		var p2 := Vector3(_rng.randf_range(-spread, spread), 0, _rng.randf_range(-spread * 1.3, -10))
		var hgt2 := _rng.randf_range(4.0, 11.0)
		k.cyl(p2 + Vector3(0, -0.5, 0), p2 + Vector3(_rng.randf_range(-1, 1), hgt2, _rng.randf_range(-1, 1)), 0.25, 0.05, 5, Color(0.12, 0.1, 0.09))
	for i in int(25 * density):
		var c := Vector3(_rng.randf_range(-300, 300), -1.5, _rng.randf_range(-400, -30))
		k.blob(c, Vector3(_rng.randf_range(8, 20), 2.0, _rng.randf_range(8, 20)), Color(0.08, 0.07, 0.07), 5, 10, 0.3, i)
	_mesh(k)



func _fire(at: Vector3, s: float) -> void:
	var k := MeshKit.new()
	for i in 5:
		k.blob(Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(0.0, 1.0), _rng.randf_range(-0.5, 0.5)) * s, Vector3(0.5, 0.9, 0.5) * s * _rng.randf_range(0.5, 1.0), Color(1.0, _rng.randf_range(0.35, 0.6), 0.1), 5, 7, 0.4, i)
	var mi := _mesh(k)
	mi.position = at
	var m := mi.material_override as StandardMaterial3D
	m.emission_enabled = true
	m.emission = Color(1.0, 0.45, 0.1)
	m.emission_energy_multiplier = 4.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var lt := OmniLight3D.new()
	lt.light_color = Color(1.0, 0.5, 0.2)
	lt.light_energy = 3.0
	lt.omni_range = 14.0 * s
	stage.add_child(lt)
	lt.position = at + Vector3(0, s, 0)
	var smoke := CPUParticles3D.new()
	smoke.amount = 30
	smoke.lifetime = 6.0
	smoke.direction = Vector3.UP
	smoke.spread = 15.0
	smoke.initial_velocity_min = 1.5
	smoke.initial_velocity_max = 3.0
	smoke.gravity = Vector3(0.6, 0.2, 0)
	smoke.scale_amount_min = 2.0 * s
	smoke.scale_amount_max = 5.0 * s
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.1, 0.09, 0.08, 0.35)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = smat
	smoke.mesh = sm
	stage.add_child(smoke)
	smoke.position = at + Vector3(0, s, 0)
