class_name World
extends Node3D
## The hunt. Builds the valley, puts you on your porch, keeps the herds
## coming, flies every round, leaves the blood trails, and runs the trader
## and Blorvak's radio, and the ghouls.

signal loaded
signal progress(t: float, what: String)

var terrain: Terrain
var atmo: Atmosphere
var flora: Flora
var structures: Structures
var player: Player
var hud: Node
var creatures: Array = []
var herds: Dictionary = {} # id -> Array[Creature]
var bullets: Array = []
var water: MeshInstance3D
var _next_herd := 1
var _spawn_t := 0.0
var _lod_t := 0.0
var _blood: Array = []
var _blood_i := 0
var _blood_mat: StandardMaterial3D
var _blood_mesh: QuadMesh
var _ui_stack: Array = []
var _thermal := false
var drone: Node3D = null
var _drone_t := 0.0
var _drone_cam: Camera3D
var _drone_yaw := 0.0
var _drone_pitch := -0.3
var _night_pack_t := 120.0
var _salvaged: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var ready_done := false
var farm: Farm
var ghouls: Array = []
var companion: Companion
var xyla_npc: Companion = null
var _wild_ghoul_t := 200.0
var _fps_t := 0.0
var _fps_low := 0.0
var test_mode := false
var _story_t := 4.0


func _ready() -> void:
	_rng.seed = Game.seed_world + Game.day * 7
	if not test_mode:
		build()


func build() -> void:
	progress.emit(0.05, "Raising the valley")
	await get_tree().process_frame
	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.generate(Game.seed_world)
	var q := Settings.q()
	terrain.lod0 = float(q["lod0"])
	terrain.lod1 = float(q["lod1"])
	progress.emit(0.3, "Painting the ground")
	await get_tree().process_frame
	terrain.build_material(Tex.terrain_params())
	terrain.build_collision()
	terrain.build_all_coarse()
	atmo = Atmosphere.new()
	atmo.name = "Atmosphere"
	add_child(atmo)
	_water()
	progress.emit(0.45, "Building the farm")
	await get_tree().process_frame
	structures = Structures.new()
	structures.name = "Structures"
	add_child(structures)
	structures.setup(self, terrain)
	structures.build_all(Game.seed_world)
	progress.emit(0.6, "Growing what's left")
	await get_tree().process_frame
	flora = Flora.new()
	flora.name = "Flora"
	add_child(flora)
	flora.setup(terrain)
	flora.place_all(Game.seed_world, structures.avoid)
	farm = Farm.new()
	farm.name = "Farm"
	add_child(farm)
	farm.setup(self, terrain)
	progress.emit(0.8, "Waking the herds")
	await get_tree().process_frame
	_blood_setup()
	player = Player.new()
	player.name = "Player"
	player.world = self
	add_child(player)
	var start := Game.player_pos
	if start == Vector3.ZERO or not terrain.in_bounds(start.x, start.z):
		start = structures.farm_spawn
		player.look_dir(structures.farm_yaw + PI, 0.0)
	player.global_position = start + Vector3(0, 0.3, 0)
	terrain.build_lod_now(player.global_position)
	structures.refresh_wall()
	atmo.apply_quality()
	companion = Companion.new()
	companion.name = "Dale"
	add_child(companion)
	companion.setup(self, "dale")
	companion.global_position = player.global_position + Vector3(2, 0, 3)
	if Game.xyla:
		_spawn_xyla()
	for i in 13:
		_spawn_herd(true)
	hud = load("res://ui/hud.gd").new()
	hud.name = "HUD"
	add_child(hud)
	hud.call("setup", self)
	Sfx.ambience(true, Game.is_night())
	get_tree().create_timer(6.0).timeout.connect(func() -> void: companion.say(Story.line("start")))
	ready_done = true
	progress.emit(1.0, "")
	loaded.emit()
	if Game.story == 0:
		_story_t = 3.0


func _water() -> void:
	water = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	pm.subdivide_width = 32
	pm.subdivide_depth = 32
	water.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/water.gdshader")
	m.set_shader_parameter("noise_n", Tex.get_tex("detail_n"))
	water.material_override = m
	water.position = Vector3(Terrain.LAKE.x, Terrain.WATER, Terrain.LAKE.y)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


# ---------------------------------------------------------------- frame

func _process(dt: float) -> void:
	if not ready_done:
		return
	var p := player.global_position if not player.in_drone else drone.global_position
	_lod_t -= dt
	if _lod_t <= 0.0:
		_lod_t = 0.2
		terrain.update_lod(p, 2)
	flora.update_grass(p)
	atmo.follow(get_viewport().get_camera_3d().global_position)
	_spawn_t -= dt
	if _spawn_t <= 0.0:
		_spawn_t = 3.0
		_manage_herds()
	_night_packs(dt)
	_story(dt)
	_discover()
	_wild_ghouls(dt)
	_xyla_check()
	_dynamic_resolution(dt)
	if drone != null:
		_drone_tick(dt)


