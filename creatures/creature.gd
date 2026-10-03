class_name Creature
extends CharacterBody3D
## One hybrid. It grazes, wanders its range with its herd, watches, listens
## and smells the wind; it bolts, or (if it's that kind) comes for you.
## Its heart is somewhere in its chest or flank, and nowhere twice the same:
## put a round through it and it runs a few seconds and drops. Lungs: it
## runs far, bleeding hard. Gut: a long, slow trail. The hide remembers
## every hole.

signal killed(c: Creature, info: Dictionary)

enum S { GRAZE, WALK, ALERT, FLEE, CHARGE, STALK, INVESTIGATE, DEAD }

var world: Node = null
var species := "moorhorn"
var sp: Dictionary = {}
var size := 1.0
var horn: Dictionary = {}
var hearts: Array = [] # model-space positions
var heart_r := 0.15
var hp := 100.0
var max_hp := 100.0
var bleed := 0.0 # hp per second
var state := S.GRAZE
var herd_id := 0
var home := Vector3.ZERO
var dead := false
var harvested_hide := false
var harvested_horn := false
var hide_q := 100.0
var shots_taken := 0
var hearts_hit := 0
var heart_killed := false
var death_t := -1.0 # dead run: seconds until it drops
var awareness := 0.0
var threat := Vector3.ZERO
var tagged_until := 0.0
var legendary := false
var last_organ := ""

var model: Node3D
var skin: ShaderMaterial
var horn_mat: ShaderMaterial
var neck: Node3D
var head: Node3D
var tail: Node3D
var hips: Array = [] # [hip Node3D, knee Node3D, front?, side]
var heart_marks: Array = []
var lung_marks: Array = []
var _p: Dictionary
var _target := Vector3.ZERO
var _speed := 0.0
var _heading := 0.0
var _think := 0.0
var _sense := 0.0
var _phase := 0.0
var _graze := 0.0
var _look := 0.0
var _blood_d := 0.0
var _last_pos := Vector3.ZERO
var _charge_cool := 0.0
var _fall := 0.0
var _call_cool := 0.0
var _lie := 0.0
var _flee_from := Vector3.ZERO
var _stuck := 0.0
var _rng := RandomNumberGenerator.new()


func setup(w: Node, kind: String, at: Vector3, sd: int, herd: int) -> void:
	world = w
	species = kind
	sp = Catalog.SPECIES[kind]
	herd_id = herd
	_rng.seed = sd
	legendary = bool(sp.get("legendary", false))
	# The Visitors' blood grows them big.
	size = clampf(_rng.randfn(1.1, 0.12), 0.85, 1.38)
	if _rng.randf() < 0.06 and not legendary:
		size = _rng.randf_range(1.38, 1.6) # an ancient trophy animal
	horn = Horns.roll(kind, _rng, size)
	max_hp = float(sp["hp"]) * size * size
	hp = max_hp
	home = at
	_heading = _rng.randf() * TAU
	_p = BodyBuilder.parts(kind)
	tree_exiting.connect(func() -> void:
		if world != null and world.get("creatures") != null:
			world.creatures.erase(self)
			var h: Array = world.herds.get(herd_id, [])
			h.erase(self))
	_build()
	_place_hearts()
	global_position = at
	rotation.y = _heading
	_last_pos = at
	_think = _rng.randf() * 3.0
	_sense = _rng.randf() * 0.3
	_graze = _rng.randf() * 10.0


# ---------------------------------------------------------------- build

