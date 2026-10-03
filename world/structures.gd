class_name Structures
extends Node3D
## What people built and what fell out of the sky. Your farm: the house
## (with the trophy room), the barn, the silo, the windmill, the dead field.
## Burned-out homesteads, a dirt road and power poles. And the Visitors'
## wreckage: the mothership broken across the crash basin, and the escape
## pods scattered over the valley, still worth salvaging.

var terrain: Terrain
var world: Node
var mats: Dictionary = {}
var kits: Dictionary = {}
var body: StaticBody3D
var farm_spawn := Vector3.ZERO
var farm_yaw := 0.0
var radio_pos := Vector3.ZERO
var bed_pos := Vector3.ZERO
var wall_root: Node3D
var wall_slots: Array = [] # [Transform3D]
var pods: Array = [] # Vector3
var windmill: Node3D
var mothership := Vector3.ZERO
var avoid: Array = [] # Vector3(x, z, r): keep trees off these
var camps: Array = [] # [name, Vector3]


func setup(w: Node, t: Terrain) -> void:
	world = w
	terrain = t
	var wood := StandardMaterial3D.new()
	wood.vertex_color_use_as_albedo = true
	wood.albedo_texture = Tex.get_tex("wood")
	wood.roughness = 0.85
	wood.uv1_triplanar = true
	wood.uv1_scale = Vector3(0.5, 0.5, 0.5)
	var metal := StandardMaterial3D.new()
	metal.vertex_color_use_as_albedo = true
	metal.albedo_texture = Tex.get_tex("rust")
	metal.metallic = 0.6
	metal.roughness = 0.7
	metal.uv1_triplanar = true
	metal.uv1_scale = Vector3(0.4, 0.4, 0.4)
	var stone := StandardMaterial3D.new()
	stone.vertex_color_use_as_albedo = true
	stone.albedo_texture = Tex.get_tex("detail")
	stone.roughness = 0.9
	stone.uv1_triplanar = true
	stone.uv1_scale = Vector3(0.3, 0.3, 0.3)
	var hull := ShaderMaterial.new()
	hull.shader = load("res://shaders/hull.gdshader")
	hull.set_shader_parameter("detail", Tex.get_tex("detail"))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.1, 0.12, 0.13, 0.6)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic = 0.4
	var lamp := StandardMaterial3D.new()
	lamp.vertex_color_use_as_albedo = true
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.75, 0.4)
	lamp.emission_energy_multiplier = 3.0
	mats = {"wood": wood, "metal": metal, "stone": stone, "hull": hull, "glass": glass, "lamp": lamp}
	for k in mats.keys():
		kits[k] = MeshKit.new()
	body = StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)


