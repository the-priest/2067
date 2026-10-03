extends Node
## What a frame costs: objects, draw calls, triangles, script time.
var world: World
func _ready() -> void:
	Game.new_game()
	Game.time_of_day = 10.0
	var g: Node = load("res://ui/game.tscn").instantiate()
	add_child(g)
	world = g.world
	await world.loaded
	for i in 60:
		await get_tree().process_frame
	_report("porch")
	for c in world.creatures:
		(c as Node).set_process(false)
	for i in 20:
		await get_tree().process_frame
	_report("no creature _process")
	for c in world.creatures:
		(c as Node).set_process(true)
	world.set_process(false)
	for i in 20:
		await get_tree().process_frame
	_report("no world _process")
	world.set_process(true)
	world.hud.set_process(false)
	for i in 20:
		await get_tree().process_frame
	_report("no hud")
	world.hud.set_process(true)
	world.farm.set_process(false)
	world.companion.set_process(false)
	world.player.set_process(false)
	for i in 20:
		await get_tree().process_frame
	_report("no farm/dale/player")
	world.farm.set_process(true)
	world.companion.set_process(true)
	world.player.set_process(true)
	world.player.global_position = Vector3(-500, world.terrain.height_at(-500, -60) + 1, -60)
	world.terrain.build_lod_now(world.player.global_position)
	for i in 60:
		await get_tree().process_frame
	_report("forest")
	var groups := {"flora": world.flora, "terrain": world.terrain, "structures": world.structures}
	for k in groups.keys():
		(groups[k] as Node3D).visible = false
		for i in 5:
			await get_tree().process_frame
		_report("forest without " + k)
		(groups[k] as Node3D).visible = true
	for c in world.creatures:
		(c as Node3D).visible = false
	for i in 5:
		await get_tree().process_frame
	_report("forest without creatures")
	for c in world.creatures:
		(c as Node3D).visible = true
	world.atmo.sun.shadow_enabled = false
	for i in 5:
		await get_tree().process_frame
	_report("forest without sun shadows")
	world.atmo.sun.shadow_enabled = true
	world.player.global_position = Vector3(-100, world.terrain.height_at(-100, 420) + 1, 420)
	for i in 60:
		await get_tree().process_frame
	_report("fields")
	get_tree().quit()
func _report(n: String) -> void:
	var rs := RenderingServer
	print("%s: objects %d  draws %d  prims %dk  creatures %d  process %.2fms physics %.2fms" % [n,
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
		world.creatures.size(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