func _build() -> void:
	collision_layer = 4
	collision_mask = 0
	model = Node3D.new()
	model.name = "Model"
	model.scale = Vector3.ONE * size
	add_child(model)
	skin = ShaderMaterial.new()
	skin.shader = preload("res://shaders/creature.gdshader")
	skin.set_shader_parameter("fur", Tex.get_tex("fur"))
	skin.set_shader_parameter("fur_n", Tex.get_tex("fur_n"))
	skin.set_shader_parameter("glow_col", sp["glow"])
	skin.set_shader_parameter("belly_col", sp["belly"])
	skin.set_shader_parameter("pattern", ["ridge", "spots", "stripes", "saddle", "bristle"].find(sp["pattern"]))
	skin.set_shader_parameter("pulse_rate", 0.9 + _rng.randf() * 0.6)
	horn_mat = ShaderMaterial.new()
	horn_mat.shader = preload("res://shaders/horn.gdshader")
	horn_mat.set_shader_parameter("glow_col", Horns.glow_of(horn, sp["glow"]))
	horn_mat.set_shader_parameter("detail", Tex.get_tex("detail"))
	var vis_end := 1400.0 if legendary else 950.0
	var torso := _mi(_p["torso"], skin, model, vis_end)
	torso.name = "Torso"
	neck = Node3D.new()
	neck.position = _p["neck_pivot"]
	model.add_child(neck)
	_mi(_p["neck"], skin, neck, vis_end)
	head = Node3D.new()
	head.position = _p["head_c"]
	neck.add_child(head)
	var hd := float(sp["body"]["head"])
	var hk := Horns.build(horn, hd, sp["glow"])
	if not hk.empty():
		var hm := _mi(hk.commit(), horn_mat, head, vis_end)
		hm.name = "Horns"
	for which in ["f", "h"]:
		for side: float in [-1.0, 1.0]:
			var hip := Node3D.new()
			var hp0: Vector3 = _p["hip_" + which]
			hip.position = Vector3(hp0.x * side, hp0.y, hp0.z)
			model.add_child(hip)
			_mi(_p["thigh_" + which], skin, hip, 400.0)
			var knee := Node3D.new()
			knee.position = Vector3(0, -float(_p["l1_" + which]), 0)
			hip.add_child(knee)
			_mi(_p["shin_" + which], skin, knee, 300.0)
			hips.append([hip, knee, which == "f", side])
	tail = Node3D.new()
	tail.position = _p["tail_pivot"]
	model.add_child(tail)
	_mi(_p["tail"], skin, tail, 250.0)
	# Hit shapes: torso, and neck+head.
	var L := float(_p["L"])
	var H := float(_p["H"])
	var W := float(_p["W"])
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(W * 1.05, H * 1.1, L * 1.0) * size
	cs.shape = bs
	cs.position = Vector3(0, float(_p["torso_y"]), 0) * size
	add_child(cs)
	var cs2 := CollisionShape3D.new()
	var bs2 := BoxShape3D.new()
	var piv: Vector3 = _p["neck_pivot"]
	var sn: Vector3 = _p["snout"]
	var span := sn.length()
	bs2.size = Vector3(hd * 0.55, hd * 0.7, span) * size
	cs2.shape = bs2
	cs2.position = (piv + sn * 0.5) * size
	cs2.rotation.x = atan2(sn.y, -sn.z)
	add_child(cs2)


func _mi(m: Mesh, mat: Material, parent: Node3D, vis: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.visibility_range_end = vis
	mi.visibility_range_end_margin = 40.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(mi)
	return mi


## Where the heart sits: somewhere in the species' heart zone, different in
## every animal. Ironcrown has two.
func _place_hearts() -> void:
	var L := float(_p["L"])
	var H := float(_p["H"])
	var W := float(_p["W"])
	var cy := float(_p["torso_y"])
	var zone: Array = sp["heart_zone"]
	heart_r = float(sp["heart_r"]) * 1.25 # a little forgiving
	for i in int(sp.get("hearts", 1)):
		var f := _rng.randf_range(float(zone[0]), float(zone[1]))
		var p := Vector3(_rng.randf_range(-0.22, 0.22) * W, cy + _rng.randf_range(-0.25, 0.18) * H, f * L * 0.5)
		hearts.append(p)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.15, 0.3, 0.85)
	mat.render_priority = 10
	var sm := SphereMesh.new()
	sm.radius = heart_r
	sm.height = heart_r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	for p in hearts:
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = mat
		mi.position = p
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.add_child(mi)
		heart_marks.append(mi)
	var lm := mat.duplicate() as StandardMaterial3D
	lm.albedo_color = Color(0.3, 0.7, 1.0, 0.35)
	for l in lungs():
		var lp: Array = l
		var mi2 := MeshInstance3D.new()
		var s2 := SphereMesh.new()
		s2.radius = float(lp[1])
		s2.height = float(lp[1]) * 2.0
		mi2.mesh = s2
		mi2.material_override = lm
		mi2.position = lp[0]
		mi2.visible = false
		model.add_child(mi2)
		lung_marks.append(mi2)


