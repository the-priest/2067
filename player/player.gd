class_name Player
extends CharacterBody3D
## You. A farmer with a rifle. Walk, crouch, sprint, hold your breath on the
## scope. Your noise, your silhouette and your scent are what the animals
## react to. Rounds fly with real drop and travel time.

const WALK := 3.4
const SPRINT := 6.8
const CROUCH := 1.7
const GRAVITY := 18.0
const EYE := 1.65
const EYE_CROUCH := 1.0

var world: Node = null
var cam: Camera3D
var pivot: Node3D
var gun_holder: Node3D
var gun: Node3D = null
var gun_kind := ""
var light: SpotLight3D
var health := 100.0
var stamina := 100.0
var breath := 100.0
var cloak_energy := 100.0
var cloak_on := false
var crouched := false
var aiming := 0.0 # 0 hip .. 1 fully aimed
var binos := false
var scoped := false # looking through a scope or the binoculars
var zoom_i := 0
var holding_breath := false
var thermal := false
var reloading := 0.0
var fire_cool := 0.0
var interact_target: Object = null
var harvest_t := 0.0
var in_drone := false
var dead := false
var range_m := -1.0
var aim_creature: Creature = null
var hurt_flash := 0.0
var last_hit := {} # for the hit marker
var _pitch := 0.0
var _yaw := 0.0
var _bob := 0.0
var _step := 0.0
var _sway := Vector2.ZERO
var _recoil := 0.0
var _kick := Vector2.ZERO
var _eye := EYE
var _moving := false
var _sprinting := false
var _land_v := 0.0
var _caller_cd := 0.0
var _heart_sfx := 0.0
var _vitals_shown: Creature = null
var _reload_count := 0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	floor_max_angle = deg_to_rad(48.0)
	floor_snap_length = 0.6
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	pivot = Node3D.new()
	pivot.position.y = EYE
	add_child(pivot)
	cam = Camera3D.new()
	cam.fov = Settings.fov
	cam.near = 0.04
	cam.far = 4000.0
	pivot.add_child(cam)
	cam.make_current()
	gun_holder = Node3D.new()
	cam.add_child(gun_holder)
	light = SpotLight3D.new()
	light.spot_range = 45.0
	light.spot_angle = 28.0
	light.light_energy = 3.0
	light.light_color = Color(1.0, 0.92, 0.8)
	light.shadow_enabled = true
	light.visible = false
	light.position = Vector3(0.2, -0.15, 0)
	cam.add_child(light)
	equip(Game.weapon)


func equip(kind: String) -> void:
	if gun != null:
		gun.queue_free()
	gun_kind = kind
	gun = Guns.build(kind)
	gun_holder.add_child(gun)
	zoom_i = 0
	reloading = 0.0
	Game.weapon = kind if kind != "binoculars" else Game.weapon
	Sfx.play("load", -8.0)


func weapon() -> Dictionary:
	return Catalog.WEAPONS.get(gun_kind, {})


# ---------------------------------------------------------------- input