func _physics_process(dt: float) -> void:
	if not ready_done:
		return
	_fly_bullets(dt)


func ui_open() -> bool:
	return not _ui_stack.is_empty()


func push_ui(n: Node) -> void:
	_ui_stack.append(n)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	atmo.paused = true


func pop_ui(n: Node) -> void:
	_ui_stack.erase(n)
	if _ui_stack.is_empty():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		atmo.paused = false


# ---------------------------------------------------------------- herds

## Which hybrids may appear where, and how often, given your rank.
func _pick_species(hab: String) -> String:
	var r := Game.rank()
	var opts: Array = []
	for k in Catalog.SPECIES.keys():
		var sp: Dictionary = Catalog.SPECIES[k]
		if bool(sp.get("legendary", false)) or k == "howler":
			continue
		var habs: Variant = sp["habitat"]
		if habs is Array and not (habs as Array).has(hab) or habs is String and habs != hab:
			continue
		# Big game shows up as you rank: now and then early, often later.
		var tier := int(sp["tier"])
		var allowed := 1 + r / 2
		var w := 1.0 if tier <= allowed else (0.3 if tier == allowed + 1 else 0.06)
		opts.append([k, w])
	if opts.is_empty():
		return ""
	var tot := 0.0
	for o in opts:
		tot += float(o[1])
	var x := _rng.randf() * tot
	for o in opts:
		x -= float(o[1])
		if x <= 0.0:
			return o[0]
	return opts[0][0]


func _spawn_herd(initial: bool = false) -> bool:
	var pp := player.global_position if player != null else Vector3(Terrain.FARM.x, 0, Terrain.FARM.y)
	for tries in 12:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(70.0 if initial else 220.0, 650.0)
		var x := pp.x + cos(a) * d
		var z := pp.z + sin(a) * d
		if not terrain.in_bounds(x, z, 150.0):
			continue
		if Vector2(x, z).distance_to(Terrain.FARM) < 110.0:
			continue
		var hab := terrain.habitat_at(x, z)
		if hab == "water" or hab == "basin":
			continue
		var kind := _pick_species(hab)
		if kind == "":
			continue
		spawn_herd(kind, Vector3(x, terrain.height_at(x, z), z))
		return true
	return false


func spawn_herd(kind: String, at: Vector3, count: int = -1) -> Array:
	var sp: Dictionary = Catalog.SPECIES[kind]
	var hr: Array = sp["herd"]
	var n := count if count > 0 else _rng.randi_range(int(hr[0]), int(hr[1]) + 1)
	var id := _next_herd
	_next_herd += 1
	var list: Array = []
	for i in n:
		var p := at + Vector3(_rng.randf_range(-9, 9), 0, _rng.randf_range(-9, 9))
		p.y = terrain.height_at(p.x, p.z)
		var c := Creature.new()
		c.name = "%s_%d_%d" % [kind, id, i]
		add_child(c)
		c.setup(self, kind, p, _rng.randi(), id)
		c.killed.connect(_on_killed)
		creatures.append(c)
		list.append(c)
	herds[id] = list
	return list


func _manage_herds() -> void:
	var pp := player.global_position
	# Let go of herds far behind you (the dead stay a while for harvesting).
	for id in herds.keys():
		var list: Array = herds[id]
		var all_far := true
		for c in list:
			if not is_instance_valid(c):
				continue
			var cr := c as Creature
			var d := cr.global_position.distance_to(pp)
			if d < 950.0 or cr.dead and not (cr.harvested_hide and cr.harvested_horn) and d < 1400.0:
				all_far = false
		if all_far:
			for c in list:
				if is_instance_valid(c):
					creatures.erase(c)
					(c as Node).queue_free()
			herds.erase(id)
	var alive := 0
	for id in herds.keys():
		alive += 1
	if alive < 13:
		_spawn_herd()
	_legend()


func herd_spooked(c: Creature, at: Vector3) -> void:
	for o in herds.get(c.herd_id, []):
		if o != c and is_instance_valid(o) and (o as Creature).global_position.distance_to(c.global_position) < 80.0:
			(o as Creature).herd_runs(at)


## Somebody made a sound. Everything that can hear it, hears it.
func noise(at: Vector3, radius: float, kind: String) -> void:
	for c in creatures:
		if is_instance_valid(c):
			(c as Creature).hear(at, radius, kind)


## Packs of Howlers come out at night.
func _night_packs(dt: float) -> void:
	if not Game.is_night() or Game.rank() < 2:
		return
	_night_pack_t -= dt
	if _night_pack_t > 0.0:
		return
	_night_pack_t = _rng.randf_range(150.0, 300.0)
	var n := 0
	for c in creatures:
		if is_instance_valid(c) and (c as Creature).species == "howler" and not (c as Creature).dead:
			n += 1
	if n > 0:
		return
	var pp := player.global_position
	for i in 8:
		var a := _rng.randf() * TAU
		var x := pp.x + cos(a) * 220.0
		var z := pp.z + sin(a) * 220.0
		if terrain.in_bounds(x, z) and terrain.height_at(x, z) > 1.0 and Vector2(x, z).distance_to(Terrain.FARM) > 150.0:
			var pack := spawn_herd("howler", Vector3(x, terrain.height_at(x, z), z))
			Sfx.play_at("howl", pack[0].global_position + Vector3(0, 2, 0), 6.0, 300.0)
			Game.say("Howling, out in the dark. A pack's caught your scent.", Color(1.0, 0.5, 0.5))
			for c in pack:
				(c as Creature).awareness = 1.0
				(c as Creature).state = Creature.S.CHARGE
			return