func lungs() -> Array:
	var L := float(_p["L"])
	var H := float(_p["H"])
	var W := float(_p["W"])
	var cy := float(_p["torso_y"])
	var r := minf(W * 0.22, H * 0.3)
	return [[Vector3(-W * 0.17, cy + H * 0.08, -L * 0.25), r], [Vector3(W * 0.17, cy + H * 0.08, -L * 0.25), r]]


func name_text() -> String:
	return String(sp["name"])


func heart_world(i: int = 0) -> Vector3:
	return model.global_transform * (hearts[i] as Vector3)


func center() -> Vector3:
	return global_position + Vector3(0, float(_p["torso_y"]) * size, 0)


## Show the vitals (heart scanner): 0 off, 1 rough, 2 exact + lungs, 3 all.
func show_vitals(level: int) -> void:
	for i in heart_marks.size():
		var m: MeshInstance3D = heart_marks[i]
		m.visible = level > 0 and not dead and (i == 0 or level >= 3)
		m.scale = Vector3.ONE * (2.2 if level == 1 else 1.0)
		(m.material_override as StandardMaterial3D).albedo_color.a = 0.35 if level == 1 else 0.85
	for m in lung_marks:
		(m as MeshInstance3D).visible = level >= 2 and not dead


func set_thermal(on: bool) -> void:
	skin.set_shader_parameter("thermal", 1.0 if on else 0.0)


# ---------------------------------------------------------------- shooting

