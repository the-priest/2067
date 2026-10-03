extends Node
## Pictures of the trading post. SHOTDIR=... xvfb-run godot --path . res://test/post_shots.tscn
var world: World
func _ready() -> void:
	Game.new_game()
	Game.time_of_day = 16.5
	var g: Node = load("res://ui/game.tscn").instantiate()
	add_child(g)
	world = g.world
	await world.loaded
	world.atmo.paused = true
	var cam := world.player.cam
	cam.top_level = true
	var door: Vector3 = world.structures.post_spot
	world.player.global_position = door
	cam.global_position = door + Vector3(-6, 2.0, -12)
	cam.look_at(door + Vector3(0, 3.0, 6), Vector3.UP)
	await _shot("post_outside")
	cam.global_position = door + Vector3(-3.5, 1.7, 5.5)
	cam.look_at(door + Vector3(1.5, 1.6, 12.0), Vector3.UP)
	await _shot("post_inside")
	get_tree().quit()
func _shot(n: String) -> void:
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTDIR") + "/" + n + ".png")