## The Ironcrown lives in the crash basin. It shows itself to hunters who've
## earned it.
func _legend() -> void:
	if Game.rank() < 6:
		return
	for c in creatures:
		if is_instance_valid(c) and (c as Creature).legendary:
			return
	if Game.legend_down and _rng.randf() > 0.02:
		return
	var pp := player.global_position
	var b := Terrain.BASIN
	if pp.distance_to(Vector3(b.x, pp.y, b.y)) > 900.0:
		return
	var p := Vector3(b.x + _rng.randf_range(-120, 120), 0, b.y + _rng.randf_range(-120, 120))
	p.y = terrain.height_at(p.x, p.z)
	spawn_herd("ironcrown", p, 1)


func _on_killed(c: Creature, info: Dictionary) -> void:
	var sp := c.sp
	var heart := bool(info["heart"])
	var one := int(info["shots"]) == 1
	var xp := int(sp["xp"]) * (2 if heart and one else 1)
	var verdict := "CLEAN KILL" if heart or info["cause"] in ["BRAIN", "SPINE"] else ("TRACKED DOWN" if info["cause"] == "BLEED" else "DOWN")
	if heart and one:
		verdict = "PERFECT HEART SHOT"
	Game.add_xp(xp)
	Game.on_kill(c.species, heart, int(info["shots"]))
	Game.say("%s: %s  +%d XP" % [verdict, c.name_text(), xp], Color(1.0, 0.85, 0.4) if heart else Color(0.9, 0.85, 0.75))
	Game.journal("%s down (%s, %d shot%s)." % [c.name_text(), info["cause"].to_lower(), int(info["shots"]), "" if one else "s"])
	if c.legendary:
		Game.legend_down = true
		Game.journal("THE IRONCROWN IS DOWN.")
		Game.say("THE IRONCROWN IS DOWN", Color(1.0, 0.85, 0.3))
	if hud != null:
		hud.call("kill_banner", verdict, c)
	companion_react("heart" if heart else "kill")


# ---------------------------------------------------------------- harvesting

## Dead animals you're standing over.
func interactables() -> Array:
	var out: Array = []
	out.append_array(get_tree().get_nodes_in_group("interact"))
	var pp := player.global_position
	for c in creatures:
		if not is_instance_valid(c):
			continue
		var cr := c as Creature
		if cr.dead and cr.death_t < 0.0 and not (cr.harvested_hide and cr.harvested_horn):
			if cr.global_position.distance_to(pp) < 12.0:
				out.append(Carcass.of(cr, self))
	return out


func harvest(c: Creature) -> void:
	var took := []
	var full := false
	if not c.harvested_hide:
		var t := {"kind": "hide", "species": c.species, "quality": snappedf(c.hide_q, 0.1), "day": Game.day, "legend": c.legendary}
		if Game.carry(t):
			c.harvested_hide = true
			took.append("%s hide (%s)" % [c.name_text(), Catalog.hide_grade(c.hide_q)])
		else:
			full = true
	if not c.harvested_horn:
		var score := float(c.horn["score"])
		var cls := Catalog.horn_class(score, c.species)
		var t2 := {"kind": "horn", "species": c.species, "score": score, "class": cls, "horn": c.horn, "day": Game.day, "legend": c.legendary}
		if Game.carry(t2):
			c.harvested_horn = true
			took.append("%s %s: %.1f %s" % [c.name_text(), "fangs" if c.species == "howler" else "horns", score, cls])
			var broke := Game.record_horn(t2)
			if broke != "" and hud != null:
				hud.call("record_banner", broke, c.name_text(), score, cls)
			elif cls in ["DIAMOND", "MYTHIC"] and hud != null:
				hud.call("record_banner", "class", c.name_text(), score, cls)
			c.get_node("Model").find_child("Horns", true, false)
			var hm: Node = c.head.get_node_or_null("Horns")
			if hm != null:
				hm.queue_free()
		else:
			full = true
	if not took.is_empty():
		Sfx.play("harvest", -4.0)
		companion_react("harvest")
		for t3 in took:
			Game.say("Harvested: %s" % t3, Color(0.85, 0.95, 0.7))
		Game.stat("harvests")
	if full:
		Game.say("Your pack's full (%d). Sell or mount at the farm's trade radio." % Game.capacity(), Color(1.0, 0.6, 0.4))
	if c.harvested_hide and c.harvested_horn:
		c.skin.set_shader_parameter("wet", 1.0)
		c.model.scale.y *= 0.8