## A round hit this animal. Returns what it hit, for the hit marker.
func take_shot(at: Vector3, dir: Vector3, w: Dictionary, dmg: float) -> Dictionary:
	if dead and death_t < 0.0:
		hide_q = maxf(0.0, hide_q - float(w["hide"]) * 0.5)
		return {"organ": "CARCASS"}
	shots_taken += 1
	var inv := model.global_transform.affine_inverse()
	var o := inv * at
	var d := (inv.basis * dir).normalized()
	var depth := float(_p["L"]) * 1.4 + float(_p["W"]) * 2.0
	var burn := bool(w.get("burn", false))
	if burn:
		depth = 0.6 # plasma doesn't pass through; it cooks
	var organ := "FLESH"
	# Brain, in the head (which moves with the neck).
	var brain := inv * head.global_transform * Vector3(0, float(sp["body"]["head"]) * 0.08, 0)
	var br := float(sp["body"]["head"]) * 0.2
	if _ray_hits(o, d, brain, br, depth):
		organ = "BRAIN"
	if organ == "FLESH":
		for i in hearts.size():
			if _ray_hits(o, d, hearts[i], heart_r * 1.1 + (float(w.get("splash", 0.0)) * 0.25 if burn else 0.0), depth):
				organ = "HEART"
				break
	if organ == "FLESH":
		var L := float(_p["L"])
		var H := float(_p["H"])
		var cy := float(_p["torso_y"])
		# Spine: a line along the top of the back.
		var sy := cy + H * 0.36
		var t := _closest_on_ray_to_line(o, d, Vector3(0, sy, -L * 0.45), Vector3(0, sy, L * 0.45), depth)
		if t < 0.075:
			organ = "SPINE"
	if organ == "FLESH":
		for l in lungs():
			if _ray_hits(o, d, l[0], l[1], depth):
				organ = "LUNGS"
				break
	if organ == "FLESH":
		# Rear half: gut. Head/neck box: neck.
		if o.z > float(_p["L"]) * 0.05 and absf(o.y - float(_p["torso_y"])) < float(_p["H"]) * 0.6:
			organ = "GUT"
		elif o.z < -float(_p["L"]) * 0.45:
			organ = "NECK"
	# The hide.
	var hole := float(w["hide"])
	if organ == "BRAIN":
		hole *= 0.25
	if organ == "GUT":
		hole *= 1.5
	if burn:
		hole += 12.0
	hide_q = maxf(0.0, hide_q - hole)
	skin.set_shader_parameter("wet", minf(1.0, float(shots_taken) * 0.25))
	world.blood_spray(at, dir, sp["glow"])
	last_organ = organ
	var res := {"organ": organ, "kill": false}
	match organ:
		"BRAIN":
			_die(organ)
			res["kill"] = true
		"SPINE":
			hp -= dmg
			_die(organ)
			res["kill"] = true
		"HEART":
			hearts_hit += 1
			hp -= dmg * 0.6
			if hearts_hit >= hearts.size():
				heart_killed = true
				death_t = _rng.randf_range(1.5, 3.5) # the dead run
				bleed += max_hp * 0.3
			else:
				bleed += max_hp * 0.05
		"LUNGS":
			hp -= dmg * 0.7
			bleed += max_hp * 0.065
		"GUT":
			hp -= dmg * 0.55
			bleed += max_hp * 0.012
		"NECK":
			hp -= dmg * 0.9
			bleed += max_hp * 0.03
		_:
			hp -= dmg * 0.75
			bleed += max_hp * 0.006
	if not dead and hp <= 0.0:
		_die(organ)
		res["kill"] = true
	if not dead:
		_spooked(world.player.global_position, true)
	return res


func _ray_hits(o: Vector3, d: Vector3, c: Vector3, r: float, depth: float) -> bool:
	var t := clampf((c - o).dot(d), 0.0, depth)
	return (o + d * t).distance_to(c) <= r


func _closest_on_ray_to_line(o: Vector3, d: Vector3, a: Vector3, b: Vector3, depth: float) -> float:
	var best := INF
	for i in 24:
		var p := a.lerp(b, float(i) / 23.0)
		var t := clampf((p - o).dot(d), 0.0, depth)
		best = minf(best, (o + d * t).distance_to(p))
	return best


func _die(cause: String) -> void:
	if dead and death_t < 0.0:
		return
	dead = true
	death_t = -1.0
	state = S.DEAD
	_speed = 0.0
	bleed = 0.0
	for m in heart_marks:
		(m as MeshInstance3D).visible = false
	for m in lung_marks:
		(m as MeshInstance3D).visible = false
	var info := {"cause": cause, "heart": heart_killed or cause == "HEART", "shots": shots_taken, "species": species}
	killed.emit(self, info)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		skin.set_shader_parameter("alive", v)
		horn_mat.set_shader_parameter("alive", v), 1.0, 0.0, 25.0)


# ---------------------------------------------------------------- senses

## Something happened nearby: a shot, a snapped branch, the caller.
func hear(at: Vector3, radius: float, kind: String) -> void:
	if dead:
		return
	var d := global_position.distance_to(at)
	if d > radius * float(sp["hearing"]):
		return
	if kind == "call":
		if state in [S.GRAZE, S.WALK]:
			state = S.INVESTIGATE
			_target = at + Vector3(_rng.randf_range(-12, 12), 0, _rng.randf_range(-12, 12))
		return
	if kind == "shot":
		if d < radius * 0.6:
			_spooked(at, d < radius * 0.35)
		else:
			_alerted(at, 0.6)
	else:
		_alerted(at, 0.25 * (1.0 - d / radius))


