class_name Flora
extends Node3D
## What grows (or grew) in the valley: dead oaks and snags, scrub, reeds by
## the lake, rocks and boulders, and in the crash basin the Visitors' own
## growths: twisted trees with glowing bulbs, and crystal spires.
## Trees and rocks are placed once for the whole map in 256 m patches (one
## MultiMesh per kind per patch, so the GPU draws them in batches), with
## collision on every trunk. Grass streams around the player.

const PATCH := 256.0
const GRASS_CELL := 20.0

var terrain: Terrain
var mat: ShaderMaterial
var grass_mat: ShaderMaterial
var kinds: Dictionary = {} # name -> {mesh, r (trunk radius), h}
var obstacles: Dictionary = {} # Vector2i(16 m) -> Array of Vector3(x, z, r)
var _grass_cells: Dictionary = {}
var _grass_meshes: Dictionary = {}
var grass_density := 1.0
var grass_radius := 70.0
var tree_count := 0


func setup(t: Terrain) -> void:
	terrain = t
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/flora.gdshader")
	mat.set_shader_parameter("bark", Tex.get_tex("bark"))
	mat.set_shader_parameter("bark_n", Tex.get_tex("bark_n"))
	mat.set_shader_parameter("detail", Tex.get_tex("detail"))
	grass_mat = ShaderMaterial.new()
	grass_mat.shader = load("res://shaders/grass.gdshader")
	var q := Settings.q()
	grass_density = float(q["grass"])
	grass_radius = float(q["grass_r"])
	grass_mat.set_shader_parameter("fade_dist", grass_radius)
	_make_kinds()
	_make_grass_meshes()


# ---------------------------------------------------------------- meshes

func _make_kinds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 4:
		kinds["oak%d" % i] = _dead_oak(rng)
	for i in 3:
		kinds["snag%d" % i] = _snag(rng)
	for i in 3:
		kinds["alien%d" % i] = _alien_tree(rng)
	for i in 3:
		kinds["bush%d" % i] = _bush(rng)
	for i in 4:
		kinds["rock%d" % i] = _rock(rng, i)
	for i in 2:
		kinds["crystal%d" % i] = _crystal(rng)
	for i in 2:
		kinds["reed%d" % i] = _reeds(rng)


func _branch(k: MeshKit, rng: RandomNumberGenerator, start: Vector3, dir: Vector3, length: float, r: float, depth: int, col: Color) -> void:
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	var p := start
	var d := dir.normalized()
	var segs := 5
	for s in segs + 1:
		var u := float(s) / segs
		pts.append(p)
		rad.append(r * lerpf(1.0, 0.25, u))
		d = (d + Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.1, 0.25), rng.randf_range(-0.35, 0.35))).normalized()
		p += d * length / segs
	k.tube(pts, rad, maxi(3, 7 - depth * 2), col, true)
	if depth >= 3:
		return
	var nb := rng.randi_range(2, 3 if depth == 0 else 3)
	for b in nb:
		var at := rng.randf_range(0.45, 0.95)
		var ip := int(at * segs)
		var bp := pts[ip]
		var side := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 0.9), rng.randf_range(-1, 1)).normalized()
		_branch(k, rng, bp, (dir * 0.4 + side).normalized(), length * rng.randf_range(0.45, 0.65), rad[ip] * 0.65, depth + 1, col)


func _dead_oak(rng: RandomNumberGenerator) -> Dictionary:
	var k := MeshKit.new()
	var col := Color(0.24, 0.21, 0.19).lerp(Color(0.33, 0.3, 0.27), rng.randf())
	var h := rng.randf_range(6.0, 10.0)
	var r := rng.randf_range(0.28, 0.45)
	# Trunk, flared at the root.
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	var p := Vector3(0, -0.6, 0)
	var lean := Vector3(rng.randf_range(-0.15, 0.15), 1.0, rng.randf_range(-0.15, 0.15)).normalized()
	for s in 7:
		var u := float(s) / 6.0
		pts.append(p)
		rad.append(r * (1.0 + 0.8 * pow(1.0 - u, 6.0)) * lerpf(1.0, 0.55, u))
		p += (lean + Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))) * h * 0.6 / 6.0
	k.tube(pts, rad, 9, col, true)
	var top := pts[6]
	for b in rng.randi_range(3, 5):
		var side := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.5, 1.1), rng.randf_range(-1, 1)).normalized()
		var from := pts[rng.randi_range(3, 6)]
		_branch(k, rng, from, side, h * rng.randf_range(0.35, 0.55), r * 0.55, 1, col)
	_branch(k, rng, top, lean, h * 0.4, r * 0.5, 1, col)
	return {"mesh": k.commit(), "r": r * 1.1, "h": h}