# ---------------------------------------------------------------- ballistics

func fire(origin: Vector3, dir: Vector3, kind: String, shooter: Node) -> void:
	var w: Dictionary = Catalog.WEAPONS[kind]
	var v := float(w["vel"])
	var drop := float(w.get("drop", 1.0))
	# Zeroed at 100 m: tip the barrel up so the round crosses the line of
	# sight there.
	var t100 := 100.0 / v
	var lift := 0.5 * 9.81 * drop * t100 * t100 / 100.0
	var d := (dir + Vector3(0, lift, 0)).normalized()
	var aimed: bool = shooter == player and player.aim_creature != null and not player.aim_creature.dead
	var b := {"aimed": aimed, "origin": origin, "pos": origin, "vel": d * v, "w": w, "kind": kind, "v0": v, "life": 4.0, "drop": drop, "exclude": [shooter.get_rid()], "hits": 0, "trace": null, "dist": 0.0}
	if kind == "plasma":
		b["trace"] = _plasma_ball(origin)
	if kind == "rail":
		b["beam_from"] = origin
	bullets.append(b)


func _fly_bullets(dt: float) -> void:
	var space := get_world_3d().direct_space_state
	for b in bullets.duplicate():
		var steps := 1
		var pos: Vector3 = b["pos"]
		var vel: Vector3 = b["vel"]
		var np := pos + vel * dt
		vel += Vector3(0, -9.81 * float(b["drop"]), 0) * dt
		vel *= 1.0 - 0.06 * dt # a touch of drag
		b["life"] = float(b["life"]) - dt
		var q := PhysicsRayQueryParameters3D.create(pos, np, 1 | 4)
		q.exclude = b["exclude"]
		var hit := space.intersect_ray(q)
		var done := false
		if not hit.is_empty():
			var hp: Vector3 = hit["position"]
			b["dist"] = float(b["dist"]) + pos.distance_to(hp)
			var col: Object = hit["collider"]
			var w: Dictionary = b["w"]
			var energy := vel.length() / float(b["v0"])
			var dmg := float(w["dmg"]) * (0.55 + 0.45 * energy)
			if col is Ghoul:
				var gr: Dictionary = (col as Ghoul).take_shot(hp, vel.normalized(), w, dmg)
				Sfx.play_at("impact", hp, 0.0, 60.0)
				if hud != null:
					hud.call("hit_marker", gr, float(b["dist"]))
				done = true
			elif col is Creature:
				var res: Dictionary = (col as Creature).take_shot(hp, vel.normalized(), w, dmg)
				if not bool(res.get("kill", false)) and res.get("organ", "") in ["LUNGS", "GUT", "FLESH", "NECK"]:
					companion_react("wounded")
				b["aimed"] = false
				Sfx.play_at("impact", hp, 0.0, 60.0)
				Game.stat("hits")
				if hud != null:
					hud.call("hit_marker", res, float(b["dist"]) + 0.0)
				var org: String = res.get("organ", "")
				if Settings.killcam and not test_mode and float(b["dist"]) > 70.0 and org in ["HEART", "BRAIN", "LUNGS", "SPINE"] and (org == "HEART" or randf() < 0.5) and get_node_or_null("KillCam") == null:
					KillCam.play(self, b["origin"], hp, col as Creature, org)
				if bool(w.get("pierce", false)) and int(b["hits"]) < 3:
					b["hits"] = int(b["hits"]) + 1
					(b["exclude"] as Array).append((col as CollisionObject3D).get_rid())
					np = hp + vel.normalized() * 0.05
				else:
					done = true
			else:
				_impact(hp, hit["normal"], b)
				if bool(b.get("aimed", false)):
					companion_react("miss")
				done = true
			if bool(w.get("burn", false)):
				_plasma_burst(hp)
				done = true
			np = hp if done else np
		else:
			b["dist"] = float(b["dist"]) + pos.distance_to(np)
		b["pos"] = np
		b["vel"] = vel
		if b["trace"] != null:
			(b["trace"] as Node3D).global_position = np
		if done or float(b["life"]) <= 0.0 or np.y < -50.0:
			if b.has("beam_from"):
				_beam(b["beam_from"], np)
			if b["trace"] != null:
				(b["trace"] as Node).queue_free()
			bullets.erase(b)


func _impact(at: Vector3, n: Vector3, b: Dictionary) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 24
	p.lifetime = 1.4
	p.explosiveness = 0.95
	p.direction = n
	p.spread = 35.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -4, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	mesh.radial_segments = 6
	mesh.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.4, 0.33, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = m
	p.mesh = mesh
	add_child(p)
	p.global_position = at
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)
	Sfx.play_at("thud", at, -10.0, 30.0, 1.6)
	noise(at, 25.0, "snap")


