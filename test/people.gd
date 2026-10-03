extends Node3D
## Everyone lined up for a photo. SHOTDIR=... xvfb-run godot --path . res://test/people.tscn
func _ready() -> void:
	Game.time_of_day = 10.0
	var at := Atmosphere.new()
	add_child(at)
	at.paused = true
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	g.mesh = pm
	add_child(g)
	var kinds := ["dale", "xyla", "ghoul", "burnt", "grey", "soldier", "civilian"]
	var anims := ["idle", "wave", "walk", "attack", "idle", "aim", "run"]
	for i in kinds.size():
		var h := Humanoid.make(kinds[i], i, kinds[i] in ["dale", "soldier"])
		add_child(h)
		h.position = Vector3((i - 3) * 1.4, 0, 0)
		h.set_anim(anims[i])
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 1.4, -7.5)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	cam.make_current()
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTDIR") + "/people.png")
	cam.position = Vector3(-2.2, 1.75, -2.4)
	cam.look_at(Vector3(-2.8, 1.55, 0), Vector3.UP)
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTDIR") + "/people_close.png")
	get_tree().quit()