func _snag(rng: RandomNumberGenerator) -> Dictionary:
	var k := MeshKit.new()
	var col := Color(0.2, 0.18, 0.16).lerp(Color(0.3, 0.27, 0.24), rng.randf())
	var h := rng.randf_range(9.0, 16.0)
	var r := rng.randf_range(0.18, 0.3)
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	for s in 6:
		var u := float(s) / 5.0
		pts.append(Vector3(rng.randf_range(-0.08, 0.08) * u * h * 0.1, -0.5 + u * h, 0))
		rad.append(r * lerpf(1.2, 0.12, u))
	k.tube(pts, rad, 7, col, true)
	# Stubs of dead branches, angled down.
	var n := rng.randi_range(10, 18)
	for i in n:
		var y := rng.randf_range(h * 0.3, h * 0.92)
		var a := rng.randf() * TAU
		var l := lerpf(1.8, 0.4, (y / h)) * rng.randf_range(0.6, 1.2)
		var d := Vector3(cos(a), rng.randf_range(-0.5, -0.1), sin(a)).normalized()
		var b := Vector3(0, y, 0)
		k.cyl(b, b + d * l, r * 0.25, 0.02, 4, col, false)
	return {"mesh": k.commit(), "r": r * 1.1, "h": h}


func _alien_tree(rng: RandomNumberGenerator) -> Dictionary:
	var k := MeshKit.new()
	var col := Color(0.12, 0.1, 0.14)
	var glow := [Color(0.25, 1.0, 0.85), Color(0.7, 0.35, 1.0), Color(0.4, 0.8, 1.0)][rng.randi() % 3] as Color
	var h := rng.randf_range(5.0, 9.0)
	var r := rng.randf_range(0.25, 0.4)
	# Twisted trunk of braided strands.
	for strand in 3:
		var pts := PackedVector3Array()
		var rad := PackedFloat32Array()
		for s in 9:
			var u := float(s) / 8.0
			var a := u * TAU * 0.8 + strand * TAU / 3.0
			pts.append(Vector3(cos(a) * r * 0.6 * (1.0 - u * 0.4), -0.5 + u * h, sin(a) * r * 0.6 * (1.0 - u * 0.4)))
			rad.append(r * 0.5 * lerpf(1.2, 0.35, u))
		k.tube(pts, rad, 6, col, true)
	# Drooping tendrils ending in glowing bulbs.
	for t in rng.randi_range(5, 8):
		var a2 := rng.randf() * TAU
		var start := Vector3(0, h * rng.randf_range(0.7, 1.0), 0)
		var pts2 := PackedVector3Array()
		var rad2 := PackedFloat32Array()
		var reach := rng.randf_range(1.5, 3.0)
		for s in 7:
			var u2 := float(s) / 6.0
			pts2.append(start + Vector3(cos(a2) * reach * u2, sin(u2 * PI) * 1.0 - u2 * u2 * 2.2, sin(a2) * reach * u2))
			rad2.append(r * 0.25 * lerpf(1.0, 0.3, u2))
		k.tube(pts2, rad2, 5, col, false)
		k.tag = Vector2(1, 0)
		k.blob(pts2[6], Vector3.ONE * rng.randf_range(0.18, 0.35), glow, 6, 8, 0.2, t)
		k.tag = Vector2(0, 0)
	k.tag = Vector2(1, 0)
	k.blob(Vector3(0, h, 0), Vector3(0.6, 0.45, 0.6) * rng.randf_range(0.8, 1.3), glow, 8, 10, 0.3, 5)
	k.tag = Vector2.ZERO
	return {"mesh": k.commit(), "r": r * 1.2, "h": h}


func _bush(rng: RandomNumberGenerator) -> Dictionary:
	var k := MeshKit.new()
	var col := Color(0.3, 0.26, 0.18).lerp(Color(0.38, 0.33, 0.2), rng.randf())
	for i in rng.randi_range(9, 14):
		var a := rng.randf() * TAU
		var d := Vector3(cos(a) * rng.randf_range(0.3, 1.0), rng.randf_range(0.6, 1.2), sin(a) * rng.randf_range(0.3, 1.0)).normalized()
		var l := rng.randf_range(0.7, 1.5)
		var mid := d * l * 0.5 + Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1))
		k.tube(PackedVector3Array([Vector3(0, -0.1, 0), mid, d * l]), PackedFloat32Array([0.04, 0.025, 0.008]), 3, col, false)
		for t in 3:
			var tp := mid + (d * l - mid) * rng.randf()
			var td := Vector3(rng.randf_range(-1, 1), rng.randf_range(0, 1), rng.randf_range(-1, 1)).normalized()
			k.cyl(tp, tp + td * rng.randf_range(0.2, 0.45), 0.012, 0.003, 3, col, false)
	return {"mesh": k.commit(), "r": 0.0, "h": 1.2}