func _plasma_ball(at: Vector3) -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.6, 0.3)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.5, 0.2)
	m.emission_energy_multiplier = 6.0
	mi.material_override = m
	n.add_child(mi)
	var lt := OmniLight3D.new()
	lt.light_color = Color(1.0, 0.5, 0.2)
	lt.light_energy = 3.0
	lt.omni_range = 8.0
	n.add_child(lt)
	add_child(n)
	n.global_position = at
	return n


func _plasma_burst(at: Vector3) -> void:
	var lt := OmniLight3D.new()
	lt.light_color = Color(1.0, 0.5, 0.2)
	lt.light_energy = 8.0
	lt.omni_range = 14.0
	add_child(lt)
	lt.global_position = at
	var tw := lt.create_tween()
	tw.tween_property(lt, "light_energy", 0.0, 0.6)
	tw.tween_callback(lt.queue_free)


func _beam(a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var k := MeshKit.new()
	k.cyl(Vector3.ZERO, Vector3(0, 0, -a.distance_to(b)), 0.02, 0.02, 6, Color(0.6, 0.85, 1.0), false)
	mi.mesh = k.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.5, 0.8, 1.0)
	m.emission_energy_multiplier = 4.0
	mi.material_override = m
	add_child(mi)
	mi.global_position = a + (b - a).normalized() * 1.0
	mi.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	tw.tween_callback(mi.queue_free)


func muzzle_flash(at: Vector3, w: Dictionary) -> void:
	var lt := OmniLight3D.new()
	var plasma := String(w["kind"]) in ["plasma", "coil", "rail"]
	lt.light_color = Color(1.0, 0.75, 0.45) if not plasma else Color(0.5, 0.9, 1.0)
	lt.light_energy = 6.0 if String(w["kind"]) != "coil" else 1.5
	lt.omni_range = 10.0
	add_child(lt)
	lt.global_position = at
	get_tree().create_timer(0.05).timeout.connect(lt.queue_free)


# ---------------------------------------------------------------- blood

func _blood_setup() -> void:
	_blood_mat = StandardMaterial3D.new()
	_blood_mat.albedo_color = Color(0.25, 0.04, 0.05)
	_blood_mat.emission_enabled = true
	_blood_mat.emission = Color(0.2, 1.0, 0.75)
	_blood_mat.emission_energy_multiplier = 0.25
	_blood_mat.roughness = 0.2
	_blood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_blood_mesh = QuadMesh.new()
	_blood_mesh.size = Vector2(0.25, 0.25)
	_blood_mesh.orientation = PlaneMesh.FACE_Y
	_tracker_glow()


func _tracker_glow() -> void:
	if _blood_mat == null:
		return
	var on := Game.has("tracker")
	_blood_mat.emission_energy_multiplier = 3.0 if on else 0.25
	_blood_mat.no_depth_test = false


## A drop on the ground where a wounded animal ran. Hybrid blood glows a
## little; through the Bio-Tracker it shines.
func blood_drop(at: Vector3, amount: float, glow: Color) -> void:
	var mi: MeshInstance3D
	if _blood.size() < 500:
		mi = MeshInstance3D.new()
		mi.mesh = _blood_mesh
		mi.material_override = _blood_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_blood.append(mi)
	else:
		mi = _blood[_blood_i]
		_blood_i = (_blood_i + 1) % _blood.size()
	var p := at + Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4))
	p.y = terrain.height_at(p.x, p.z) + 0.03
	var n := terrain.normal_at(p.x, p.z)
	mi.global_transform = Transform3D(Basis(Vector3.UP.cross(n).normalized() if n.y < 0.999 else Vector3.RIGHT, acos(clampf(n.y, -1, 1))) * Basis(Vector3.UP, _rng.randf() * TAU), p)
	mi.scale = Vector3.ONE * (0.6 + amount * _rng.randf_range(0.6, 1.4))
	mi.visible = true
	_blood_mat.emission = glow


func blood_spray(at: Vector3, dir: Vector3, glow: Color) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 30
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.direction = dir
	p.spread = 25.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -9.0, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.02
	mesh.height = 0.04
	mesh.radial_segments = 4
	mesh.rings = 2
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.35, 0.05, 0.05)
	m.emission_enabled = true
	m.emission = glow
	m.emission_energy_multiplier = 1.5
	mesh.material = m
	p.mesh = mesh
	add_child(p)
	p.global_position = at
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)
	for i in 3:
		blood_drop(at + dir * (1.0 + i), 1.0, glow)


# ---------------------------------------------------------------- gear

func set_thermal(on: bool) -> void:
	_thermal = on
	for c in creatures:
		if is_instance_valid(c):
			(c as Creature).set_thermal(on)
	atmo.env.adjustment_saturation = 0.0 if on else 0.92
	atmo.env.adjustment_brightness = 0.55 if on else 1.0
	if hud != null:
		hud.call("thermal", on)


func set_cloak(on: bool) -> void:
	if hud != null:
		hud.call("cloak", on)
	Sfx.play("scanner", -6.0, 0.6 if on else 0.4)


