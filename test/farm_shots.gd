extends Node
## Pictures of the farm under attack. SHOTDIR=... xvfb-run godot --path . res://test/farm_shots.tscn
var world: World
func _ready() -> void:
	Game.new_game()
	Game.time_of_day = 17.0
	var g: Node = load("res://ui/game.tscn").instantiate()
	add_child(g)
	world = g.world
	await world.loaded
	world.atmo.paused = true
	for c in world.creatures.duplicate():
		(c as Node).queue_free()
	Game.defense["turrets"] = 4
	Game.defense["spikes"] = 1
	world.farm.rebuild()
	world.farm.start_raid(6)
	for gh in world.farm.raid_ghouls:
		var dir := ((gh as Node3D).global_position - world.farm.center).normalized()
		(gh as Node3D).global_position = world.farm.center + dir * 60.0
	var cam := world.player.cam
	cam.top_level = true
	await get_tree().create_timer(2.0).timeout
	cam.global_position = world.farm.center + Vector3(-30, 14, 70)
	cam.look_at(world.farm.center, Vector3.UP)
	await _shot("farm_raid")
	var gh0: Node3D = world.farm.raid_ghouls[0]
	cam.global_position = gh0.global_position + Vector3(3, 1.8, 3)
	cam.look_at(gh0.global_position + Vector3(0, 1.2, 0), Vector3.UP)
	await _shot("farm_ghoul")
	world.companion.global_position = world.player.global_position + Vector3(2, 0, 2)
	await get_tree().create_timer(0.5).timeout
	cam.global_position = world.companion.global_position + Vector3(0.5, 1.7, -3.0)
	cam.look_at(world.companion.global_position + Vector3(0, 1.3, 0), Vector3.UP)
	await _shot("farm_dale")
	get_tree().quit()
func _shot(n: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTDIR") + "/" + n + ".png")
	print("SHOT ", n)
