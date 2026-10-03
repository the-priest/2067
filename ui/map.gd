extends UIPanel
## The valley from above: relief shading, the regions, your farm, the pods,
## the mothership, and you.

static var _tex: ImageTexture = null
var map_rect: TextureRect


func panel_title() -> String:
	return "THE VALLEY"


func panel_size() -> Vector2:
	return Vector2(820, 860)


func build() -> void:
	if _tex == null:
		_tex = ImageTexture.create_from_image(_render(world.terrain))
	map_rect = TextureRect.new()
	map_rect.texture = _tex
	map_rect.custom_minimum_size = Vector2(760, 760)
	map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_rect.stretch_mode = TextureRect.STRETCH_SCALE
	box.add_child(map_rect)
	map_rect.draw.connect(_marks)


static func _render(t: Terrain) -> Image:
	var n := 384
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var light := Vector3(-0.6, 0.7, -0.4).normalized()
	for y in n:
		for x in n:
			var wx := -Terrain.HALF + (x + 0.5) * Terrain.SIZE / n
			var wz := -Terrain.HALF + (y + 0.5) * Terrain.SIZE / n
			var h := t.height_at(wx, wz)
			var nrm := t.normal_at(wx, wz)
			var hab := t.habitat_at(wx, wz)
			var c := Color(0.55, 0.5, 0.35)
			match hab:
				"water":
					c = Color(0.16, 0.22, 0.2)
				"forest":
					c = Color(0.35, 0.33, 0.24)
				"marsh":
					c = Color(0.28, 0.32, 0.22)
				"scrub":
					c = Color(0.6, 0.48, 0.34)
				"ridges":
					c = Color(0.52, 0.5, 0.47)
				"basin":
					c = Color(0.2, 0.17, 0.24)
			var shade := clampf(nrm.dot(light), 0.0, 1.0) * 0.7 + 0.45
			if hab != "water":
				c = c * shade
				if int(h) % 10 == 0 and fmod(h, 10.0) < 0.6:
					c = c.darkened(0.15)
			img.set_pixel(x, y, c)
	return img


func _marks() -> void:
	var s := map_rect.size
	var f := UIStyle.bold()
	var to := func(p: Vector3) -> Vector2:
		return Vector2((p.x + Terrain.HALF) / Terrain.SIZE * s.x, (p.z + Terrain.HALF) / Terrain.SIZE * s.y)
	var regions := {"FIELDS": Vector3(-100, 0, 420), "DEAD FOREST": Vector3(-560, 0, -50), "BADLANDS": Vector3(560, 0, 260), "THE RIDGES": Vector3(-100, 0, -700), "MARSH": Vector3(-560, 0, 700), "CRASH BASIN": Vector3(560, 0, -420), "LAKE": Vector3(-560, 0, 470)}
	for k in regions.keys():
		var p: Vector2 = to.call(regions[k])
		map_rect.draw_string(f, p - Vector2(80, 0), k, HORIZONTAL_ALIGNMENT_CENTER, 160, 15, Color(1, 0.95, 0.85, 0.75))
	var farm: Vector2 = to.call(Vector3(Terrain.FARM.x, 0, Terrain.FARM.y))
	map_rect.draw_circle(farm, 7, Color(1.0, 0.8, 0.4))
	map_rect.draw_string(f, farm + Vector2(10, 5), "YOUR FARM", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.85, 0.5))
	for pod in world.structures.pods:
		var pp: Vector2 = to.call(pod)
		map_rect.draw_circle(pp, 5, UIStyle.TEAL)
	var ms: Vector2 = to.call(world.structures.mothership)
	map_rect.draw_circle(ms, 9, Color(0.4, 1.0, 0.85, 0.8))
	map_rect.draw_string(f, ms + Vector2(12, 5), "MOTHERSHIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIStyle.TEAL)
	var now := Time.get_ticks_msec() / 1000.0
	for c in world.creatures:
		var cr := c as Creature
		if is_instance_valid(cr) and not cr.dead and cr.tagged_until > now:
			map_rect.draw_circle(to.call(cr.global_position), 3, Color(0.5, 1.0, 0.8))
		elif is_instance_valid(cr) and cr.dead and not (cr.harvested_hide and cr.harvested_horn):
			map_rect.draw_circle(to.call(cr.global_position), 4, Color(1.0, 0.3, 0.3))
	var p: Player = world.player
	var pp2: Vector2 = to.call(p.global_position)
	var fwd := -p.global_transform.basis.z
	var d := Vector2(fwd.x, fwd.z).normalized()
	map_rect.draw_colored_polygon(PackedVector2Array([pp2 + d * 12, pp2 + d.orthogonal() * 6 - d * 5, pp2 - d.orthogonal() * 6 - d * 5]), Color(1, 1, 1))
	map_rect.draw_string(f, Vector2(8, s.y - 10), "teal: escape pods (salvage)   red: carcasses you haven't harvested", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.BONE)