func toggle_drone() -> void:
	if drone != null:
		_end_drone()
		return
	drone = Node3D.new()
	add_child(drone)
	drone.global_position = player.global_position + Vector3(0, 3, 0)
	var k := MeshKit.new()
	k.box(Vector3.ZERO, Vector3(0.4, 0.1, 0.4), Color(0.2, 0.2, 0.22))
	for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		k.cyl(Vector3(s.x * 0.3, 0.05, s.y * 0.3), Vector3(s.x * 0.3, 0.08, s.y * 0.3), 0.18, 0.18, 10, Color(0.1, 0.1, 0.1))
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	mi.material_override = m
	drone.add_child(mi)
	_drone_cam = Camera3D.new()
	_drone_cam.fov = 70.0
	_drone_cam.far = 4000.0
	_drone_cam.cull_mask = 1
	drone.add_child(_drone_cam)
	_drone_cam.make_current()
	_drone_yaw = player.rotation.y
	_drone_pitch = -0.3
	_drone_t = 60.0
	player.in_drone = true
	var hum := AudioStreamPlayer3D.new()
	hum.stream = Sfx.bank["drone"]
	hum.volume_db = -10.0
	drone.add_child(hum)
	hum.play()
	noise(drone.global_position, 30.0, "snap")
	Game.say("Drone up. WASD to fly, Space/Ctrl for height, G to land. It tags what it sees.", Color(0.6, 0.9, 1.0))


func drone_look(rel: Vector2) -> void:
	_drone_yaw -= rel.x
	_drone_pitch = clampf(_drone_pitch - rel.y, -1.4, 0.5)


func _drone_tick(dt: float) -> void:
	_drone_t -= dt
	var input := Input.get_vector("left", "right", "fwd", "back")
	var b := Basis(Vector3.UP, _drone_yaw)
	var v := b * Vector3(input.x, 0, input.y) * 18.0
	if Input.is_action_pressed("jump"):
		v.y += 8.0
	if Input.is_action_pressed("crouch"):
		v.y -= 8.0
	var np := drone.global_position + v * dt
	np.y = clampf(np.y, terrain.height_at(np.x, np.z) + 2.0, terrain.height_at(np.x, np.z) + 120.0)
	if np.distance_to(player.global_position) > 500.0:
		np = player.global_position + (np - player.global_position).normalized() * 500.0
	drone.global_position = np
	drone.rotation = Vector3(0, _drone_yaw, 0)
	_drone_cam.rotation = Vector3(_drone_pitch, 0, 0)
	# Tag what's in view.
	var now := Time.get_ticks_msec() / 1000.0
	for c in creatures:
		if not is_instance_valid(c):
			continue
		var cr := c as Creature
		if cr.dead:
			continue
		var d := cr.center() - _drone_cam.global_position
		if d.length() < 320.0 and d.normalized().dot(-_drone_cam.global_transform.basis.z) > 0.8:
			if cr.tagged_until < now:
				Sfx.play("scanner", -12.0, 1.3)
			cr.tagged_until = now + 60.0
	if _drone_t <= 0.0 or Input.is_action_just_pressed("drone"):
		_end_drone()


func _end_drone() -> void:
	if drone != null:
		drone.queue_free()
		drone = null
	player.in_drone = false
	player.cam.make_current()


# ---------------------------------------------------------------- the farm

func open_shop() -> void:
	var s: Node = load("res://ui/shop.gd").new()
	s.call("setup", self)
	hud.add_child(s)
	Sfx.play("ui")


func open_trophies() -> void:
	var s: Node = load("res://ui/trophies.gd").new()
	s.call("setup", self)
	hud.add_child(s)


func sleep() -> void:
	var to := 6.0 if Game.time_of_day > 15.0 or Game.time_of_day < 5.0 else 19.0
	if to == 6.0 and Game.time_of_day > 15.0:
		Game.day += 1
		Game.refresh_contracts()
	Game.time_of_day = to
	player.health = 100.0
	Game.player_pos = structures.farm_spawn
	Game.save_game()
	Game.say("You sleep. It's %s on day %d. Game saved." % ["dawn" if to == 6.0 else "dusk", Game.day], Color(0.7, 0.85, 1.0))
	if hud != null:
		hud.call("fade")


func salvage(i: int) -> void:
	var key := "%d_%d" % [i, Game.day]
	if _salvaged.has(key):
		Game.say("You've stripped this pod today. Visitor tech grows back overnight, somehow.")
		return
	_salvaged[key] = true
	var v := _rng.randi_range(40, 120) + Game.rank() * 15
	Game.add_scrip(v)
	Game.add_xp(10)
	Sfx.play("cash", -4.0)
	Game.say("Salvaged Visitor parts: +%d scrip" % v, Color(0.5, 1.0, 0.9))


