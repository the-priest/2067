class_name Companion
extends Node3D
## Dale. Follows a few steps behind, crouches when you crouch, spots game
## and calls it out ("Moorhorn, two hundred metres, by the dead oak"),
## marks it for you, cracks wise about your shooting, shoots ghouls, and
## carries two trophies for you. If you run off he catches up.

var world: Node
var body: Humanoid
var who := "dale"
var _spot_t := 8.0
var _talk_t := 30.0
var _shoot_t := 0.0
var _last_line := ""
var _rng := RandomNumberGenerator.new()
var _vel := Vector3.ZERO
var follow := true
var home := Vector3.ZERO # where to stand when not following


func setup(w: Node, kind: String = "dale") -> void:
	world = w
	who = kind
	body = Humanoid.make(kind, 7, kind == "dale")
	add_child(body)
	_rng.randomize()


func say(t: String, force: bool = false) -> void:
	if t == "" or (t == _last_line and not force):
		return
	_last_line = t
	_talk_t = _rng.randf_range(25.0, 50.0)
	if world.hud != null:
		world.hud.call("subtitle", "DALE" if who == "dale" else "XYLA", t, Color(1.0, 0.8, 0.45) if who == "dale" else Color(0.55, 0.95, 1.0))


func _process(dt: float) -> void:
	if world == null or not world.ready_done:
		return
	var p: Player = world.player
	var pp := p.global_position
	var target := pp
	if follow:
		# A few steps behind and to the right of where you're looking.
		var yaw := p.rotation.y
		target = pp + Basis(Vector3.UP, yaw) * Vector3(2.4, 0, 3.2)
	else:
		target = home
	var to := target - global_position
	to.y = 0.0
	var d := to.length()
	if follow and d > 70.0:
		# Lost you: catch up out of sight.
		global_position = target
		d = 0.0
	var spd := 0.0
	if d > 1.2:
		spd = clampf(d * 0.9, 1.4, 6.5 if d > 8.0 else 3.4)
		if p.crouched:
			spd = minf(spd, 1.8)
		var dir := to / d
		global_position += dir * spd * dt
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(dt * 6.0, 0.0, 1.0))
	elif follow:
		var look := p.global_position + -p.global_transform.basis.z * 20.0 - global_position
		rotation.y = lerp_angle(rotation.y, atan2(-look.x, -look.z), clampf(dt * 3.0, 0.0, 1.0))
	global_position.y = world.terrain.height_at(global_position.x, global_position.z)
	body.crouch = move_toward(body.crouch, 1.0 if (p.crouched and follow) else 0.0, dt * 3.0)
	if _shoot_t > 0.0:
		body.set_anim("aim")
	elif spd > 4.0:
		body.set_anim("run")
	elif spd > 0.3:
		body.set_anim("walk")
	elif p.aiming > 0.5 and follow:
		body.set_anim("aim")
	else:
		body.set_anim("idle")
	body.speed = 1.0 if spd < 4.0 else 1.2
	_shoot_t -= dt
	if follow:
		_spot(dt)
		_fight(dt)
	_talk_t -= dt
	if _talk_t <= 0.0:
		var k := "night" if Game.is_night() and _rng.randf() < 0.3 else "idle"
		if who == "dale" and Game.xyla and _rng.randf() < 0.25:
			k = "xyla"
		if who == "dale":
			say(Story.line(k))
		else:
			_talk_t = 999.0


## Find game the player hasn't seen, and call it out.
func _spot(dt: float) -> void:
	_spot_t -= dt
	if _spot_t > 0.0:
		return
	_spot_t = _rng.randf_range(10.0, 20.0)
	var p: Player = world.player
	var best: Creature = null
	var bd := 380.0
	var now := Time.get_ticks_msec() / 1000.0
	for c in world.creatures:
		var cr := c as Creature
		if cr.dead or cr.tagged_until > now or cr.species == "howler":
			continue
		var dd := cr.global_position.distance_to(global_position)
		if dd < bd and dd > 25.0:
			bd = dd
			best = cr
	if best == null:
		return
	best.tagged_until = now + 60.0
	var rel := best.global_position - p.global_position
	var fwd := -p.global_transform.basis.z
	var ang := rad_to_deg(atan2(fwd.cross(Vector3(rel.x, 0, rel.z).normalized()).y, fwd.dot(Vector3(rel.x, 0, rel.z).normalized())))
	var dir := "dead ahead"
	if absf(ang) > 150.0:
		dir = "behind us"
	elif ang > 60.0:
		dir = "off to your left"
	elif ang > 20.0:
		dir = "left a touch"
	elif ang < -60.0:
		dir = "off to your right"
	elif ang < -20.0:
		dir = "right a touch"
	var name := best.name_text() if not best.legendary else "THE IRONCROWN"
	if best.size > 1.38:
		name = "big old " + name
	say(Story.line("spot", {"species": name, "dist": int(round(bd / 10.0) * 10.0), "dir": dir}))
	Sfx.play("scanner", -14.0, 1.2)


## Ghouls and the Burnt: Dale shoots at anything coming for you.
func _fight(_dt: float) -> void:
	if _shoot_t > -1.2:
		return
	var target: Node3D = null
	var bd := 70.0
	for g in world.ghouls:
		var gh := g as Node3D
		if not is_instance_valid(gh) or gh.get("dead"):
			continue
		var dd := gh.global_position.distance_to(global_position)
		if dd < bd:
			bd = dd
			target = gh
	if target == null:
		return
	_shoot_t = 0.8
	var look := target.global_position - global_position
	rotation.y = atan2(-look.x, -look.z)
	Sfx.play_at("rifle", global_position + Vector3(0, 1.5, 0), -4.0, 120.0, 1.1)
	world.muzzle_flash(global_position + Vector3(0, 1.5, 0) - global_transform.basis.z * 0.9, Catalog.WEAPONS["lever"])
	if _rng.randf() < 0.6:
		target.call("hurt", 45.0, global_position)


## Events from the world.
func react(what: String) -> void:
	if who != "dale":
		return
	if _rng.randf() < (0.9 if what in ["heart", "ghoul", "burnt", "raid", "wounded"] else 0.5):
		say(Story.line(what), true)