func _rock(rng: RandomNumberGenerator, i: int) -> Dictionary:
	var k := MeshKit.new()
	k.tag = Vector2(2, 0)
	var s := [Vector3(1.0, 0.7, 0.9), Vector3(2.2, 1.4, 1.8), Vector3(0.5, 0.35, 0.45), Vector3(3.5, 2.6, 3.0)][i] as Vector3
	var col := Color(0.26, 0.25, 0.23).lerp(Color(0.36, 0.33, 0.3), rng.randf())
	k.blob(Vector3(0, s.y * 0.25, 0), s, col, 10, 14, 0.38, rng.randi())
	k.smooth_normals()
	return {"mesh": k.commit(), "r": minf(s.x, s.z) * 0.85, "h": s.y, "rock": true}


func _crystal(rng: RandomNumberGenerator) -> Dictionary:
	var k := MeshKit.new()
	k.tag = Vector2(3, 0)
	var col := [Color(0.3, 0.9, 1.0), Color(0.8, 0.4, 1.0)][rng.randi() % 2] as Color
	for i in rng.randi_range(5, 9):
		var a := rng.randf() * TAU
		var tilt := rng.randf_range(0.0, 0.6)
		var d := Vector3(cos(a) * tilt, 1.0, sin(a) * tilt).normalized()
		var l := rng.randf_range(1.0, 4.5)
		var r := l * rng.randf_range(0.1, 0.16)
		var b := Vector3(cos(a) * 0.3, -0.3, sin(a) * 0.3)
		k.tube(PackedVector3Array([b, b + d * l * 0.85, b + d * l]), PackedFloat32Array([r, r * 0.9, 0.01]), 6, col, false)
	return {"mesh": k.commit(), "r": 0.8, "h": 3.0}


func _reeds(rng: RandomNumberGenerator) -> Dictionary:
	var k := MeshKit.new()
	var col := Color(0.32, 0.33, 0.2)
	for i in 40:
		var b := Vector3(rng.randf_range(-0.8, 0.8), -0.1, rng.randf_range(-0.8, 0.8))
		var h := rng.randf_range(1.0, 2.2)
		var lean := Vector3(rng.randf_range(-0.2, 0.2), 1, rng.randf_range(-0.2, 0.2)).normalized()
		k.cyl(b, b + lean * h, 0.015, 0.004, 3, col, false)
		if rng.randf() < 0.4:
			k.cyl(b + lean * h * 0.8, b + lean * h * 0.98, 0.03, 0.02, 4, Color(0.26, 0.18, 0.12), true)
	return {"mesh": k.commit(), "r": 0.0, "h": 2.0}


# ---------------------------------------------------------------- placing

## How dense each kind grows in each habitat (per 1000 m²).
const DENSITY := {
	"fields": {"oak": 0.12, "bush": 0.9, "rock": 0.3, "snag": 0.05},
	"forest": {"oak": 3.4, "snag": 2.0, "bush": 1.2, "rock": 0.6},
	"marsh": {"snag": 1.4, "reed": 6.0, "bush": 0.6, "oak": 0.25},
	"scrub": {"bush": 2.4, "rock": 1.6, "snag": 0.1},
	"ridges": {"snag": 1.1, "rock": 3.0, "bush": 0.4},
	"basin": {"alien": 1.5, "crystal": 1.0, "rock": 0.6},
	"water": {},
}