func _alerted(at: Vector3, amount: float) -> void:
	awareness = minf(1.5, awareness + amount)
	threat = at
	if state in [S.GRAZE, S.WALK, S.INVESTIGATE] and awareness > 0.35:
		state = S.ALERT
		_think = _rng.randf_range(2.0, 5.0)
		if _call_cool <= 0.0:
			Sfx.play_at("snort", center(), -4.0, 30.0, _rng.randf_range(0.8, 1.2))
			_call_cool = 6.0
	if awareness >= 1.0:
		_spooked(at, false)


func _spooked(at: Vector3, hard: bool) -> void:
	threat = at
	awareness = 1.5
	var temper: String = sp["temper"]
	var d := global_position.distance_to(at)
	if temper == "aggressive" and d < 45.0 or temper == "territorial" and d < 30.0 and (Game.is_night() or hp < max_hp * 0.7) or temper == "predator":
		if state != S.CHARGE:
			state = S.CHARGE
			_call()
		return
	if state != S.FLEE:
		state = S.FLEE
		_flee_from = at
		_think = _rng.randf_range(10.0, 18.0) if hard else _rng.randf_range(7.0, 12.0)
		world.herd_spooked(self, at)


## The herd is running: go with them.
func herd_runs(at: Vector3) -> void:
	if dead or state in [S.FLEE, S.CHARGE]:
		return
	await get_tree().create_timer(_rng.randf_range(0.1, 0.6)).timeout
	if not dead and is_instance_valid(self):
		_spooked(at, false)


func _call() -> void:
	if _call_cool > 0.0:
		return
	_call_cool = _rng.randf_range(8.0, 20.0)
	Sfx.play_at(String(sp["call"]), center() + Vector3(0, 0.5, 0), 4.0 if legendary else 0.0, 90.0, _rng.randf_range(0.85, 1.1) / sqrt(size))


func _sense_player(dt: float) -> void:
	var pl: Node3D = world.player
	if pl == null:
		return
	var pp: Vector3 = pl.global_position
	var d := global_position.distance_to(pp)
	if d > 450.0:
		awareness = maxf(0.0, awareness - dt * 0.1)
		return
	var gain := 0.0
	# Sight.
	var vis: float = pl.call("visibility")
	var sight := float(sp["sight"]) * 0.8 * vis * (0.55 if Game.is_night() and species != "howler" else 1.0)
	if d < sight:
		var to := (pp - global_position).normalized()
		var fwd := -global_transform.basis.z
		var fov := 0.75 if species == "howler" else -0.6 # dot threshold: prey see almost all round
		if fwd.dot(to) > fov or d < 6.0:
			if _los(pl):
				gain += (1.0 - d / sight) * 1.6 * dt * (2.0 if pl.call("moving") else 0.7)
	# Hearing.
	var noise: float = pl.call("noise_radius")
	var hear_r := noise * float(sp["hearing"]) * 0.8
	if hear_r > d:
		gain += (1.0 - d / hear_r) * 1.0 * dt
	# Smell: downwind of you, and the wind's carrying.
	if Time.get_ticks_msec() / 1000.0 > Game.scent_until:
		var dw: float = world.atmo.downwind(pp, global_position)
		var reach: float = 120.0 * float(sp["smell"]) * (0.4 + world.atmo.wind_strength)
		if dw > 0.75 and d < reach:
			gain += (1.0 - d / reach) * 2.0 * dt
			if awareness < 0.4 and gain > 0.05:
				Sfx.play_at("snort", center(), -6.0, 30.0)
	if gain > 0.0:
		_alerted(pp, gain)
	else:
		awareness = maxf(0.0, awareness - dt * 0.06)
		if state == S.ALERT and awareness < 0.2:
			state = S.GRAZE