func build_all(sd: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd + 500
	_farm()
	_mothership(rng)
	_pods(rng)
	_ruins(rng)
	_road()
	_camps()
	_commit()


func _commit() -> void:
	for k in kits.keys():
		var mk: MeshKit = kits[k]
		if mk.empty():
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mk.commit()
		mi.material_override = mats[k]
		add_child(mi)
		mk.clear()


## A solid box: mesh and collision.
func solid(kit: String, c: Vector3, size: Vector3, col: Color, b: Basis = Basis.IDENTITY, collide: bool = true) -> void:
	(kits[kit] as MeshKit).box(c, size, col, b)
	if collide:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.transform = Transform3D(b, c)
		body.add_child(cs)


func ground(x: float, z: float, r: float) -> float:
	var h := INF
	for d in [Vector2(0, 0), Vector2(r, r), Vector2(-r, r), Vector2(r, -r), Vector2(-r, -r)]:
		h = minf(h, terrain.height_at(x + d.x, z + d.y))
	return h


# ---------------------------------------------------------------- the farm

func _farm() -> void:
	var f := Terrain.FARM
	var y := ground(f.x, f.y, 8.0)
	avoid.append(Vector3(f.x, f.y, 75.0))
	_house(Vector3(f.x, y, f.y))
	_barn(Vector3(f.x + 30.0, ground(f.x + 30.0, f.y - 8.0, 10.0), f.y - 8.0))
	_silo(Vector3(f.x + 48.0, ground(f.x + 48.0, f.y - 22.0, 4.0), f.y - 22.0))
	_windmill(Vector3(f.x - 22.0, ground(f.x - 22.0, f.y - 16.0, 2.0), f.y - 16.0))
	_field(Vector2(f.x - 10.0, f.y + 40.0), Vector2(70.0, 40.0))
	_fence_ring(f, 62.0)
	_truck(Vector3(f.x + 14.0, terrain.height_at(f.x + 14.0, f.y + 14.0), f.y + 14.0), 0.6)
	_tractor(Vector3(f.x + 40.0, terrain.height_at(f.x + 40.0, f.y + 10.0), f.y + 10.0))


func _house(o: Vector3) -> void:
	var W := 12.0
	var D := 9.0
	var H := 3.3
	var siding := Color(0.62, 0.58, 0.5)
	var trim := Color(0.85, 0.82, 0.74)
	var floor_y := o.y + 0.6
	# Foundation down into the ground.
	solid("stone", Vector3(o.x, o.y - 0.7, o.z), Vector3(W + 0.4, 2.6, D + 0.4), Color(0.45, 0.43, 0.4))
	solid("wood", Vector3(o.x, floor_y - 0.05, o.z), Vector3(W, 0.1, D), Color(0.5, 0.38, 0.27))
	var t := 0.18
	var front := o.z + D * 0.5
	var back := o.z - D * 0.5
	# Back wall (the trophy wall), side walls with windows, front with the door.
	solid("wood", Vector3(o.x, floor_y + H * 0.5, back), Vector3(W, H, t), siding)
	for s: float in [-1.0, 1.0]:
		var x: float = o.x + s * W * 0.5
		solid("wood", Vector3(x, floor_y + H * 0.5, o.z - D * 0.3), Vector3(t, H, D * 0.4), siding)
		solid("wood", Vector3(x, floor_y + H * 0.5, o.z + D * 0.4), Vector3(t, H, D * 0.2), siding)
		solid("wood", Vector3(x, floor_y + 0.45, o.z + D * 0.1), Vector3(t, 0.9, D * 0.4), siding)
		solid("wood", Vector3(x, floor_y + H - 0.4, o.z + D * 0.1), Vector3(t, 0.8, D * 0.4), siding)
		(kits["glass"] as MeshKit).box(Vector3(x, floor_y + 1.5, o.z + D * 0.1), Vector3(0.04, 1.3, D * 0.4), Color.WHITE)
	var door_w := 1.4
	var seg := (W - door_w) * 0.5
	solid("wood", Vector3(o.x - door_w * 0.5 - seg * 0.5, floor_y + H * 0.5, front), Vector3(seg, H, t), siding)
	solid("wood", Vector3(o.x + door_w * 0.5 + seg * 0.5, floor_y + H * 0.5, front), Vector3(seg, H, t), siding)
	solid("wood", Vector3(o.x, floor_y + H - 0.5, front), Vector3(door_w, 1.0, t), siding)
	# Trim.
	for s: float in [-1.0, 1.0]:
		solid("wood", Vector3(o.x + s * (door_w * 0.5 + 0.06), floor_y + (H - 1.0) * 0.5, front + 0.1), Vector3(0.1, H - 1.0, 0.06), trim, Basis.IDENTITY, false)
	# Ceiling and the gable roof.
	solid("wood", Vector3(o.x, floor_y + H, o.z), Vector3(W, 0.12, D), Color(0.55, 0.5, 0.42))
	var pitch := 0.55
	var rl := D * 0.5 / cos(pitch) + 0.6
	for s: float in [-1.0, 1.0]:
		var b := Basis(Vector3.RIGHT, -pitch * s)
		var c := Vector3(o.x, floor_y + H + sin(pitch) * rl * 0.5 - 0.1, o.z + s * D * 0.25)
		solid("metal", c, Vector3(W + 0.8, 0.08, rl), Color(0.42, 0.3, 0.24), b)
	# Gable ends.
	for zz in [front, back]:
		var k: MeshKit = kits["wood"]
		var ridge_y := floor_y + H + tan(pitch) * D * 0.5
		k.quad(Vector3(o.x - W * 0.5, floor_y + H, zz), Vector3(o.x + W * 0.5, floor_y + H, zz), Vector3(o.x, ridge_y, zz), Vector3(o.x, ridge_y, zz), siding, true)
	# Porch.
	var py := floor_y - 0.1
	solid("wood", Vector3(o.x, py, front + 1.6), Vector3(W, 0.15, 3.0), Color(0.45, 0.34, 0.24))
	for s: float in [-1.0, -0.33, 0.33, 1.0]:
		solid("wood", Vector3(o.x + s * (W * 0.5 - 0.15), py + 1.5, front + 2.9), Vector3(0.15, 3.0, 0.15), trim)
	solid("metal", Vector3(o.x, py + 3.05, front + 1.6), Vector3(W + 0.4, 0.08, 3.4), Color(0.4, 0.3, 0.24), Basis(Vector3.RIGHT, 0.1))
	solid("wood", Vector3(o.x, py - 0.4, front + 3.4), Vector3(2.0, 0.2, 0.6), Color(0.4, 0.3, 0.22))
	# The trade radio on a table by the door.
	var rp := Vector3(o.x + 3.0, py + 0.08, front + 1.4)
	solid("wood", rp + Vector3(0, 0.45, 0), Vector3(1.4, 0.06, 0.7), Color(0.4, 0.28, 0.18))
	for dx: float in [-0.6, 0.6]:
		for dz: float in [-0.28, 0.28]:
			solid("wood", rp + Vector3(dx, 0.22, dz), Vector3(0.06, 0.44, 0.06), Color(0.35, 0.25, 0.16), Basis.IDENTITY, false)
	solid("metal", rp + Vector3(0, 0.66, 0), Vector3(0.7, 0.36, 0.35), Color(0.2, 0.22, 0.2))
	(kits["lamp"] as MeshKit).box(rp + Vector3(-0.15, 0.7, 0.18), Vector3(0.25, 0.1, 0.01), Color(0.4, 1.0, 0.5))
	(kits["metal"] as MeshKit).cyl(rp + Vector3(0.25, 0.84, 0), rp + Vector3(0.3, 1.8, 0), 0.01, 0.005, 4, Color(0.3, 0.3, 0.3))
	radio_pos = rp + Vector3(0, 0.7, 0)
	Interactable.make(world, radio_pos, "Trade radio: buy, sell, contracts", func(_p: Node) -> void: world.open_shop())
	# Inside: bed, table, stove, lamp, rug.
	var ip := Vector3(o.x, floor_y, o.z)
	solid("wood", ip + Vector3(-4.2, 0.3, -2.6), Vector3(2.0, 0.6, 1.4), Color(0.45, 0.33, 0.22))
	(kits["wood"] as MeshKit).box(ip + Vector3(-4.2, 0.65, -2.6), Vector3(1.9, 0.12, 1.3), Color(0.55, 0.5, 0.42))
	bed_pos = ip + Vector3(-4.2, 0.8, -2.6)
	Interactable.make(world, bed_pos, "Sleep (and save)", func(_p: Node) -> void: world.sleep(), 2.2)
	solid("wood", ip + Vector3(2.5, 0.75, 0.5), Vector3(1.8, 0.06, 1.0), Color(0.42, 0.3, 0.2))
	for dx: float in [-0.8, 0.8]:
		for dz: float in [-0.42, 0.42]:
			solid("wood", ip + Vector3(2.5 + dx, 0.37, 0.5 + dz), Vector3(0.07, 0.74, 0.07), Color(0.36, 0.25, 0.16), Basis.IDENTITY, false)
	solid("metal", ip + Vector3(5.2, 0.5, -3.4), Vector3(0.9, 1.0, 0.8), Color(0.15, 0.15, 0.15))
	(kits["metal"] as MeshKit).cyl(ip + Vector3(5.2, 1.0, -3.4), ip + Vector3(5.2, H + 1.5, -3.4), 0.1, 0.1, 8, Color(0.15, 0.15, 0.15))
	(kits["wood"] as MeshKit).box(ip + Vector3(0, 0.02, 0.5), Vector3(4.0, 0.02, 2.6), Color(0.45, 0.15, 0.1))
	var lt := OmniLight3D.new()
	lt.light_color = Color(1.0, 0.75, 0.45)
	lt.light_energy = 2.2
	lt.omni_range = 9.0
	lt.shadow_enabled = true
	add_child(lt)
	lt.global_position = ip + Vector3(2.5, 1.2, 0.5)
	(kits["lamp"] as MeshKit).blob(ip + Vector3(2.5, 0.95, 0.5), Vector3(0.12, 0.16, 0.12), Color(1.0, 0.8, 0.5), 6, 8)
	var pl := OmniLight3D.new()
	pl.light_color = Color(1.0, 0.7, 0.4)
	pl.light_energy = 1.4
	pl.omni_range = 7.0
	add_child(pl)
	pl.global_position = Vector3(o.x, py + 2.7, front + 1.6)
	# The trophy wall: plaques along the back and side walls.
	wall_root = Node3D.new()
	wall_root.name = "TrophyWall"
	add_child(wall_root)
	for i in 5:
		var x := o.x - 4.4 + i * 2.2
		wall_slots.append(Transform3D(Basis.IDENTITY, Vector3(x, floor_y + 2.0, back + 0.15)))
	for s: float in [-1.0, 1.0]:
		for i in 2:
			var z := o.z - 2.4 + i * 2.0
			wall_slots.append(Transform3D(Basis(Vector3.UP, -s * PI * 0.5), Vector3(o.x + s * (W * 0.5 - 0.15), floor_y + 2.0, z)))
	Interactable.make(world, Vector3(o.x, floor_y + 1.6, back + 1.2), "Trophy wall: your best", func(_p: Node) -> void: world.open_trophies(), 3.5)
	farm_spawn = Vector3(o.x, py + 0.2, front + 2.0)
	farm_yaw = 0.0


## Mount the best horns on the wall: the actual horns, regrown from their seed.
func refresh_wall() -> void:
	for c in wall_root.get_children():
		c.queue_free()
	var plaque := StandardMaterial3D.new()
	plaque.albedo_texture = Tex.get_tex("wood")
	plaque.albedo_color = Color(0.45, 0.28, 0.16)
	plaque.roughness = 0.35
	var n := mini(Game.wall.size(), wall_slots.size())
	for i in n:
		var t: Dictionary = Game.wall[i]
		var xf: Transform3D = wall_slots[i]
		var holder := Node3D.new()
		wall_root.add_child(holder)
		holder.global_transform = xf
		var board := MeshInstance3D.new()
		var bm := MeshKit.new()
		bm.blob(Vector3.ZERO, Vector3(0.38, 0.48, 0.05), Color.WHITE, 6, 12)
		board.mesh = bm.commit()
		board.material_override = plaque
		holder.add_child(board)
		var sp: Dictionary = Catalog.SPECIES[t["species"]]
		var hd := float(sp["body"]["head"])
		var hk := Horns.build(t["horn"] if t.has("horn") else {"kind": sp["horn"], "size": 1.0, "seed": 1, "tines": 4, "twist": 0.0, "spread": 1.0}, hd, sp["glow"])
		var hm := MeshInstance3D.new()
		hm.mesh = hk.commit()
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/horn.gdshader")
		mat.set_shader_parameter("glow_col", sp["glow"])
		mat.set_shader_parameter("mounted", 1.0)
		mat.set_shader_parameter("alive", 0.0)
		mat.set_shader_parameter("detail", Tex.get_tex("detail"))
		hm.material_override = mat
		var fit := 0.8 / maxf(0.4, float(sp["horn_len"]) * float((t["horn"] as Dictionary).get("size", 1.0)) if t.has("horn") else 1.0)
		hm.scale = Vector3.ONE * clampf(fit, 0.25, 1.0)
		hm.position = Vector3(0, -0.1, 0.25)
		hm.rotation.y = PI
		holder.add_child(hm)
		var lb := Label3D.new()
		lb.text = "%s\n%.1f  %s" % [sp["name"], float(t["score"]), t["class"]]
		lb.font_size = 22
		lb.pixel_size = 0.0025
		lb.modulate = Catalog.class_color(t["class"])
		lb.position = Vector3(0, -0.62, 0.08)
		lb.outline_size = 6
		holder.add_child(lb)


func _barn(o: Vector3) -> void:
	var W := 14.0
	var D := 18.0
	var H := 5.5
	var red := Color(0.48, 0.17, 0.12)
	solid("stone", Vector3(o.x, o.y - 0.8, o.z), Vector3(W + 0.3, 2.0, D + 0.3), Color(0.4, 0.38, 0.35))
	var t := 0.25
	for s: float in [-1.0, 1.0]:
		solid("wood", Vector3(o.x + s * W * 0.5, o.y + H * 0.5, o.z), Vector3(t, H, D), red)
	# Gable end walls with big door openings.
	for zs: float in [-1.0, 1.0]:
		var z: float = o.z + zs * D * 0.5
		solid("wood", Vector3(o.x - W * 0.35, o.y + H * 0.5, z), Vector3(W * 0.3, H, t), red)
		solid("wood", Vector3(o.x + W * 0.35, o.y + H * 0.5, z), Vector3(W * 0.3, H, t), red)
		solid("wood", Vector3(o.x, o.y + H - 0.6, z), Vector3(W * 0.4, 1.2, t), red)
		var k: MeshKit = kits["wood"]
		k.quad(Vector3(o.x - W * 0.5, o.y + H, z), Vector3(o.x + W * 0.5, o.y + H, z), Vector3(o.x, o.y + H + 4.0, z), Vector3(o.x, o.y + H + 4.0, z), red, true)
		# One door hangs open, one has fallen.
		solid("wood", Vector3(o.x + W * 0.2 + 0.1, o.y + 2.2, z + zs * 1.6), Vector3(0.12, 4.4, W * 0.2), red.darkened(0.2), Basis.IDENTITY, true)
	for s: float in [-1.0, 1.0]:
		var b := Basis(Vector3.FORWARD, s * 0.62)
		solid("metal", Vector3(o.x + s * W * 0.26, o.y + H + 2.05, o.z), Vector3(W * 0.6, 0.1, D + 1.0), Color(0.36, 0.26, 0.22), b)
	# Hay bales.
	for i in 6:
		var p := Vector3(o.x - W * 0.3 + (i % 3) * 1.4, o.y + 0.45 + (i / 3) * 0.9, o.z - D * 0.35)
		solid("wood", p, Vector3(1.3, 0.85, 0.9), Color(0.6, 0.52, 0.3))
	avoid.append(Vector3(o.x, o.z, 16.0))


func _silo(o: Vector3) -> void:
	var k: MeshKit = kits["metal"]
	k.cyl(Vector3(o.x, o.y - 1.0, o.z), Vector3(o.x, o.y + 14.0, o.z), 3.0, 3.0, 20, Color(0.55, 0.53, 0.5), false)
	k.blob(Vector3(o.x, o.y + 14.0, o.z), Vector3(3.05, 1.8, 3.05), Color(0.5, 0.48, 0.46), 8, 20)
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 3.0
	cy.height = 16.0
	cs.shape = cy
	cs.position = Vector3(o.x, o.y + 7.0, o.z)
	body.add_child(cs)
	avoid.append(Vector3(o.x, o.z, 5.0))


func _windmill(o: Vector3) -> void:
	var k: MeshKit = kits["metal"]
	var h := 12.0
	for a in 4:
		var ang := a * PI * 0.5 + PI * 0.25
		var foot := Vector3(cos(ang) * 1.6, -0.5, sin(ang) * 1.6)
		k.cyl(o + foot, o + Vector3(cos(ang) * 0.25, h, sin(ang) * 0.25), 0.06, 0.04, 5, Color(0.35, 0.33, 0.3))
	for y: float in [3.0, 6.0, 9.0]:
		var r := lerpf(1.6, 0.25, y / h)
		for a in 4:
			var a0 := a * PI * 0.5 + PI * 0.25
			var a1 := a0 + PI * 0.5
			k.cyl(o + Vector3(cos(a0) * r, y, sin(a0) * r), o + Vector3(cos(a1) * r, y, sin(a1) * r), 0.03, 0.03, 4, Color(0.35, 0.33, 0.3), false)
	windmill = Node3D.new()
	add_child(windmill)
	windmill.global_position = o + Vector3(0, h, -0.5)
	var bk := MeshKit.new()
	for b in 14:
		var a := TAU * b / 14.0
		var bd := Basis(Vector3.FORWARD, a)
		bk.box(bd * Vector3(0, 1.4, 0), Vector3(0.35, 2.0, 0.03), Color(0.6, 0.58, 0.55), bd * Basis(Vector3.UP, 0.4))
	bk.blob(Vector3.ZERO, Vector3.ONE * 0.25, Color(0.3, 0.3, 0.3), 5, 8)
	var mi := MeshInstance3D.new()
	mi.mesh = bk.commit()
	mi.material_override = mats["metal"]
	windmill.add_child(mi)
	var tail := MeshKit.new()
	tail.box(Vector3(0, 0, 1.4), Vector3(0.05, 0.9, 1.6), Color(0.55, 0.3, 0.25))
	var tm := MeshInstance3D.new()
	tm.mesh = tail.commit()
	tm.material_override = mats["metal"]
	windmill.add_child(tm)


func _process(dt: float) -> void:
	if windmill != null:
		var ws: float = world.atmo.wind_strength if world.get("atmo") != null else 0.5
		windmill.get_child(0).rotation.z += dt * (0.5 + ws * 3.0)


func _field(c: Vector2, size: Vector2) -> void:
	var k: MeshKit = kits["wood"]
	var rows := int(size.y / 1.6)
	for r in rows:
		var z := c.y - size.y * 0.5 + r * 1.6
		var x := c.x - size.x * 0.5
		while x < c.x + size.x * 0.5:
			var h := terrain.height_at(x, z)
			if fmod(x * 7.3 + z * 3.1, 3.0) > 0.4:
				k.cyl(Vector3(x, h - 0.1, z), Vector3(x + 0.05, h + 0.9, z + 0.05), 0.015, 0.008, 3, Color(0.42, 0.36, 0.2), false)
			x += 0.9


func _fence_ring(c: Vector2, r: float) -> void:
	var k: MeshKit = kits["wood"]
	var n := 64
	for i in n:
		if i in [16, 17]:
			continue # the gate
		if (i * 7) % 11 == 0:
			continue # broken
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(c.x + cos(a0) * r, 0, c.y + sin(a0) * r)
		var p1 := Vector3(c.x + cos(a1) * r, 0, c.y + sin(a1) * r)
		p0.y = terrain.height_at(p0.x, p0.z)
		p1.y = terrain.height_at(p1.x, p1.z)
		k.cyl(p0 + Vector3(0, -0.3, 0), p0 + Vector3(0, 1.3, 0), 0.07, 0.06, 5, Color(0.36, 0.3, 0.24))
		for y: float in [0.5, 1.0]:
			k.cyl(p0 + Vector3(0, y, 0), p1 + Vector3(0, y, 0), 0.03, 0.03, 4, Color(0.4, 0.33, 0.26), false)


func _truck(o: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var col := Color(0.32, 0.36, 0.38)
	solid("metal", o + b * Vector3(0, 0.95, 0), Vector3(2.0, 0.8, 5.2), col, b)
	solid("metal", o + b * Vector3(0, 1.75, 0.6), Vector3(1.9, 0.9, 1.6), col, b)
	(kits["glass"] as MeshKit).box(o + b * Vector3(0, 1.85, -0.25), Vector3(1.8, 0.6, 0.05), Color.WHITE, b * Basis(Vector3.RIGHT, 0.3))
	for wx: float in [-1.0, 1.0]:
		for wz: float in [-1.6, 1.7]:
			(kits["metal"] as MeshKit).cyl(o + b * Vector3(wx * 1.0, 0.42, wz), o + b * Vector3(wx * 0.75, 0.42, wz), 0.42, 0.42, 12, Color(0.1, 0.1, 0.1))


func _tractor(o: Vector3) -> void:
	var col := Color(0.4, 0.3, 0.12)
	solid("metal", o + Vector3(0, 1.1, 0), Vector3(1.2, 1.0, 3.0), col)
	solid("metal", o + Vector3(0, 2.1, 0.8), Vector3(1.4, 1.2, 1.2), col.darkened(0.2))
	(kits["metal"] as MeshKit).cyl(o + Vector3(0, 1.6, -1.0), o + Vector3(0, 3.2, -1.0), 0.07, 0.07, 6, Color(0.1, 0.1, 0.1))
	for s: float in [-1.0, 1.0]:
		(kits["metal"] as MeshKit).cyl(o + Vector3(s * 1.0, 0.9, 0.9), o + Vector3(s * 0.6, 0.9, 0.9), 0.9, 0.9, 14, Color(0.08, 0.08, 0.08))
		(kits["metal"] as MeshKit).cyl(o + Vector3(s * 0.85, 0.5, -1.2), o + Vector3(s * 0.55, 0.5, -1.2), 0.5, 0.5, 12, Color(0.08, 0.08, 0.08))


# ---------------------------------------------------------------- the Visitors

## The mothership: a broken hull longer than the farm, half buried in the
## basin it dug, ribs open to the sky, lights still pulsing.
func _mothership(rng: RandomNumberGenerator) -> void:
	var c := Terrain.BASIN
	var y := terrain.height_at(c.x, c.y)
	mothership = Vector3(c.x, y, c.y)
	avoid.append(Vector3(c.x, c.y, 170.0))
	var k: MeshKit = kits["hull"]
	var yaw := 0.7
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, 0.12) * Basis(Vector3.RIGHT, -0.08)
	var o := Vector3(c.x, y - 2.5, c.y)
	# Main hull: a flattened lofted spindle, broken in two.
	for half in 2:
		var pts := PackedVector3Array()
		var rad := PackedFloat32Array()
		var ry := PackedFloat32Array()
		var z0 := -110.0 if half == 0 else 12.0
		var z1 := -8.0 if half == 0 else 120.0
		for i in 12:
			var u := float(i) / 11.0
			var z := lerpf(z0, z1, u)
			var g := (z + 110.0) / 230.0
			pts.append(Vector3(0, 0, z))
			rad.append(42.0 * pow(sin(PI * clampf(g, 0.02, 0.98)), 0.6))
			ry.append(0.42)
		var hb := b if half == 0 else b * Basis(Vector3.UP, 0.18) * Basis(Vector3.RIGHT, 0.32)
		var part := MeshKit.new()
		part.tube(pts, rad, 24, Color(0.2, 0.2, 0.24), true, Vector3.UP, ry, func(i: int, a: float) -> float:
			return 1.0 + 0.04 * sin(a * 12.0) * float(i % 2))
		part.append_to(k, Transform3D(hb, o + (b * Vector3(6, 4, 4) if half == 1 else Vector3.ZERO)))
	# Ribs where the hull split.
	for i in 9:
		var z := -14.0 + i * 3.2
		var r := 36.0 * (1.0 - absf(i - 4.0) * 0.04)
		var pts2 := PackedVector3Array()
		var rad2 := PackedFloat32Array()
		for j in 9:
			var a := lerpf(0.15, PI - 0.15, float(j) / 8.0)
			pts2.append(Vector3(cos(a) * r, sin(a) * r * 0.42 + 1.0, z))
			rad2.append(1.2)
		var rk := MeshKit.new()
		rk.tube(pts2, rad2, 6, Color(0.16, 0.16, 0.2), true, Vector3.FORWARD)
		rk.append_to(k, Transform3D(b, o))
	# Fins and spires sticking out of the ground.
	for i in 6:
		var a := rng.randf() * TAU
		var d := rng.randf_range(60.0, 150.0)
		var p := Vector3(c.x + cos(a) * d, 0, c.y + sin(a) * d)
		p.y = terrain.height_at(p.x, p.z) - 2.0
		var tilt := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.2, 0.6))
		var fk := MeshKit.new()
		var L := rng.randf_range(14.0, 30.0)
		fk.tube(PackedVector3Array([Vector3.ZERO, Vector3(0, L * 0.6, 0.5), Vector3(0, L, 2.0)]), PackedFloat32Array([3.0, 1.8, 0.2]), 6, Color(0.18, 0.18, 0.22), true, Vector3.FORWARD, PackedFloat32Array([0.3, 0.3, 0.3]))
		fk.append_to(k, Transform3D(tilt, p))
		var cs2 := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2.0, L, 2.0)
		cs2.shape = bs
		cs2.transform = Transform3D(tilt, p + tilt * Vector3(0, L * 0.5, 0))
		body.add_child(cs2)
	# Collision for the hull: a few boxes along it.
	for i in 11:
		var z := -100.0 + i * 20.0
		var g := (z + 110.0) / 230.0
		var r := 42.0 * pow(sin(PI * clampf(g, 0.05, 0.95)), 0.6)
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(r * 1.7, r * 0.7, 20.0)
		cs.shape = bx
		cs.transform = Transform3D(b, o + b * Vector3(0, 0, z))
		body.add_child(cs)
	# Its lights.
	for i in 5:
		var lt := OmniLight3D.new()
		lt.light_color = Color(0.3, 1.0, 0.85)
		lt.light_energy = 4.0
		lt.omni_range = 40.0
		add_child(lt)
		lt.global_position = o + b * Vector3(rng.randf_range(-15, 15), 12.0, -90.0 + i * 45.0)