func place_all(sd: int, avoid: Array) -> void:
	var t0 := Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	rng.seed = sd + 100
	var tq := float(Settings.q()["trees"])
	var per_patch: Dictionary = {} # Vector2i -> kind -> Array[Transform3D]
	var bodies: Dictionary = {}
	# Jittered grid: one try per 10x10 m cell per pass, kept by density.
	var step := 10.0
	var count := int(Terrain.SIZE / step)
	for iz in count:
		for ix in count:
			var x := -Terrain.HALF + (ix + rng.randf()) * step
			var z := -Terrain.HALF + (iz + rng.randf()) * step
			if not terrain.in_bounds(x, z, 30.0):
				continue
			var hab := terrain.habitat_at(x, z)
			var dens: Dictionary = DENSITY.get(hab, {})
			if dens.is_empty():
				continue
			var blocked := false
			for a in avoid:
				var av: Vector3 = a # x, z, radius
				if Vector2(x - av.x, z - av.y).length() < av.z:
					blocked = true
					break
			if blocked:
				continue
			# Each family gets a roll; density per 1000 m² over a 100 m² cell.
			for fam in dens.keys():
				var p := float(dens[fam]) * 0.1 * (tq if fam in ["oak", "snag", "alien"] else 1.0)
				if rng.randf() >= p:
					continue
				var variants := 4 if fam in ["oak", "rock"] else (2 if fam in ["crystal", "reed"] else 3)
				var kind := "%s%d" % [fam, rng.randi() % variants]
				var h := terrain.height_at(x, z)
				if h < Terrain.WATER + (-0.4 if fam == "reed" else 0.4):
					continue
				var n := terrain.normal_at(x, z)
				if n.y < 0.8 and fam in ["oak", "alien", "reed", "bush"]:
					continue
				var sc := rng.randf_range(0.75, 1.3)
				var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc)
				if fam == "rock":
					b = Basis(n.cross(Vector3.RIGHT).normalized(), rng.randf() * TAU).slerp(Basis.IDENTITY, 0.6).scaled(Vector3.ONE * sc) * Basis(Vector3.UP, rng.randf() * TAU)
				var xf := Transform3D(b, Vector3(x, h, z))
				var pk := Vector2i(floori((x + Terrain.HALF) / PATCH), floori((z + Terrain.HALF) / PATCH))
				if not per_patch.has(pk):
					per_patch[pk] = {}
				var pp: Dictionary = per_patch[pk]
				if not pp.has(kind):
					pp[kind] = []
				(pp[kind] as Array).append(xf)
				var kd: Dictionary = kinds[kind]
				var r := float(kd["r"]) * sc
				if r > 0.05:
					if not bodies.has(pk):
						var sb := StaticBody3D.new()
						sb.collision_layer = 1
						sb.collision_mask = 0
						add_child(sb)
						bodies[pk] = sb
					var cs := CollisionShape3D.new()
					if kd.has("rock"):
						var sp := SphereShape3D.new()
						sp.radius = r
						cs.shape = sp
						cs.position = Vector3(x, h + float(kd["h"]) * 0.2 * sc, z)
					else:
						var cy := CylinderShape3D.new()
						cy.radius = r
						cy.height = minf(float(kd["h"]), 8.0) * sc
						cs.shape = cy
						cs.position = Vector3(x, h + cy.height * 0.5 - 0.5, z)
					(bodies[pk] as StaticBody3D).add_child(cs)
					var ok := Vector2i(floori(x / 16.0), floori(z / 16.0))
					if not obstacles.has(ok):
						obstacles[ok] = []
					(obstacles[ok] as Array).append(Vector3(x, z, r + 0.3))
				tree_count += 1
				break
	var view := float(Settings.q()["view"])
	for pk in per_patch.keys():
		var pp: Dictionary = per_patch[pk]
		for kind in pp.keys():
			var list: Array = pp[kind]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = kinds[kind]["mesh"]
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = mat
			var small: bool = kind.begins_with("bush") or kind.begins_with("reed") or kind == "rock2"
			mmi.visibility_range_end = (260.0 if small else view)
			mmi.visibility_range_end_margin = 30.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if small else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(mmi)
	print("FLORA %d placed in %d ms" % [tree_count, Time.get_ticks_msec() - t0])


## Trees and rocks near a point (for animals steering round them).
func obstacles_near(x: float, z: float) -> Array:
	var out: Array = []
	var cx := floori(x / 16.0)
	var cz := floori(z / 16.0)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var k := Vector2i(cx + dx, cz + dz)
			if obstacles.has(k):
				out.append_array(obstacles[k])
	return out


# ---------------------------------------------------------------- grass

func _make_grass_meshes() -> void:
	_grass_meshes["grass"] = _blades(9, 0.45, 0.9, 0.03)
	_grass_meshes["tall"] = _blades(12, 0.8, 1.4, 0.035)
	_grass_meshes["tendril"] = _blades(6, 0.5, 1.1, 0.04, true)