func player_died() -> void:
	player.dead = true
	var lost := Game.carried.size()
	Game.carried.clear()
	var fee := mini(Game.scrip, 100 + Game.rank() * 25)
	Game.scrip -= fee
	Game.say("You wake up on your porch. Dale dragged you home by the boots. -%d scrip%s" % [fee, (", and the %d trophies you carried are gone" % lost) if lost > 0 else ""], Color(1.0, 0.5, 0.45))
	if hud != null:
		hud.call("fade")
	await get_tree().create_timer(1.2).timeout
	player.global_position = structures.farm_spawn + Vector3(0, 0.3, 0)
	player.velocity = Vector3.ZERO
	player.health = 100.0
	player.dead = false
	Game.time_of_day = fmod(Game.time_of_day + 6.0, 24.0)
	for c in creatures:
		if is_instance_valid(c) and (c as Creature).state == Creature.S.CHARGE:
			(c as Creature).state = Creature.S.WALK
	Game.changed.emit()


# ---------------------------------------------------------------- Blorvak on the radio

var STORY: Array = Story.RADIO


func story_goal() -> String:
	return String(STORY[clampi(Game.story - 1, 0, STORY.size() - 1)][1])


func _story(dt: float) -> void:
	_story_t -= dt
	if _story_t > 0.0:
		return
	_story_t = 2.0
	var s := Game.story
	var next := false
	match s:
		0:
			next = true
		1:
			next = Game.sold_total > 0 or Game.wall.size() > 0
		2:
			next = Game.weapons.has("bolt")
		3:
			next = int(Game.stats.get("kill_stagwraith", 0)) > 0
		4:
			next = Game.rank() >= 4
		5:
			next = Game.best_on_wall("ramspire") > 0.0 or Game.rank() >= 6
		6:
			next = Game.rank() >= 6
		7:
			next = Game.legend_down
	if next and s < STORY.size():
		var entry: Array = STORY[s]
		Game.story = s + 1
		if hud != null:
			hud.call("radio", entry[0])
		Game.journal("Blorvak: " + String(entry[0]).substr(0, 80) + "...")
		Sfx.play("scanner", -4.0, 0.8)
		Game.changed.emit()



# ---------------------------------------------------------------- camps

func _discover() -> void:
	if Engine.get_process_frames() % 30 != 0:
		return
	var pp := player.global_position
	for c in structures.camps:
		var nm: String = c[0]
		if not Game.camps.has(nm) and pp.distance_to(c[1]) < 45.0:
			Game.camps[nm] = true
			Game.say("Discovered %s. You can fast travel here from the map." % nm, UIStyle.TEAL)
			Game.journal("Found %s." % nm)
			Game.add_xp(20)
			Sfx.play("rank", -10.0, 1.3)


func open_travel() -> void:
	var m: Node = load("res://ui/map.gd").new()
	m.name = "Map"
	m.call("setup", self)
	hud.add_child(m)


## Every place you can fast travel to: the farm, and the camps you've found.
func travel_spots() -> Array:
	var out: Array = [["Your Farm", structures.farm_spawn]]
	for c in structures.camps:
		if Game.camps.has(c[0]):
			out.append([c[0], (c[1] as Vector3) + Vector3(3.0, 0.3, -2.0)])
	return out


func can_travel() -> String:
	for c in creatures:
		if is_instance_valid(c) and (c as Creature).state == Creature.S.CHARGE and (c as Creature).global_position.distance_to(player.global_position) < 120.0:
			return "Something's coming for you. Deal with it first."
	return ""


func travel_to(at: Vector3) -> void:
	if hud != null:
		hud.call("fade")
	player.global_position = at + Vector3(0, 0.5, 0)
	player.velocity = Vector3.ZERO
	Game.time_of_day = fmod(Game.time_of_day + 0.5, 24.0)
	terrain.build_lod_now(at)
	Sfx.play("step0", -14.0)



# ---------------------------------------------------------------- ghouls

func spawn_ghoul(kind: String, at: Vector3, raid: bool) -> Ghoul:
	var g := Ghoul.new()
	add_child(g)
	g.setup(self, kind, at, raid)
	ghouls.append(g)
	g.tree_exiting.connect(func() -> void: ghouls.erase(g))
	return g


func ghoul_died(_g: Ghoul) -> void:
	pass


func companion_react(what: String) -> void:
	if companion != null:
		companion.react(what)


## Out in the wasteland at night, the odd ghoul (and later the Burnt) finds you.
func _wild_ghouls(dt: float) -> void:
	if not Game.is_night() or Game.rank() < 2:
		return
	_wild_ghoul_t -= dt
	if _wild_ghoul_t > 0.0:
		return
	_wild_ghoul_t = _rng.randf_range(150.0, 320.0)
	var pp := player.global_position
	if pp.distance_to(farm.center) < 120.0:
		return
	var n := _rng.randi_range(1, 2 + Game.rank() / 3)
	var a := _rng.randf() * TAU
	for i in n:
		var p := pp + Vector3(cos(a), 0, sin(a)) * 90.0 + Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-8, 8))
		p.y = terrain.height_at(p.x, p.z)
		spawn_ghoul("burnt" if Game.rank() >= 5 and _rng.randf() < 0.25 else "ghoul", p, false)
	companion_react("ghoul")


# ---------------------------------------------------------------- Xyla