func _pods(rng: RandomNumberGenerator) -> void:
	for i in 7:
		var p := terrain.random_spot(rng)
		if p == Vector3.INF or Vector2(p.x, p.z).distance_to(Terrain.FARM) < 200.0:
			continue
		pods.append(p)
		avoid.append(Vector3(p.x, p.z, 14.0))
		var b := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.3, 0.9))
		var k: MeshKit = kits["hull"]
		var pk := MeshKit.new()
		pk.blob(Vector3.ZERO, Vector3(2.6, 1.6, 4.0), Color(0.2, 0.2, 0.24), 10, 16)
		pk.append_to(k, Transform3D(b, p + Vector3(0, 0.6, 0)))
		# The furrow it ploughed.
		var dir := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		for j in 10:
			var q := p - dir * (6.0 + j * 4.0)
			q.y = terrain.height_at(q.x, q.z) - 0.2
			(kits["stone"] as MeshKit).blob(q, Vector3(2.2, 0.5, 2.6), Color(0.2, 0.18, 0.17), 4, 8, 0.4, j)
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 2.6
		cs.shape = sh
		cs.position = p + Vector3(0, 0.6, 0)
		body.add_child(cs)
		var lt := OmniLight3D.new()
		lt.light_color = Color(0.3, 1.0, 0.85)
		lt.light_energy = 2.0
		lt.omni_range = 12.0
		add_child(lt)
		lt.global_position = p + Vector3(0, 3, 0)
		var idx := i
		var it := Interactable.make(world, p + Vector3(0, 1.4, 0), "Salvage the pod", func(_pl: Node) -> void: world.salvage(idx), 4.5)
		it.hold = 2.0