func _unhandled_input(e: InputEvent) -> void:
	if dead or world == null or world.ui_open():
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s := Settings.sens * (cam.fov / Settings.fov)
		var m := e as InputEventMouseMotion
		if in_drone:
			world.drone_look(m.relative * s)
			return
		_yaw -= m.relative.x * s
		_pitch -= m.relative.y * s * (-1.0 if Settings.invert_y else 1.0)
		_pitch = clampf(_pitch, -1.5, 1.5)
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and scoped:
		var mb := e as InputEventMouseButton
		var z: Array = weapon().get("zoom", [])
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and z.size() > 1:
			zoom_i = mini(zoom_i + 1, z.size() - 1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_i = maxi(zoom_i - 1, 0)
	if e.is_action_pressed("reload"):
		_start_reload()
	if e.is_action_pressed("flash"):
		light.visible = not light.visible
		Sfx.play("click", -10.0)
	if e.is_action_pressed("binos"):
		binos = not binos
		equip("binoculars" if binos else Game.weapon)
	for i in 6:
		if e.is_action_pressed("slot%d" % (i + 1)) and i < Game.weapons.size():
			binos = false
			equip(Game.weapons[i])
	if e.is_action_pressed("thermal") and Game.has("thermal") and scoped:
		thermal = not thermal
		world.set_thermal(thermal)
	if e.is_action_pressed("cloak") and Game.has("cloak"):
		cloak_on = not cloak_on and cloak_energy > 10.0
		world.set_cloak(cloak_on)
	if e.is_action_pressed("caller") and Game.has("caller"):
		if _caller_cd <= 0.0:
			_caller_cd = 25.0
			Sfx.play_at("bugle", global_position, 6.0, 120.0, 0.7)
			world.noise(global_position, 320.0, "call")
			Game.say("You blow the caller. Anything in earshot will come and look.")
		else:
			Game.say("The caller needs a moment (%ds)." % int(_caller_cd))
	if e.is_action_pressed("scent") and Game.has("scent"):
		Game.gear["scent"] = int(Game.gear["scent"]) - 1
		if int(Game.gear["scent"]) <= 0:
			Game.gear.erase("scent")
		Game.scent_until = Time.get_ticks_msec() / 1000.0 + 300.0
		Game.say("Scent masked for five minutes.", Color(0.6, 0.9, 1.0))
		Game.changed.emit()
	if e.is_action_pressed("drone") and Game.has("drone"):
		world.toggle_drone()


# ---------------------------------------------------------------- frame

func _physics_process(dt: float) -> void:
	if world == null or dead:
		return
	if world.ui_open() or in_drone:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y -= GRAVITY * dt
		move_and_slide()
		return
	var input := Input.get_vector("left", "right", "fwd", "back")
	crouched = Input.is_action_pressed("crouch")
	var want_sprint := Input.is_action_pressed("sprint") and input.y < -0.2 and not crouched and aiming < 0.3 and stamina > 5.0
	_sprinting = want_sprint
	var spd := SPRINT if want_sprint else (CROUCH if crouched else WALK)
	if aiming > 0.5:
		spd = minf(spd, 2.0)
	var basis_y := Basis(Vector3.UP, _yaw)
	var wish := basis_y * Vector3(input.x, 0, input.y) * spd
	var accel := 10.0 if is_on_floor() else 2.0
	velocity.x = lerpf(velocity.x, wish.x, clampf(accel * dt, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, wish.z, clampf(accel * dt, 0.0, 1.0))
	if is_on_floor():
		if Input.is_action_just_pressed("jump") and not crouched and stamina > 10.0:
			velocity.y = 6.0
			stamina -= 10.0
	else:
		velocity.y -= GRAVITY * dt
	_land_v = velocity.y
	move_and_slide()
	# Never fall through the world.
	var th: float = world.terrain.height_at(global_position.x, global_position.z)
	if global_position.y < th - 1.0:
		global_position.y = th + 0.2
		velocity.y = 0.0
	# Keep inside the valley.
	var lim := Terrain.HALF - 60.0
	global_position.x = clampf(global_position.x, -lim, lim)
	global_position.z = clampf(global_position.z, -lim, lim)
	_moving = Vector2(velocity.x, velocity.z).length() > 0.5
	if want_sprint and _moving:
		stamina = maxf(0.0, stamina - dt * 14.0)
	elif not holding_breath:
		stamina = minf(100.0, stamina + dt * (12.0 if not _moving else 6.0))
	# Footsteps.
	if _moving and is_on_floor():
		_step += Vector2(velocity.x, velocity.z).length() * dt
		var stride := 0.75 if crouched else (1.45 if _sprinting else 1.0)
		if _step > stride:
			_step = 0.0
			Sfx.play("step_soft" if crouched else "step", (-20.0 if crouched else -11.0) + (3.0 if _sprinting else 0.0), randf_range(0.85, 1.15))
	Game.player_pos = global_position


func _process(dt: float) -> void:
	if world == null:
		return
	hurt_flash = maxf(0.0, hurt_flash - dt)
	_caller_cd -= dt
	if dead or in_drone:
		return
	var ui: bool = world.ui_open()
	fire_cool -= dt
	health = minf(100.0, health + dt * 0.8)
	# Aiming.
	var want_aim := Input.is_action_pressed("aim") and not ui and reloading <= 0.0 and not _sprinting
	aiming = move_toward(aiming, 1.0 if want_aim else 0.0, dt * (4.5 if want_aim else 6.0))
	var w := weapon()
	var zooms: Array = w.get("zoom", [])
	if binos:
		zooms = [7.0]
	scoped = aiming > 0.92 and not zooms.is_empty()
	var fov_t := Settings.fov
	if scoped:
		fov_t = Settings.fov / float(zooms[mini(zoom_i, zooms.size() - 1)])
	elif aiming > 0.0:
		fov_t = lerpf(Settings.fov, Settings.fov * 0.72, aiming)
	cam.fov = lerpf(cam.fov, fov_t, clampf(dt * 14.0, 0.0, 1.0)) if not scoped else fov_t
	gun.visible = not scoped
	if not scoped and thermal:
		thermal = false
		world.set_thermal(false)
	# Hold your breath on the glass.
	holding_breath = scoped and Input.is_action_pressed("breath") and breath > 0.0
	if holding_breath:
		breath = maxf(0.0, breath - dt * 18.0)
		_heart_sfx -= dt
		if _heart_sfx <= 0.0:
			_heart_sfx = 0.9
			Sfx.play("heart", -8.0)
	else:
		breath = minf(100.0, breath + dt * 22.0)
	# Cloak.
	if cloak_on:
		cloak_energy -= dt * 3.5
		if cloak_energy <= 0.0:
			cloak_on = false
			world.set_cloak(false)
			Game.say("The cloak's out of charge.")
	else:
		cloak_energy = minf(100.0, cloak_energy + dt * 2.0)
	# Sway: breathing, tiredness, movement. Steady when you hold it.
	var t := Time.get_ticks_msec() / 1000.0
	var tired := 1.0 + (100.0 - stamina) / 40.0
	var amt := (0.0035 if crouched else 0.006) * tired * (0.12 if holding_breath else 1.0)
	if _moving:
		amt *= 2.2
	_sway = Vector2(sin(t * 0.9) + sin(t * 2.1) * 0.3, sin(t * 1.3 + 1.0) * 0.8 + sin(t * 0.5) * 0.4) * amt * aiming
	_kick = _kick.lerp(Vector2.ZERO, clampf(dt * 8.0, 0.0, 1.0))
	pivot.rotation = Vector3(_pitch + _sway.y + _kick.y, 0, 0)
	rotation.y = _yaw + _sway.x + _kick.x
	# Eye height and head bob.
	_eye = lerpf(_eye, EYE_CROUCH if crouched else EYE, clampf(dt * 8.0, 0.0, 1.0))
	if _moving and is_on_floor():
		_bob += dt * Vector2(velocity.x, velocity.z).length() * 1.9
	var bob := sin(_bob) * 0.035 * (1.0 - aiming * 0.8)
	pivot.position = Vector3(cos(_bob * 0.5) * 0.02 * (1.0 - aiming), _eye + bob, 0)
	_view_model(dt)
	_fire_input()
	_reload_tick(dt)
	_look_at_things(dt)
	_interact_tick(dt)


func _view_model(dt: float) -> void:
	_recoil = move_toward(_recoil, 0.0, dt * 4.0)
	var hip := Vector3(0.16, -0.17, -0.32)
	var ads := Vector3(0, -Guns.SIGHT, -0.22)
	if gun_kind == "binoculars":
		hip = Vector3(0.0, -0.25, -0.3)
		ads = Vector3(0, 0, -0.08)
	var p := hip.lerp(ads, ease(aiming, 0.6))
	if _sprinting:
		p += Vector3(-0.05, -0.08, 0.04)
	if reloading > 0.0:
		p += Vector3(0, -0.12, 0.05)
	p.y += sin(_bob) * 0.008 * (1.0 - aiming)
	p.x += cos(_bob * 0.5) * 0.01 * (1.0 - aiming)
	p.z += _recoil * 0.07
	gun.position = gun.position.lerp(p, clampf(dt * 16.0, 0.0, 1.0))
	gun.rotation = Vector3(_recoil * 0.35 + (0.35 if reloading > 0.0 else 0.0), (0.4 if _sprinting else 0.0), (-0.3 if reloading > 0.0 else 0.0))


# ---------------------------------------------------------------- shooting

func _fire_input() -> void:
	if world.ui_open() or binos:
		return
	if Input.is_action_just_pressed("fire"):
		if reloading > 0.0 and weapon().get("per_round", false) and int(Game.mag.get(gun_kind, 0)) > 0:
			reloading = 0.0 # stop feeding the tube and shoot
		if fire_cool > 0.0 or reloading > 0.0:
			return
		var m := int(Game.mag.get(gun_kind, 0))
		if m <= 0:
			Sfx.play("click", -4.0)
			_start_reload()
			return
		_fire()


func _fire() -> void:
	var w := weapon()
	Game.mag[gun_kind] = int(Game.mag[gun_kind]) - 1
	fire_cool = float(w["rof"])
	var origin := cam.global_position
	var dir := -cam.global_transform.basis.z
	var spread := float(w["spread"]) * (1.0 if aiming > 0.9 else 6.0) * (1.6 if _moving else 1.0)
	dir = (dir + cam.global_transform.basis.x * randfn(0.0, spread) + cam.global_transform.basis.y * randfn(0.0, spread)).normalized()
	world.fire(origin, dir, gun_kind, self)
	_recoil = 1.0
	var kick := {"lever": 0.03, "bolt": 0.035, "thumper": 0.07, "coil": 0.012, "plasma": 0.04, "rail": 0.06}.get(gun_kind, 0.03) as float
	_kick += Vector2(randf_range(-0.3, 0.3) * kick, kick)
	_pitch += kick * 0.4
	Sfx.play(String(w["sound"]), 0.0 if String(w["sound"]) != "coil" else -4.0, randf_range(0.95, 1.05))
	world.muzzle_flash(gun.get_node("Muzzle").global_position if gun.has_node("Muzzle") else origin, w)
	world.noise(global_position, float(w["noise"]), "shot")
	Game.stat("shots")
	# Cycle the action.
	if w["kind"] in ["bolt", "lever"]:
		get_tree().create_timer(0.35).timeout.connect(func() -> void: Sfx.play("bolt" if w["kind"] == "bolt" else "lever", -9.0))


func _start_reload() -> void:
	var w := weapon()
	if w.is_empty() or reloading > 0.0:
		return
	var a: String = w["ammo"]
	var have := int(Game.ammo.get(a, 0))
	var m := int(Game.mag.get(gun_kind, 0))
	if m >= int(w["mag"]):
		return
	if have <= 0:
		Game.say("Out of %s. Buy more at the trade radio." % Catalog.AMMO[a]["name"], Color(1, 0.6, 0.4))
		return
	reloading = float(w["reload"])
	Sfx.play("load", -6.0)


func _reload_tick(dt: float) -> void:
	if reloading <= 0.0:
		return
	reloading -= dt
	if reloading > 0.0:
		return
	var w := weapon()
	if w.is_empty():
		return
	var a: String = w["ammo"]
	var have := int(Game.ammo.get(a, 0))
	var m := int(Game.mag.get(gun_kind, 0))
	if bool(w.get("per_round", false)):
		if have > 0 and m < int(w["mag"]):
			Game.mag[gun_kind] = m + 1
			Game.ammo[a] = have - 1
			Sfx.play("load", -8.0, randf_range(0.95, 1.1))
			if m + 1 < int(w["mag"]) and have - 1 > 0:
				reloading = float(w["reload"])
	else:
		var n := mini(int(w["mag"]) - m, have)
		Game.mag[gun_kind] = m + n
		Game.ammo[a] = have - n
		Sfx.play("bolt", -6.0)
	Game.changed.emit()


# ---------------------------------------------------------------- looking

## What's under the crosshair: range, and the animal (for the glass and the
## heart scanner).
func _look_at_things(dt: float) -> void:
	range_m = -1.0
	aim_creature = null
	if aiming < 0.5:
		_vitals(null, 0)
		return
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * 1500.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		range_m = from.distance_to(hit["position"])
		if hit["collider"] is Creature:
			aim_creature = hit["collider"]
	if aim_creature == null:
		# A little forgiveness: the nearest animal close to the crosshair.
		var best := 0.9994
		for c in world.creatures:
			var cr := c as Creature
			if cr == null or cr.dead:
				continue
			var d := (cr.center() - from)
			if d.length() > 900.0:
				continue
			var dot := d.normalized().dot(-cam.global_transform.basis.z)
			if dot > best:
				best = dot
				aim_creature = cr
	if aim_creature != null and not Game.seen_species.has(aim_creature.species):
		Game.seen_species[aim_creature.species] = true
		Game.journal("First sighting: %s." % aim_creature.name_text())
	var lv := Game.scanner_level()
	var reach := [0.0, 120.0, 300.0, 600.0][lv] as float
	if scoped and aim_creature != null and lv > 0 and from.distance_to(aim_creature.center()) < reach:
		_vitals(aim_creature, lv)
	else:
		_vitals(null, 0)


func _vitals(c: Creature, lv: int) -> void:
	if _vitals_shown != null and is_instance_valid(_vitals_shown) and _vitals_shown != c:
		_vitals_shown.show_vitals(0)
	if c != null:
		if _vitals_shown != c:
			Sfx.play("scanner", -10.0)
		c.show_vitals(lv)
	_vitals_shown = c


# ---------------------------------------------------------------- using things

func _interact_tick(dt: float) -> void:
	interact_target = null
	if world.ui_open():
		return
	var best: Object = null
	var best_s := -INF
	var from := cam.global_position
	var fwd := -cam.global_transform.basis.z
	for it in world.interactables():
		var pos: Vector3 = it.call("interact_pos")
		var d := from.distance_to(pos)
		var r: float = it.call("interact_radius")
		if d > r:
			continue
		var dot := (pos - from).normalized().dot(fwd)
		if dot < 0.55 and d > 1.2:
			continue
		var s := dot * 2.0 - d / r
		if s > best_s:
			best_s = s
			best = it
	interact_target = best
	if best == null:
		harvest_t = 0.0
		return
	var hold: float = best.call("interact_hold")
	if hold > 0.0:
		if Input.is_action_pressed("use"):
			if harvest_t == 0.0:
				Sfx.play("harvest", -6.0)
			harvest_t += dt
			if harvest_t >= hold:
				harvest_t = 0.0
				best.call("interact", self)
		else:
			harvest_t = 0.0
	elif Input.is_action_just_pressed("use"):
		best.call("interact", self)


# ---------------------------------------------------------------- what animals sense

func noise_radius() -> float:
	if not _moving:
		return 0.0
	if crouched:
		return 7.0
	if _sprinting:
		return 70.0
	return 24.0


func visibility() -> float:
	var v := 1.0
	if crouched:
		v *= 0.55
	if not _moving:
		v *= 0.7
	if cloak_on:
		v *= 0.33
	return v


func moving() -> bool:
	return _moving


func hurt(dmg: float, from: Vector3) -> void:
	if dead:
		return
	health -= dmg
	hurt_flash = 0.6
	var push := (global_position - from)
	push.y = 0.0
	velocity += push.normalized() * 6.0 + Vector3(0, 3.0, 0)
	_kick += Vector2(randf_range(-0.1, 0.1), 0.08)
	if health <= 0.0:
		world.player_died()


func look_dir(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = pitch
	rotation.y = yaw