func _xyla_check() -> void:
	if Game.xyla or Game.rank() < 5 or Engine.get_process_frames() % 60 != 0:
		return
	Game.xyla = true
	Game.journal("Xyla, a Xhuul appraiser on the run from the Horn Exchange, has moved into the barn.")
	if hud != null:
		hud.call("radio", "Xhuul signal, unencrypted: \"Farmer. I am Xyla. I have run from the Horn Exchange and they will come for me. I am at your barn. Please do not shoot. I am very pretty.\"")
	_spawn_xyla()
	Game.say("Someone's waiting at your barn.", Color(0.55, 0.95, 1.0))


func _spawn_xyla() -> void:
	if xyla_npc != null:
		return
	xyla_npc = Companion.new()
	xyla_npc.name = "Xyla"
	add_child(xyla_npc)
	xyla_npc.setup(self, "xyla")
	xyla_npc.follow = false
	var spot := Vector3(Terrain.FARM.x + 22.0, 0, Terrain.FARM.y + 4.0)
	spot.y = terrain.height_at(spot.x, spot.z)
	xyla_npc.home = spot
	xyla_npc.global_position = spot
	xyla_npc.rotation.y = PI * 0.5
	var it := Interactable.make(self, spot + Vector3(0, 1.6, 0), "Talk to Xyla", func(_p: Node) -> void: talk_xyla(), 3.0)
	it.name = "XylaTalk"


func talk_xyla() -> void:
	var i := mini(Game.xyla_talk, Story.XYLA.size() - 1)
	if hud != null:
		hud.call("subtitle", "XYLA", Story.XYLA[i], Color(0.55, 0.95, 1.0), 12.0)
	if Game.xyla_talk < Story.XYLA.size() - 1:
		Game.xyla_talk += 1
	if xyla_npc != null:
		xyla_npc.body.set_anim("wave")
		get_tree().create_timer(2.5).timeout.connect(func() -> void:
			if xyla_npc != null:
				xyla_npc.body.set_anim("idle"))


func open_workbench() -> void:
	var s: Node = load("res://ui/workbench.gd").new()
	s.call("setup", self)
	hud.add_child(s)



## Hold 60: if the frame rate sags, render the 3D a little smaller (FSR
## upscales it back), and give it back when there's headroom.
func _dynamic_resolution(dt: float) -> void:
	if not Settings.dynamic_res or test_mode:
		return
	_fps_t += dt
	if _fps_t < 1.5:
		return
	_fps_t = 0.0
	var fps := Engine.get_frames_per_second()
	var vp := get_viewport()
	var cap := minf(float(Settings.q()["scale"]), Settings.render_scale)
	if fps < 55.0:
		_fps_low += 1.0
		if _fps_low >= 2.0 and vp.scaling_3d_scale > 0.5:
			vp.scaling_3d_scale = maxf(0.5, vp.scaling_3d_scale - 0.08)
			if not Settings.compat():
				vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			_fps_low = 0.0
	else:
		_fps_low = 0.0
		if fps > 70.0 and vp.scaling_3d_scale < cap:
			vp.scaling_3d_scale = minf(cap, vp.scaling_3d_scale + 0.04)



## The player blinked: a flash where they left and where they landed, Dale
## pops along behind, and anything close by hears it.
func blinked(from: Vector3, to: Vector3) -> void:
	Sfx.play("blink", -2.0)
	for p in [from, to]:
		var lt := OmniLight3D.new()
		lt.light_color = Color(0.4, 1.0, 0.9)
		lt.light_energy = 6.0
		lt.omni_range = 12.0
		add_child(lt)
		lt.global_position = (p as Vector3) + Vector3(0, 1.2, 0)
		var tw := lt.create_tween()
		tw.tween_property(lt, "light_energy", 0.0, 0.6)
		tw.tween_callback(lt.queue_free)
		var burst := CPUParticles3D.new()
		burst.one_shot = true
		burst.emitting = true
		burst.amount = 40
		burst.lifetime = 0.8
		burst.explosiveness = 1.0
		burst.direction = Vector3.UP
		burst.spread = 180.0
		burst.initial_velocity_min = 1.0
		burst.initial_velocity_max = 4.0
		burst.gravity = Vector3(0, 1.0, 0)
		var sm := SphereMesh.new()
		sm.radius = 0.04
		sm.height = 0.08
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.5, 1.0, 0.95)
		m.emission_enabled = true
		m.emission = Color(0.4, 1.0, 0.9)
		m.emission_energy_multiplier = 3.0
		sm.material = m
		burst.mesh = sm
		add_child(burst)
		burst.global_position = (p as Vector3) + Vector3(0, 1.0, 0)
		get_tree().create_timer(1.2).timeout.connect(burst.queue_free)
	if hud != null:
		hud.call("blink_flash")
	if companion != null and companion.follow:
		companion.global_position = to + Basis(Vector3.UP, player.rotation.y) * Vector3(2.4, 0, 3.2)
	noise(to, 30.0, "snap")