func _ruins(rng: RandomNumberGenerator) -> void:
	for i in 9:
		var p := terrain.random_spot(rng, "fields")
		if p == Vector3.INF:
			p = terrain.random_spot(rng)
		if p == Vector3.INF or Vector2(p.x, p.z).distance_to(Terrain.FARM) < 180.0:
			continue
		avoid.append(Vector3(p.x, p.z, 12.0))
		var y := ground(p.x, p.z, 5.0)
		var b := Basis(Vector3.UP, rng.randf() * TAU)
		var o := Vector3(p.x, y, p.z)
		var char_ := Color(0.18, 0.16, 0.14)
		solid("stone", o + b * Vector3(0, -0.3, 0), Vector3(9, 1.0, 7), Color(0.35, 0.33, 0.3), b)
		# Walls at different heights, as if burned down.
		solid("wood", o + b * Vector3(0, 1.2, -3.4), Vector3(9, rng.randf_range(1.0, 3.0), 0.2), char_, b)
		solid("wood", o + b * Vector3(-4.4, 0.9, 0), Vector3(0.2, rng.randf_range(0.6, 2.6), 7), char_, b)
		solid("stone", o + b * Vector3(3.5, 2.5, 2.0), Vector3(1.2, 5.5, 1.2), Color(0.4, 0.36, 0.33), b)
		for j in 5:
			var bp := o + b * Vector3(rng.randf_range(-4, 4), 0.2, rng.randf_range(-3, 3))
			solid("wood", bp, Vector3(rng.randf_range(1.5, 3.5), 0.18, 0.2), char_, b * Basis(Vector3.UP, rng.randf() * PI) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)), false)


