extends Node3D
## Every hybrid in a studio: side and front views, for checking bodies and
## horns. SHOTDIR=... xvfb-run godot --path . res://test/gallery.tscn

var dir := ""


func _ready() -> void:
	dir = OS.get_environment("SHOTDIR")
	Game.time_of_day = 10.0
	var at := Atmosphere.new()
	add_child(at)
	at.paused = true
	var fake := MenuWorld.new()
	add_child(fake)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.4, 0.37, 0.3)
	g.material_override = gm
	add_child(g)
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.make_current()
	var only := OS.get_environment("ONLY")
	for kind in Catalog.SPECIES.keys():
		if only != "" and kind != only:
			continue
		var c := Creature.new()
		add_child(c)
		c.setup(fake, kind, Vector3.ZERO, int(OS.get_environment("HSEED")) if OS.get_environment("HSEED") != "" else 5, 0)
		c.set_physics_process(false)
		c.set_process(false)
		c.rotation.y = 0.0
		var L := float(c.sp["body"]["len"]) * c.size
		var H := (float(c.sp["body"]["leg"]) + float(c.sp["body"]["h"])) * c.size
		var hz := float(c.sp["horn_len"]) * 1.2
		var R := maxf(L * 1.9, H * 1.6) + hz
		for v in [["side", Vector3(R, H * 0.8, -L * 0.25)], ["front", Vector3(-R * 0.45, H * 1.0, -R * 0.9)], ["head", Vector3(R * 0.35, H * 1.3, -L * 0.5 - R * 0.75)]]:
			cam.position = v[1]
			cam.look_at(Vector3(0, H * 0.7, -L * 0.25 if v[0] != "head" else -L * 0.6), Vector3.UP)
			for i in 4:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/g_%s_%s_%s.png" % [dir, kind, v[0], OS.get_environment("HSEED")])
		c.queue_free()
		await get_tree().process_frame
	print("GALLERY DONE")
	get_tree().quit()