func _los(pl: Node3D) -> bool:
	var space := get_world_3d().direct_space_state
	var from := head.global_position
	var to: Vector3 = pl.global_position + Vector3(0, 1.0 if not pl.get("crouched") else 0.6, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := space.intersect_ray(q)
	return hit.is_empty()


# ---------------------------------------------------------------- brain

func _physics_process(dt: float) -> void:
	if world == null:
		return
	_call_cool -= dt
	_charge_cool -= dt
	if dead and death_t < 0.0:
		_dead_tick(dt)
		return
	if death_t >= 0.0:
		death_t -= dt
		if death_t <= 0.0:
			death_t = -1.0
			dead = false
			_die("HEART")
			return
	if bleed > 0.0:
		hp -= bleed * dt
		bleed = maxf(0.0, bleed - dt * max_hp * 0.0006) # some wounds clot
		_blood_d += global_position.distance_to(_last_pos)
		if _blood_d > lerpf(5.0, 1.2, clampf(bleed / (max_hp * 0.05), 0.0, 1.0)):
			_blood_d = 0.0
			world.blood_drop(global_position, clampf(bleed / (max_hp * 0.03), 0.3, 1.5), sp["glow"])
		if hp <= 0.0:
			_die("BLEED")
			return
	var pd := global_position.distance_to(world.player.global_position)
	_sense -= dt
	if _sense <= 0.0:
		var step := 0.25 if pd < 250.0 else 0.8
		_sense = step
		_sense_player(step)
	_think -= dt
	_brain(dt, pd)
	_move(dt)
	_last_pos = global_position


func _brain(dt: float, pd: float) -> void:
	var pp: Vector3 = world.player.global_position
	match state:
		S.GRAZE:
			_speed = move_toward(_speed, 0.0, dt * 3.0)
			if _think <= 0.0:
				if _rng.randf() < 0.6:
					state = S.WALK
					_target = _wander_target()
				_think = _rng.randf_range(4.0, 12.0)
				if _rng.randf() < 0.15:
					_call()
		S.WALK:
			_speed = float(sp["speed"]) * (1.25 if species == "howler" else 1.0)
			if Vector2(global_position.x - _target.x, global_position.z - _target.z).length() < 3.0 or _think <= 0.0:
				state = S.GRAZE
				_think = _rng.randf_range(5.0, 14.0)
		S.INVESTIGATE:
			_speed = float(sp["speed"]) * 1.4
			if Vector2(global_position.x - _target.x, global_position.z - _target.z).length() < 4.0:
				state = S.ALERT
				threat = _target
				awareness = 0.4
				_think = 6.0
		S.ALERT:
			_speed = move_toward(_speed, 0.0, dt * 6.0)
			_face(threat, dt * 2.0)
			if _think <= 0.0 and awareness < 0.5:
				state = S.GRAZE
				_think = _rng.randf_range(3.0, 8.0)
		S.FLEE:
			var away := global_position - _flee_from
			away.y = 0.0
			if away.length() < 0.1:
				away = Vector3(sin(_heading), 0, cos(_heading))
			_target = global_position + away.normalized() * 40.0
			var wounded := clampf(1.0 - hp / max_hp, 0.0, 0.7)
			_speed = move_toward(_speed, float(sp["run"]) * (1.0 - wounded * 0.6), dt * 10.0)
			if _think <= 0.0 and global_position.distance_to(_flee_from) > 110.0:
				state = S.WALK
				awareness = 0.5
				home = global_position
				_target = _wander_target()
				_think = 8.0
		S.CHARGE:
			_target = pp
			var run := float(sp["run"])
			_speed = move_toward(_speed, run * (0.8 if pd > 30.0 else 1.0), dt * 8.0)
			if pd < 2.2 + size * float(_p["L"]) * 0.4 and _charge_cool <= 0.0:
				_charge_cool = 2.5 if species != "howler" else 1.4
				var dmg := {"tuskmaw": 28.0, "crownelk": 45.0, "ironcrown": 70.0, "howler": 16.0}.get(species, 20.0) as float
				world.player.call("hurt", dmg * size, global_position)
				Sfx.play_at("thud", world.player.global_position, 2.0, 30.0)
				if species != "howler":
					# Run through, then come round again.
					state = S.FLEE
					_flee_from = pp
					_think = 2.5
					_charge_after()
			if pd > 160.0 and species != "howler":
				state = S.WALK
				_target = _wander_target()
				awareness = 0.4


func _charge_after() -> void:
	await get_tree().create_timer(2.6).timeout
	if is_instance_valid(self) and not dead and state == S.FLEE and global_position.distance_to(world.player.global_position) < 70.0:
		state = S.CHARGE


func _wander_target() -> Vector3:
	for i in 8:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(10.0, 60.0)
		var t := home + Vector3(cos(a) * r, 0, sin(a) * r)
		var h: float = world.terrain.height_at(t.x, t.z)
		if h > 0.6 and world.terrain.in_bounds(t.x, t.z):
			return t
	return home


func _face(at: Vector3, rate: float) -> void:
	var want := atan2(-(at.x - global_position.x), -(at.z - global_position.z))
	_heading = lerp_angle(_heading, want, clampf(rate, 0.0, 1.0))


func _move(dt: float) -> void:
	if _speed > 0.05 and state not in [S.ALERT]:
		var to := _target - global_position
		to.y = 0.0
		if to.length() > 0.5:
			var want := atan2(-to.x, -to.z)
			# Steer round trees and rocks, and away from water and the edge.
			var fwd := Vector3(-sin(_heading), 0, -cos(_heading))
			var avoid := Vector3.ZERO
			for o in world.flora.obstacles_near(global_position.x, global_position.z):
				var ov: Vector3 = o
				var rel := Vector3(global_position.x - ov.x, 0, global_position.z - ov.y)
				var dd := rel.length()
				var reach := ov.z + float(_p["W"]) * size + 1.5
				if dd < reach and dd > 0.01 and rel.dot(fwd) < 0.5:
					avoid += rel.normalized() * (reach - dd) / reach
			var ahead := global_position + fwd * 6.0
			if world.terrain.height_at(ahead.x, ahead.z) < 0.4 or not world.terrain.in_bounds(ahead.x, ahead.z, 140.0):
				avoid += -fwd * 2.0 + Vector3(fwd.z, 0, -fwd.x) * 1.5
			if avoid.length() > 0.01:
				var steer := (to.normalized() + avoid * 2.0)
				want = atan2(-steer.x, -steer.z)
			var turn := 2.5 if _speed < 4.0 else 1.6
			_heading = lerp_angle(_heading, want, clampf(turn * dt, 0.0, 1.0))
		var step := Vector3(-sin(_heading), 0, -cos(_heading)) * _speed * dt
		var np := global_position + step
		var h: float = world.terrain.height_at(np.x, np.z)
		if h < 0.3 and state != S.FLEE:
			_target = _wander_target()
		elif h >= -0.2:
			global_position = Vector3(np.x, h, np.z)
	else:
		global_position.y = world.terrain.height_at(global_position.x, global_position.z)
	rotation.y = _heading


# ---------------------------------------------------------------- animation

func _process(dt: float) -> void:
	if world == null or dead and death_t < 0.0 and _fall >= 1.0:
		return
	var cam := get_viewport().get_camera_3d()
	if cam != null and cam.global_position.distance_to(global_position) > 260.0 and Engine.get_process_frames() % 4 != 0:
		return
	var spd := _speed
	var run := spd > float(sp["speed"]) * 2.0
	var stride := float(sp["body"]["leg"]) * size * (2.2 if run else 1.4)
	_phase += dt * spd / maxf(stride, 0.2) * TAU * 0.5
	var amp := clampf(spd / float(sp["speed"]), 0.0, 1.0) * (0.55 if not run else 0.85)
	for hp_ in hips:
		var hip: Node3D = hp_[0]
		var knee: Node3D = hp_[1]
		var front: bool = hp_[2]
		var side: float = hp_[3]
		var off := 0.0
		if run:
			off = (0.0 if front else PI * 0.9) + (0.25 if side > 0 else 0.0)
		else:
			off = (0.0 if front else PI * 0.5) + (PI if side > 0 else 0.0)
		var ph := _phase + off
		hip.rotation.x = sin(ph) * amp
		var kb := maxf(0.0, -cos(ph)) * amp * 1.4
		knee.rotation.x = kb if front else -kb
	# Body bob, breathing.
	var bob := absf(sin(_phase)) * amp * 0.04 * size
	model.position.y = bob
	var breathe := 1.0 + sin(Time.get_ticks_msec() * 0.002) * 0.015 * (2.0 if state == S.FLEE else 1.0)
	model.scale = Vector3(size * breathe, size, size)
	# Head: down to graze, up and round when alert.
	var target_pitch := 0.0
	var target_yaw := 0.0
	if state == S.GRAZE and spd < 0.2:
		_graze += dt
		target_pitch = 0.75 + sin(_graze * 0.6) * 0.1 if fmod(_graze, 9.0) < 6.5 else 0.1
	elif state == S.ALERT:
		target_pitch = -0.25
		var local := to_local(threat)
		target_yaw = clampf(atan2(-local.x, -local.z), -0.9, 0.9)
	elif state == S.CHARGE:
		target_pitch = 0.35 if species != "howler" else 0.1
	elif run:
		target_pitch = 0.08 + sin(_phase * 2.0) * 0.05
	neck.rotation.x = lerpf(neck.rotation.x, -target_pitch, clampf(dt * 3.0, 0.0, 1.0))
	neck.rotation.y = lerpf(neck.rotation.y, target_yaw, clampf(dt * 3.0, 0.0, 1.0))
	tail.rotation.z = sin(Time.get_ticks_msec() * 0.003 + herd_id) * 0.3
	tail.rotation.x = -0.4 if run else 0.0
	# Lean into the slope.
	var n: Vector3 = world.terrain.normal_at(global_position.x, global_position.z)
	var local_n := global_transform.basis.inverse() * n
	model.rotation.x = lerpf(model.rotation.x, atan2(-local_n.z, local_n.y) * 0.8, clampf(dt * 4.0, 0.0, 1.0))
	model.rotation.z = lerpf(model.rotation.z, atan2(local_n.x, local_n.y) * 0.6, clampf(dt * 4.0, 0.0, 1.0))


func _dead_tick(dt: float) -> void:
	if _fall < 1.0:
		_fall = minf(1.0, _fall + dt * 1.6)
		var e := ease(_fall, 0.4)
		model.rotation.z = lerpf(0.0, PI * 0.47 * (1.0 if herd_id % 2 == 0 else -1.0), e)
		model.position.y = -float(_p["W"]) * 0.1 * e * size
		neck.rotation.x = lerpf(neck.rotation.x, 0.3, e)
		for hp_ in hips:
			(hp_[0] as Node3D).rotation.x = lerpf((hp_[0] as Node3D).rotation.x, 0.25 if hp_[2] else -0.2, e)
			(hp_[1] as Node3D).rotation.x = lerpf((hp_[1] as Node3D).rotation.x, 0.0, e)
		global_position.y = world.terrain.height_at(global_position.x, global_position.z)
		if _fall >= 1.0:
			Sfx.play_at("thud", center(), 0.0, 40.0)


## What you see through the glass: species, rough size, rough trophy class.
func glass_info() -> String:
	var t := name_text()
	if legendary:
		t = "THE IRONCROWN"
	var sz := "young" if size < 1.0 else ("mature" if size < 1.2 else ("old" if size < 1.38 else "ANCIENT"))
	var cls := Catalog.horn_class(float(horn["score"]), species)
	if species == "howler":
		return "%s  (%s)" % [t, sz]
	return "%s  %s  horns look %s" % [t, sz, cls]