## The dirt road out of the farm, east to the badlands and north to the ridges,
## with the power poles still standing beside it.
func _road() -> void:
	var path := [Terrain.FARM + Vector2(0, 75), Terrain.FARM + Vector2(140, 90), Vector2(150, 250), Vector2(400, 200), Vector2(700, 120)]
	var path2 := [Terrain.FARM + Vector2(-40, -70), Vector2(-150, 0), Vector2(-60, -250), Vector2(80, -420)]
	for pth in [path, path2]:
		var pts: Array = pth
		var k: MeshKit = kits["stone"]
		var pole := 0.0
		for s in pts.size() - 1:
			var a: Vector2 = pts[s]
			var bb: Vector2 = pts[s + 1]
			var n := int(a.distance_to(bb) / 4.0)
			for j in n:
				var u0 := float(j) / n
				var u1 := float(j + 1) / n
				var p0 := a.lerp(bb, u0)
				var p1 := a.lerp(bb, u1)
				var side := (p1 - p0).normalized().orthogonal() * 2.2
				var q := [p0 - side, p1 - side, p1 + side, p0 + side]
				var v := []
				for qq in q:
					var q2: Vector2 = qq
					v.append(Vector3(q2.x, terrain.height_at(q2.x, q2.y) + 0.06, q2.y))
				k.quad(v[0], v[1], v[2], v[3], Color(0.33, 0.28, 0.22))
				pole += 4.0
				if pole >= 40.0:
					pole = 0.0
					var pp := p0 + side * 2.2
					var ph := terrain.height_at(pp.x, pp.y)
					var lean := Vector3(randf_range(-0.1, 0.1), 1, randf_range(-0.1, 0.1)).normalized()
					var top := Vector3(pp.x, ph, pp.y) + lean * 8.0
					(kits["wood"] as MeshKit).cyl(Vector3(pp.x, ph - 0.5, pp.y), top, 0.14, 0.11, 6, Color(0.3, 0.24, 0.18))
					(kits["wood"] as MeshKit).box(top - lean * 0.5, Vector3(2.2, 0.12, 0.12), Color(0.3, 0.24, 0.18))


