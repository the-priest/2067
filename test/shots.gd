extends Node
## Screenshots from around the valley. SHOTDIR=... xvfb-run godot --path . res://test/shots.tscn

var game: Node
var world: World
var dir := ""


func _ready() -> void:
	dir = OS.get_environment("SHOTDIR")
	if dir == "":
		dir = "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	Game.new_game()
	Game.time_of_day = float(OS.get_environment("TOD")) if OS.get_environment("TOD") != "" else 9.0
	game = load("res://ui/game.tscn").instantiate()
	add_child(game)
	world = game.world
	await world.loaded
	var t0 := Time.get_ticks_msec()
	for i in 30:
		await get_tree().process_frame
	print("FPS-ish frames in %d ms" % (Time.get_ticks_msec() - t0))
	world.atmo.paused = true
	await _shot("01_porch")
	# Look at the farm from the field.
	_cam_at(Vector3(Terrain.FARM.x + 30, 0, Terrain.FARM.y + 70), Vector3(Terrain.FARM.x, 4, Terrain.FARM.y))
	await _shot("02_farm")
	# A herd up close.
	var c: Creature = null
	for cr in world.creatures:
		if not (cr as Creature).dead:
			c = cr
			break
	if c != null:
		var p := c.global_position
		_cam_at(p + Vector3(6, 2.0, 5) * c.size, p + Vector3(0, 1.0 * c.size, 0))
		await _shot("03_creature_" + c.species)
		for kind in ["stagwraith", "tuskmaw", "ramspire", "crownelk", "howler", "ironcrown"]:
			var at := world.player.global_position + Vector3(0, 0, -40)
			at.y = world.terrain.height_at(at.x, at.z)
			var h := world.spawn_herd(kind, at, 1)
			var cc: Creature = h[0]
			cc.set_physics_process(false)
			var L := float(cc.sp["body"]["len"]) * cc.size
			_cam_at(cc.global_position + Vector3(L * 1.6, L * 0.6 + 0.5, L * 1.3), cc.global_position + Vector3(0, cc.size * float(cc.sp["body"]["leg"]) * 1.2, 0))
			await _shot("04_" + kind)
			cc.queue_free()
			world.creatures.erase(cc)
	_cam_at(world.structures.mothership + Vector3(-220, 70, 160), world.structures.mothership)
	await _shot("05_mothership")
	_cam_at(Vector3(-300, 80, 500), Vector3(-560, 0, 470))
	await _shot("06_lake")
	_cam_at(Vector3(-500, 30, -100), Vector3(-560, 10, -50))
	await _shot("07_forest")
	_cam_at(Vector3(0, 120, -200), Vector3(0, 80, -800))
	await _shot("08_ridges")
	print("SHOTS DONE")
	get_tree().quit()


func _cam_at(p: Vector3, look: Vector3) -> void:
	var h := world.terrain.height_at(p.x, p.z)
	if p.y < h + 1.7:
		p.y = h + 1.7
	world.player.global_position = Vector3(p.x, h, p.z)
	var cam := world.player.cam
	cam.top_level = true
	cam.global_position = p
	cam.look_at(look, Vector3.UP)
	world.terrain.build_lod_now(p)


func _shot(n: String) -> void:
	for i in 12:
		world.flora.update_grass(world.player.global_position)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir + "/" + n + ".png")
	print("SHOT ", n)
