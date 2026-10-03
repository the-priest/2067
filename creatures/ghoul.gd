class_name Ghoul
extends CharacterBody3D
## What the bombs left of people (ghouls), and of the Xhuul soldiers who
## stayed behind (the Burnt: tall, four-armed, glowing). They shamble toward
## the farm when the horns call them, or toward you if you're closer.
## Head shots do triple.

var world: Node
var kind := "ghoul"
var body: Humanoid
var hp := 80.0
var max_hp := 80.0
var dead := false
var raid := false
var speed := 2.2
var dmg := 10.0
var h := 1.75
var _attack_t := 0.0
var _groan_t := 0.0
var _dead_t := 0.0
var _rng := RandomNumberGenerator.new()
var at_wall := false


func setup(w: Node, k: String, at: Vector3, is_raid: bool) -> void:
	world = w
	kind = k
	raid = is_raid
	_rng.randomize()
	if kind == "burnt":
		hp = 220.0
		speed = 3.2
		dmg = 22.0
		h = 2.25
	max_hp = hp
	collision_layer = 4
	collision_mask = 0
	body = Humanoid.make(kind, _rng.randi())
	add_child(body)
	body.set_anim("walk")
	body.speed = _rng.randf_range(0.8, 1.1)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = h
	cs.shape = cap
	cs.position.y = h * 0.5
	add_child(cs)
	global_position = at
	_groan_t = _rng.randf_range(1.0, 6.0)
	add_to_group("ghoul")


func target_pos() -> Vector3:
	var pp: Vector3 = world.player.global_position
	if not raid or pp.distance_to(global_position) < 35.0:
		return pp
	return world.farm.core()


func _physics_process(dt: float) -> void:
	if world == null or not world.ready_done:
		return
	if dead:
		_dead_t += dt
		if _dead_t > 30.0:
			queue_free()
		return
	_groan_t -= dt
	if _groan_t <= 0.0:
		_groan_t = _rng.randf_range(4.0, 9.0)
		Sfx.play_at("grunt" if kind == "ghoul" else "roar", global_position + Vector3(0, h, 0), -2.0, 60.0, _rng.randf_range(0.5, 0.7) if kind == "ghoul" else 1.6)
	_attack_t -= dt
	var tp := target_pos()
	var to := tp - global_position
	to.y = 0.0
	var d := to.length()
	var pp: Vector3 = world.player.global_position
	# The farm's wall stops them until they tear through it.
	at_wall = false
	if raid and world.farm != null and world.farm.blocks(global_position, tp):
		at_wall = true
		body.set_anim("attack")
		if _attack_t <= 0.0:
			_attack_t = 1.1
			world.farm.hit_wall(dmg, global_position)
		_face(tp, dt)
		return
	if global_position.distance_to(pp) < 1.9:
		body.set_anim("attack")
		_face(pp, dt)
		if _attack_t <= 0.0:
			_attack_t = 1.0
			world.player.call("hurt", dmg, global_position)
		return
	if raid and world.farm != null and d < 4.0:
		# In the yard, wrecking things.
		body.set_anim("attack")
		if _attack_t <= 0.0:
			_attack_t = 1.5
			world.farm.breach(dmg)
		return
	body.set_anim("walk" if kind == "ghoul" or d > 30.0 else "run")
	if d > 0.5:
		var dir := to / d
		var np := global_position + dir * speed * (1.6 if body.anim == "run" else 1.0) * dt
		np.y = world.terrain.height_at(np.x, np.z)
		global_position = np
		_face(tp, dt)


func _face(at: Vector3, dt: float) -> void:
	var want := atan2(-(at.x - global_position.x), -(at.z - global_position.z))
	rotation.y = lerp_angle(rotation.y, want, clampf(dt * 5.0, 0.0, 1.0))


## A rifle round. Head shots do triple.
func take_shot(at: Vector3, _dir: Vector3, _w: Dictionary, d: float) -> Dictionary:
	if dead:
		return {"organ": "CORPSE"}
	var head := at.y > global_position.y + h * 0.82
	world.blood_spray(at, _dir, body.k.get("glow", Color(0.5, 1.0, 0.2)))
	hurt(d * (3.0 if head else 1.0), at)
	return {"organ": "HEADSHOT" if head else ("GHOUL" if kind == "ghoul" else "BURNT"), "kill": dead}


func hurt(amount: float, _from: Vector3) -> void:
	if dead:
		return
	hp -= amount
	if hp <= 0.0:
		dead = true
		body.set_anim("dead")
		collision_layer = 0
		var bounty := 15 if kind == "ghoul" else 45
		Game.add_scrip(bounty)
		Game.add_xp(8 if kind == "ghoul" else 25)
		Game.stat("ghouls")
		Game.say("%s down  +%d scrip" % ["Ghoul" if kind == "ghoul" else "Burnt", bounty], Color(0.7, 1.0, 0.5))
		Sfx.play_at("thud", global_position, 0.0, 40.0)
		world.ghoul_died(self)