func _blades(n: int, hmin: float, hmax: float, w: float, curly: bool = false) -> ArrayMesh:
	var k := MeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = n * 13
	for i in n:
		var b := Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35))
		var a := rng.randf() * TAU
		var side := Vector3(cos(a), 0, sin(a))
		var lean := Vector3(rng.randf_range(-0.4, 0.4), 1.0, rng.randf_range(-0.4, 0.4)).normalized()
		var h := rng.randf_range(hmin, hmax)
		var segs := 3
		for s in segs:
			var u0 := float(s) / segs
			var u1 := float(s + 1) / segs
			var bend0 := lean * h * u0 + Vector3(lean.x, 0, lean.z) * u0 * u0 * h * 0.6
			var bend1 := lean * h * u1 + Vector3(lean.x, 0, lean.z) * u1 * u1 * h * 0.6
			if curly:
				bend1 += Vector3(cos(u1 * 6.0 + a), 0, sin(u1 * 6.0 + a)) * 0.12 * u1
				bend0 += Vector3(cos(u0 * 6.0 + a), 0, sin(u0 * 6.0 + a)) * 0.12 * u0
			var w0 := w * (1.0 - u0)
			var w1 := w * (1.0 - u1) + 0.002
			var p0 := b + bend0
			var p1 := b + bend1
			var i0 := k.verts.size()
			for pv in [[p0 - side * w0, u0], [p0 + side * w0, u0], [p1 + side * w1, u1], [p1 - side * w1, u1]]:
				var pos: Vector3 = pv[0]
				k.verts.append(pos)
				k.norms.append(Vector3.UP.lerp(side.cross(lean), 0.3).normalized())
				k.cols.append(Color.WHITE)
				k.uvs.append(Vector2(0, float(pv[1])))
				k.uv2s.append(Vector2.ZERO)
			k.idx.append_array([i0, i0 + 2, i0 + 1, i0, i0 + 3, i0 + 2])
	return k.commit()


func update_grass(center: Vector3) -> void:
	grass_mat.set_shader_parameter("player_pos", center)
	var cr := int(ceil(grass_radius / GRASS_CELL))
	var cx := floori(center.x / GRASS_CELL)
	var cz := floori(center.z / GRASS_CELL)
	var want: Dictionary = {}
	var built := 0
	for dz in range(-cr, cr + 1):
		for dx in range(-cr, cr + 1):
			var k := Vector2i(cx + dx, cz + dz)
			var cc := Vector2((k.x + 0.5) * GRASS_CELL, (k.y + 0.5) * GRASS_CELL)
			if cc.distance_to(Vector2(center.x, center.z)) > grass_radius + GRASS_CELL:
				continue
			want[k] = true
			if not _grass_cells.has(k) and built < 3:
				_grass_cells[k] = _grass_cell(k)
				built += 1
	for k in _grass_cells.keys():
		if not want.has(k):
			var n: Node = _grass_cells[k]
			if n != null:
				n.queue_free()
			_grass_cells.erase(k)


func _grass_cell(k: Vector2i) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(k)
	var lists := {"grass": [], "tall": [], "tendril": []}
	var n := int(260 * grass_density)
	for i in n:
		var x := (k.x + rng.randf()) * GRASS_CELL
		var z := (k.y + rng.randf()) * GRASS_CELL
		var h := terrain.height_at(x, z)
		if h < Terrain.WATER - 0.2:
			continue
		var nrm := terrain.normal_at(x, z)
		if nrm.y < 0.82:
			continue
		var b := terrain.biome_at(x, z)
		var kind := "grass"
		var col := Color(0.46, 0.43, 0.27).lerp(Color(0.58, 0.52, 0.33), rng.randf()).lerp(Color(0.36, 0.4, 0.22), rng.randf() * 0.5)
		if b.r > 0.45:
			if rng.randf() > 0.5:
				continue
			kind = "tendril"
			col = Color(0.25, 0.18, 0.3)
			col.a = 1.0
		else:
			col.a = 0.0
			if b.g > 0.5 or h < 1.2:
				kind = "tall"
				col = Color(0.38, 0.4, 0.22).lerp(Color(0.5, 0.48, 0.28), rng.randf())
				col.a = 0.0
			elif b.b > 0.75 and rng.randf() < 0.6:
				continue
			# Patches: bare ground between tussocks.
			if sin(x * 0.13 + cos(z * 0.11) * 2.0) + rng.randf() * 0.8 < -0.3:
				continue
		var sc := rng.randf_range(0.7, 1.3)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.2), sc)), Vector3(x, h - 0.05, z))
		(lists[kind] as Array).append([xf, col])
	var holder := Node3D.new()
	add_child(holder)
	for kind in lists.keys():
		var l: Array = lists[kind]
		if l.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = _grass_meshes[kind]
		mm.instance_count = l.size()
		for i in l.size():
			mm.set_instance_transform(i, l[i][0])
			mm.set_instance_custom_data(i, l[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = grass_mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mmi)
	return holder