## Hunting camps: a tent, a fire, a flag on a pole. Find one and you can
## fast travel back to it from the map.
const CAMPS := [
	["Deadwood Camp", Vector2(-560, -120), "forest"],
	["Lakeside Camp", Vector2(-400, 620), "marsh"],
	["Mesa Camp", Vector2(560, 360), "scrub"],
	["Ridge Camp", Vector2(-80, -620), "ridges"],
	["Crater Rim Camp", Vector2(300, -260), "basin"],
	["South Fields Camp", Vector2(180, 560), "fields"],
]


func _camps() -> void:
	for c in CAMPS:
		var at: Vector2 = c[1]
		# Find flat ground near the planned spot.
		var best := Vector3(at.x, terrain.height_at(at.x, at.y), at.y)
		var bn := terrain.normal_at(at.x, at.y).y
		for i in 24:
			var a := float(i) / 24.0 * TAU
			var r := 8.0 + float(i % 3) * 14.0
			var q := Vector2(at.x + cos(a) * r, at.y + sin(a) * r)
			var n := terrain.normal_at(q.x, q.y).y
			if n > bn and terrain.height_at(q.x, q.y) > 1.0:
				bn = n
				best = Vector3(q.x, terrain.height_at(q.x, q.y), q.y)
		camps.append([c[0], best])
		avoid.append(Vector3(best.x, best.z, 12.0))
		var o := best
		# Tent: a ridge pole and two sloped canvas sides.
		var canvas := Color(0.45, 0.42, 0.3)
		var k: MeshKit = kits["wood"]
		for sd: float in [-1.0, 1.0]:
			k.quad(o + Vector3(-1.4 * sd, 0.0, -1.6), o + Vector3(-1.4 * sd, 0.0, 1.6), o + Vector3(0, 1.7, 1.6), o + Vector3(0, 1.7, -1.6), canvas, true)
		k.cyl(o + Vector3(0, 1.7, -1.8), o + Vector3(0, 1.7, 1.8), 0.03, 0.03, 5, Color(0.3, 0.24, 0.18))
		# Fire pit and logs.
		var fp := o + Vector3(3.0, 0, 1.0)
		for j in 7:
			var a2 := TAU * j / 7.0
			(kits["stone"] as MeshKit).blob(fp + Vector3(cos(a2) * 0.6, 0.08, sin(a2) * 0.6), Vector3(0.18, 0.12, 0.16), Color(0.3, 0.29, 0.27), 4, 6, 0.3, j)
		(kits["lamp"] as MeshKit).blob(fp + Vector3(0, 0.15, 0), Vector3(0.3, 0.2, 0.3), Color(1.0, 0.5, 0.15), 5, 7, 0.4, 3)
		var lt := OmniLight3D.new()
		lt.light_color = Color(1.0, 0.6, 0.25)
		lt.light_energy = 2.0
		lt.omni_range = 12.0
		add_child(lt)
		lt.global_position = fp + Vector3(0, 0.8, 0)
		k.cyl(o + Vector3(-2.5, 0, -2.0), o + Vector3(-2.5, 4.5, -2.0), 0.04, 0.03, 5, Color(0.3, 0.24, 0.18))
		k.quad(o + Vector3(-2.5, 4.4, -2.0), o + Vector3(-1.5, 4.2, -2.0), o + Vector3(-1.5, 3.7, -2.0), o + Vector3(-2.5, 3.8, -2.0), Color(0.7, 0.25, 0.1), true)
		var nm: String = c[0]
		Interactable.make(world, fp + Vector3(0, 0.6, 0), "Rest at %s: fast travel" % nm, func(_p: Node) -> void: world.open_travel(), 3.0)
