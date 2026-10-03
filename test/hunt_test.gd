extends Node
## The hunt, end to end: herds about, a heart shot drops an animal after its
## dead run, lungs bleed it out, the brain drops it on the spot, the
## Ironcrown needs both hearts, harvesting fills the pack, the trader buys,
## guns can be bought, spotting tags, and the save holds.
## xvfb-run godot --path . res://test/hunt_test.tscn   (SHOTDIR=... for pictures)

var world: World
var fails := 0
var dir := ""


func _ok(what: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _ready() -> void:
	dir = OS.get_environment("SHOTDIR")
	Game.new_game()
	Game.time_of_day = 10.0
	var g: Node = load("res://ui/game.tscn").instantiate()
	add_child(g)
	world = g.world
	await world.loaded
	world.atmo.paused = true
	# Out into the open field south of the farm, clear of buildings and trees.
	var spot := Vector3(Terrain.FARM.x - 160.0, 0, Terrain.FARM.y + 160.0)
	spot.y = world.terrain.height_at(spot.x, spot.z) + 0.5
	world.player.global_position = spot
	for k in world.flora.get_children():
		if k is StaticBody3D:
			(k as StaticBody3D).collision_layer = 0
	await _frames(10)
	var n := 0
	for c in world.creatures:
		if is_instance_valid(c):
			n += 1
	_ok("plenty of animals about (%d)" % n, n >= 40)
	# Clear the wild herds so nothing wanders into the test shots.
	for c in world.creatures.duplicate():
		(c as Node).queue_free()
	world.set_process(false)
	await _frames(3)
	await _heart()
	await _harvest_and_sell()
	await _lungs()
	await _brain()
	await _ironcrown()
	await _spotting()
	await _shop()
	await _sights()
	await _blink()
	await _farm_defense()
	_save_load()
	print("HUNT TEST DONE fails=%d" % fails)
	get_tree().quit()


func _frames(k: int) -> void:
	for i in k:
		await get_tree().physics_frame


var _ang := 0.0


func _target(kind: String, dist: float = 40.0) -> Creature:
	var p := world.player.global_position
	_ang += 1.25 # a fresh line of fire each time, clear of earlier carcasses
	var at := p + Vector3(cos(_ang) * dist, 0, sin(_ang) * dist)
	at.y = world.terrain.height_at(at.x, at.z)
	var h := world.spawn_herd(kind, at, 1)
	var c: Creature = h[0]
	c.set_physics_process(false) # hold still for the test shot
	await _frames(2)
	return c


func _shoot_at(c: Creature, point: Vector3, gun: String = "lever") -> void:
	# Fire from 15 m off, in clear air, so hills and carcasses can't get in the way.
	var back := (world.player.global_position - c.global_position)
	back.y = 0.0
	var from := point + back.normalized() * 8.0 + Vector3(0, 0.4, 0)
	var d := (point - from).normalized()
	# Undo the zero so the round flies straight at the point over this range.
	world.fire(from, d, gun, world.player)
	var b: Dictionary = world.bullets[world.bullets.size() - 1]
	b["drop"] = 0.0
	b["vel"] = d * float((b["vel"] as Vector3).length())
	await _frames(12)
	print("  hit: ", c.last_organ, "  round ended at ", (b["pos"] as Vector3).distance_to(point), " m from the aim point")


func _heart() -> void:
	print("PHASE heart shot")
	var c := await _target("moorhorn")
	var xp0 := Game.xp
	await _shoot_at(c, c.heart_world(0))
	_ok("heart hit starts the dead run", c.heart_killed and c.death_t > 0.0 or c.dead)
	c.set_physics_process(true)
	for i in 300:
		await get_tree().physics_frame
		if c.dead:
			break
	_ok("it drops within seconds", c.dead)
	_ok("clean kill pays XP (%d -> %d)" % [xp0, Game.xp], Game.xp > xp0)
	_ok("one hole, a fine hide (%.0f)" % c.hide_q, c.hide_q >= 80.0)
	set_meta("heart_c", c)


func _harvest_and_sell() -> void:
	print("PHASE harvest")
	var c: Creature = get_meta("heart_c")
	world.player.global_position = c.global_position + Vector3(2, 0.5, 0)
	await _frames(3)
	print("  dist ", world.player.global_position.distance_to(c.global_position), " dead ", c.dead, " dt ", c.death_t, " n ", world.interactables().size())
	var found := false
	for it in world.interactables():
		if it is Carcass and (it as Carcass).c == c:
			found = true
	_ok("the carcass offers a harvest", found)
	world.harvest(c)
	_ok("hide and horns in the pack (%d)" % Game.carried.size(), Game.carried.size() == 2)
	var horn: Dictionary = {}
	for t in Game.carried:
		if t["kind"] == "horn":
			horn = t
	_ok("the horns carry a score and class (%.1f %s)" % [float(horn.get("score", 0.0)), horn.get("class", "")], float(horn.get("score", 0.0)) > 10.0 and horn.get("class", "") != "")
	var s0 := Game.scrip
	var got := Game.sell(0)
	_ok("the Exchange buys it (+%d)" % got, got > 0 and Game.scrip > s0)
	Game.mount(0)
	_ok("horns go on the wall", Game.wall.size() == 1)
	world.structures.refresh_wall()
	await _frames(2)
	_ok("and appear in the farmhouse", world.structures.wall_root.get_child_count() >= 1)


func _lungs() -> void:
	print("PHASE lungs")
	var c := await _target("stagwraith", 50.0)
	var lung: Array = c.lungs()[0]
	var p: Vector3 = c.model.global_transform * (lung[0] as Vector3)
	# Make sure the line doesn't pass through the heart as well.
	c.hearts[0] = Vector3(0, float(c._p["torso_y"]) - 0.1, float(c._p["L"]) * 0.3)
	await _shoot_at(c, p)
	var p0 := c.global_position
	_ok("lung hit bleeds hard (%.1f/s)" % c.bleed, c.bleed > c.max_hp * 0.04 and not c.dead)
	c.set_physics_process(true)
	Engine.time_scale = 6.0
	for i in 60 * 30:
		await get_tree().physics_frame
		if c.dead:
			break
	Engine.time_scale = 1.0
	_ok("it runs, bleeds and goes down (ran %d m)" % int(c.global_position.distance_to(p0)), c.dead)
	var drops := 0
	for b in world._blood:
		if (b as MeshInstance3D).visible:
			drops += 1
	_ok("leaving a blood trail (%d drops)" % drops, drops > 5)


func _brain() -> void:
	print("PHASE brain")
	var c := await _target("tuskmaw", 30.0)
	var brain := c.head.global_transform * Vector3(0, float(c.sp["body"]["head"]) * 0.08, 0)
	await _shoot_at(c, brain, "lever")
	print("  organ hit: ", c.shots_taken, " dead=", c.dead)
	_ok("a brain shot drops it where it stands", c.dead and c.death_t < 0.0)


func _ironcrown() -> void:
	print("PHASE ironcrown")
	var c := await _target("ironcrown", 60.0)
	_ok("the Ironcrown has two hearts", c.hearts.size() == 2)
	var q := PhysicsRayQueryParameters3D.create(world.player.cam.global_position, c.heart_world(0), 4)
	print("  ray: ", world.get_world_3d().direct_space_state.intersect_ray(q), " shapes ", c.get_child_count(), " layer ", c.collision_layer, " pos ", c.global_position, " heart ", c.heart_world(0), " size ", c.size)
	var keep := c.hp
	await _shoot_at(c, c.heart_world(0), "thumper")
	_ok("one heart isn't enough", not c.dead and c.death_t < 0.0)
	c.hp = keep
	await _shoot_at(c, c.heart_world(1), "thumper")
	_ok("both hearts are", c.death_t > 0.0 or c.dead)


func _spotting() -> void:
	print("PHASE spotting")
	var c := await _target("ramspire", 80.0)
	var p := world.player
	p.binos = true
	p.equip("binoculars")
	p.look_dir(atan2(-(c.center().x - p.global_position.x), -(c.center().z - p.global_position.z)), 0.0)
	p.cam.look_at(c.center(), Vector3.UP)
	p._yaw = p.rotation.y
	Input.action_press("aim")
	for i in 40:
		p.pivot.rotation = Vector3.ZERO
		p.cam.look_at(c.center(), Vector3.UP)
		await get_tree().process_frame
	Input.action_release("aim")
	_ok("glassing an animal spots it", c.tagged_until > Time.get_ticks_msec() / 1000.0)
	p.binos = false
	p.equip(Game.weapon)
	p.cam.rotation = Vector3.ZERO


func _shop() -> void:
	print("PHASE shop")
	Game.add_xp(500)
	Game.scrip += 3000
	_ok("rank 2 unlocks the .308", Game.can_buy_weapon("bolt") == "")
	_ok("bought it", Game.buy_weapon("bolt"))
	_ok("with ammo", int(Game.ammo.get("308", 0)) > 0)
	_ok("gear: heart scanner", Game.buy_gear("scanner1"))
	_ok("the rail gun still needs rank 9", Game.can_buy_weapon("rail").begins_with("rank"))
	var shop: Node = load("res://ui/shop.gd").new()
	shop.call("setup", world)
	world.hud.add_child(shop)
	await _frames(3)
	_ok("the trading post opens", world.ui_open())
	shop.call("close")
	await _frames(2)
	_ok("and closes", not world.ui_open())


## Aim down the sights: iron sights on the lever gun, the scope on the .308.
func _sights() -> void:
	print("PHASE sights")
	var p := world.player
	p.cam.rotation = Vector3.ZERO
	var c := await _target("moorhorn", 35.0)
	p.look_dir(atan2(-(c.center().x - p.global_position.x), -(c.center().z - p.global_position.z)), 0.0)
	p.equip("lever")
	Input.action_press("aim")
	await _frames(40)
	_ok("aiming down the sights", p.aiming > 0.95)
	_ok("Grandpa's rifle has a scope too", p.scoped)
	await _pic("ads_lever")
	p.equip("bolt")
	await _frames(40)
	_ok("the .308 looks through its scope", p.scoped)
	Game.gear["scanner1"] = 1
	await _frames(10)
	await _pic("ads_scope")
	Input.action_release("aim")
	await _frames(20)


func _blink() -> void:
	print("PHASE blink")
	var p := world.player
	p.cam.top_level = false
	p.cam.transform = Transform3D.IDENTITY
	p.look_dir(0.0, -0.12)
	p.pivot.rotation = Vector3(-0.12, 0, 0)
	var from := p.global_position
	p.start_blink()
	for i in 5:
		await get_tree().process_frame
	_ok("R1 shows the blink target (%d m)" % int(from.distance_to(p.blink_target)), p.blink_state == 1 and p._blink_marker.visible)
	p.cancel_blink()
	_ok("Circle cancels it", p.blink_state == 0 and not p._blink_marker.visible)
	p.start_blink()
	for i in 5:
		await get_tree().process_frame
	var target := p.blink_target
	var ok := p.blink_ok
	p.confirm_blink()
	await get_tree().process_frame
	_ok("R1 again blinks you there (moved %d m)" % int(from.distance_to(p.global_position)), not ok or p.global_position.distance_to(target) < 1.0)
	_ok("and it has to recharge", p.blink_cool > 0.0 or not ok)


func _farm_defense() -> void:
	print("PHASE farm")
	_ok("Dale is with you", world.companion != null and world.companion.body != null)
	_ok("the farm starts with a wall and a turret", world.farm.level("wall") == 1 and world.farm.turrets.size() == 1)
	# A ghoul in the open: a head shot drops it.
	var gp := world.player.global_position + Vector3(20, 0, 20)
	gp.y = world.terrain.height_at(gp.x, gp.z)
	var g: Ghoul = world.spawn_ghoul("ghoul", gp, false)
	g.set_physics_process(false)
	await _frames(2)
	var head := g.global_position + Vector3(0, g.h * 0.92, 0)
	var from := head + Vector3(-6, 0.2, 0)
	world.fire(from, (head - from).normalized(), "bolt", world.player)
	var b: Dictionary = world.bullets[world.bullets.size() - 1]
	b["drop"] = 0.0
	b["vel"] = (head - from).normalized() * 820.0
	await _frames(10)
	_ok("a head shot drops a ghoul", g.dead)
	# A raid: the turrets (and a couple more we build) hold the wall.
	Game.scrip += 5000
	_ok("the workbench sells turrets", world.farm.buy("turrets") and world.farm.turrets.size() == 2)
	_ok("tesla needs Xyla first", world.farm.why_not("tesla") != "")
	world.player.global_position = world.farm.core() + Vector3(0, 0.5, 0)
	world.farm.start_raid(4)
	_ok("a raid spawns ghouls", world.farm.raid_on and world.farm.raid_ghouls.size() == 4)
	for gh in world.farm.raid_ghouls:
		var gg := gh as Ghoul
		var dir := (gg.global_position - world.farm.center).normalized()
		gg.global_position = world.farm.center + dir * 70.0
	Engine.time_scale = 4.0
	for i in 60 * 50:
		await get_tree().physics_frame
		if not world.farm.raid_on:
			break
	Engine.time_scale = 1.0
	_ok("the farm holds the raid (wall %d)" % int(Game.wall_hp), not world.farm.raid_on)
	# Rank 5: Xyla turns up.
	Game.add_xp(2000)
	world.set_process(true)
	for i in 70:
		await get_tree().process_frame
	_ok("Xyla joins the farm at rank 5", Game.xyla and world.xyla_npc != null)
	world.talk_xyla()
	_ok("and has something to say", Game.xyla_talk == 1)
	_ok("now the tesla tower can be built", world.farm.why_not("tesla") == "")


func _pic(n: String) -> void:
	if dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, n])


func _save_load() -> void:
	print("PHASE save")
	var xp := Game.xp
	var s := Game.scrip
	var wall := Game.wall.size()
	Game.save_game()
	Game.xp = 0
	Game.scrip = 0
	Game.wall = []
	_ok("save loads", Game.load_game())
	_ok("and keeps your progress", Game.xp == xp and Game.scrip == s and Game.wall.size() == wall)
