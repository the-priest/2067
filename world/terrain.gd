class_name Terrain
extends Node3D
## The valley: 2 km of ash-grey farmland, dead forest, badlands and ridges,
## with a lake in the south-west and the crash basin in the north-east where
## the mothership came down. One heightfield (2 m cells) feeds the mesh, the
## collision and every system that asks "how high is the ground here".
## The mesh streams in chunks at three detail levels, with skirts so the
## seams between levels never show a crack.

const SIZE := 2048.0
const N := 1025 # samples per side
const CELL := SIZE / float(N - 1)
const HALF := SIZE * 0.5
const CHUNK := 64 # cells per chunk side
const CHUNKS := (N - 1) / CHUNK
const WATER := 0.0

## Places the generator shapes the land around.
const FARM := Vector2(-120.0, 260.0)
const LAKE := Vector2(-560.0, 470.0)
const BASIN := Vector2(560.0, -170.0)
const RIDGE_Z := -380.0

var heights := PackedFloat32Array()
var biome := PackedColorArray() # r corruption, g moisture, b ash, a rock
var material: ShaderMaterial
var _chunks: Dictionary = {} # Vector2i -> {lv, nodes:[MeshInstance3D x3], built:[bool x3]}
var _queue: Array = []
var lod0 := 220.0
var lod1 := 560.0


func generate(sd: int) -> void:
	var t0 := Time.get_ticks_msec()
	_heights(sd)
	_biomes(sd)
	print("TERRAIN heights %d ms" % (Time.get_ticks_msec() - t0))


# ------------------------------------------------------------ heights

static func world_to_grid(x: float, z: float) -> Vector2:
	return Vector2((x + HALF) / CELL, (z + HALF) / CELL)


func _heights(sd: int) -> void:
	var base := FastNoiseLite.new()
	base.seed = sd
	base.frequency = 0.0016
	base.fractal_octaves = 5
	var ridge := FastNoiseLite.new()
	ridge.seed = sd + 1
	ridge.frequency = 0.0024
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 5
	var warp := FastNoiseLite.new()
	warp.seed = sd + 2
	warp.frequency = 0.001
	var hills := FastNoiseLite.new()
	hills.seed = sd + 3
	hills.frequency = 0.005
	hills.fractal_octaves = 3
	var M := 513
	var step := SIZE / float(M - 1)
	var a := PackedFloat32Array()
	a.resize(M * M)
	for iz in M:
		for ix in M:
			var x := -HALF + ix * step
			var z := -HALF + iz * step
			a[iz * M + ix] = _macro(x, z, base, ridge, warp, hills)
	var img := Image.create_from_data(M, M, false, Image.FORMAT_RF, a.to_byte_array())
	img.resize(N, N, Image.INTERPOLATE_CUBIC)
	heights = img.get_data().to_float32_array()
	# Fine relief: a few metres of bumps, more on rock.
	var fine := FastNoiseLite.new()
	fine.seed = sd + 4
	fine.frequency = 0.03
	fine.fractal_octaves = 3
	for iz in N:
		for ix in N:
			var i := iz * N + ix
			var h := heights[i]
			var x := -HALF + ix * CELL
			var z := -HALF + iz * CELL
			var amp := 0.5 + clampf((h - 30.0) / 60.0, 0.0, 1.0) * 2.5
			# Keep the farmyard flat enough to build on.
			var fd := Vector2(x, z).distance_to(FARM)
			if fd < 90.0:
				amp *= smoothstep(40.0, 90.0, fd)
			heights[i] = h + fine.get_noise_2d(x, z) * amp


## The big shapes: rolling farmland, the northern ridges, the lake basin, the
## crash crater, and mountains walling the valley in on every side.
func _macro(x: float, z: float, base: FastNoiseLite, ridge: FastNoiseLite, warp: FastNoiseLite, hills: FastNoiseLite) -> float:
	var wx := x + warp.get_noise_2d(x, z) * 120.0
	var wz := z + warp.get_noise_2d(z + 500.0, x) * 120.0
	var h := 14.0 + base.get_noise_2d(wx, wz) * 22.0 + hills.get_noise_2d(wx, wz) * 6.0
	# Northern ridges: ridged mountains rising past RIDGE_Z.
	var north := smoothstep(RIDGE_Z + 150.0, RIDGE_Z - 250.0, z) * smoothstep(150.0, 330.0, Vector2(x, z).distance_to(BASIN))
	h += north * (40.0 + (ridge.get_noise_2d(wx, wz) * 0.5 + 0.5) * 120.0)
	# Eastern badlands: mesas.
	var east := smoothstep(250.0, 600.0, x) * (1.0 - north) * smoothstep(200.0, 320.0, Vector2(x, z).distance_to(BASIN))
	var mesa := clampf(base.get_noise_2d(wx * 2.0, wz * 2.0) * 3.0, -1.0, 1.0)
	h += east * (smoothstep(0.1, 0.35, mesa) * 26.0 - 4.0)
	# The lake.
	var ld := Vector2(x, z).distance_to(LAKE) + warp.get_noise_2d(x * 3.0, z * 3.0) * 60.0
	h = lerpf(h, -7.0, smoothstep(260.0, 110.0, ld))
	# Marsh around it: low, flat, wet.
	h = lerpf(h, 1.2 + hills.get_noise_2d(x * 2.0, z * 2.0) * 1.5, smoothstep(380.0, 230.0, ld) * (1.0 - smoothstep(230.0, 110.0, ld)) * 0.8)
	# The crash basin: a bowl with a raised rim, ploughed out by the ship.
	var bd := Vector2(x, z).distance_to(BASIN)
	var rim := exp(-pow((bd - 260.0) / 50.0, 2.0)) * 24.0
	var bowl := smoothstep(260.0, 60.0, bd) * 30.0
	h += rim - bowl
	# The farm sits on a gentle flat.
	var fd := Vector2(x, z).distance_to(FARM)
	h = lerpf(h, 11.0, smoothstep(140.0, 50.0, fd))
	# Mountains all round the edge.
	var edge := maxf(absf(x), absf(z))
	h += smoothstep(HALF - 260.0, HALF - 20.0, edge) * (110.0 + ridge.get_noise_2d(wx * 1.5, wz * 1.5) * 60.0)
	return h


func _biomes(sd: int) -> void:
	var n := FastNoiseLite.new()
	n.seed = sd + 9
	n.frequency = 0.004
	n.fractal_octaves = 3
	biome.resize(N * N)
	for iz in N:
		for ix in N:
			var x := -HALF + ix * CELL
			var z := -HALF + iz * CELL
			var nn := n.get_noise_2d(x, z)
			var bd := Vector2(x, z).distance_to(BASIN)
			var corrupt := clampf(smoothstep(420.0, 120.0, bd) + maxf(0.0, nn - 0.45) * 2.0, 0.0, 1.0)
			var ld := Vector2(x, z).distance_to(LAKE)
			var wet := clampf(smoothstep(420.0, 200.0, ld) + smoothstep(-200.0, -650.0, x) * 0.5 * (nn * 0.5 + 0.5), 0.0, 1.0)
			var ash := clampf(0.35 + nn * 0.5 + smoothstep(200.0, 600.0, x) * 0.3, 0.0, 1.0)
			biome[iz * N + ix] = Color(corrupt, wet, ash, 0.0)


func height_at(x: float, z: float) -> float:
	var g := world_to_grid(x, z)
	var gx := clampf(g.x, 0.0, N - 1.001)
	var gz := clampf(g.y, 0.0, N - 1.001)
	var ix := int(gx)
	var iz := int(gz)
	var fx := gx - ix
	var fz := gz - iz
	var i := iz * N + ix
	var h00 := heights[i]
	var h10 := heights[i + 1]
	var h01 := heights[i + N]
	var h11 := heights[i + N + 1]
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)


func normal_at(x: float, z: float) -> Vector3:
	var e := CELL
	var hl := height_at(x - e, z)
	var hr := height_at(x + e, z)
	var hd := height_at(x, z - e)
	var hu := height_at(x, z + e)
	return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()


func biome_at(x: float, z: float) -> Color:
	var g := world_to_grid(x, z)
	var ix := clampi(int(round(g.x)), 0, N - 1)
	var iz := clampi(int(round(g.y)), 0, N - 1)
	return biome[iz * N + ix]


## Which habitat a spot belongs to (where each hybrid lives).
func habitat_at(x: float, z: float) -> String:
	var h := height_at(x, z)
	if h < WATER + 0.3:
		return "water"
	if Vector2(x, z).distance_to(BASIN) < 230.0:
		return "basin"
	var b := biome_at(x, z)
	var slope := 1.0 - normal_at(x, z).y
	if z < RIDGE_Z - 60.0 or h > 70.0 or slope > 0.3:
		return "ridges"
	if b.g > 0.55:
		return "marsh"
	if x > 260.0:
		return "scrub"
	if x < -250.0 or b.g > 0.35:
		return "forest"
	return "fields"


func in_bounds(x: float, z: float, margin: float = 120.0) -> bool:
	return absf(x) < HALF - margin and absf(z) < HALF - margin


# ------------------------------------------------------------ collision

func build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = N
	hs.map_depth = N
	hs.map_data = heights
	cs.shape = hs
	cs.scale = Vector3(CELL, 1.0, CELL)
	body.add_child(cs)
	add_child(body)


# ------------------------------------------------------------ mesh

func build_material(tex: Dictionary) -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/terrain.gdshader")
	for k in tex.keys():
		material.set_shader_parameter(k, tex[k])


## Every chunk starts at the coarsest level so the whole valley is there
## from the first frame; nearer chunks refine as you move.
func build_all_coarse() -> void:
	for cz in CHUNKS:
		for cx in CHUNKS:
			var k := Vector2i(cx, cz)
			_chunks[k] = {"lv": 2, "nodes": [null, null, null]}
			_show(k, 2)


func update_lod(center: Vector3, budget: int = 2) -> void:
	var built := 0
	var wants: Array = []
	for k in _chunks.keys():
		var c: Dictionary = _chunks[k]
		var cc := _chunk_center(k)
		var d := Vector2(cc.x - center.x, cc.y - center.z).length() - CHUNK * CELL * 0.5
		var lv := 2
		if d < lod0:
			lv = 0
		elif d < lod1:
			lv = 1
		if lv != int(c["lv"]):
			wants.append([d, k, lv])
	wants.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for w in wants:
		if built >= budget:
			break
		var k: Vector2i = w[1]
		var lv: int = w[2]
		var c: Dictionary = _chunks[k]
		if (c["nodes"] as Array)[lv] == null:
			built += 1
		_show(k, lv)


func build_lod_now(center: Vector3) -> void:
	update_lod(center, 100000)


func _chunk_center(k: Vector2i) -> Vector2:
	return Vector2(-HALF + (k.x + 0.5) * CHUNK * CELL, -HALF + (k.y + 0.5) * CHUNK * CELL)


func _show(k: Vector2i, lv: int) -> void:
	var c: Dictionary = _chunks[k]
	var nodes: Array = c["nodes"]
	if nodes[lv] == null:
		var mi := MeshInstance3D.new()
		mi.mesh = _chunk_mesh(k, [1, 2, 8][lv])
		mi.material_override = material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lv < 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		nodes[lv] = mi
	for i in 3:
		if nodes[i] != null:
			(nodes[i] as MeshInstance3D).visible = i == lv
	# Free the finest level once it's far away again.
	if lv == 2 and nodes[0] != null:
		(nodes[0] as Node).queue_free()
		nodes[0] = null
	c["lv"] = lv


func _chunk_mesh(k: Vector2i, step: int) -> ArrayMesh:
	var n := CHUNK / step + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var gx0 := k.x * CHUNK
	var gz0 := k.y * CHUNK
	verts.resize(n * n)
	norms.resize(n * n)
	cols.resize(n * n)
	uvs.resize(n * n)
	for j in n:
		for i in n:
			var gx := gx0 + i * step
			var gz := gz0 + j * step
			var v := j * n + i
			var gi := gz * N + gx
			var x := -HALF + gx * CELL
			var z := -HALF + gz * CELL
			verts[v] = Vector3(x, heights[gi], z)
			norms[v] = _grid_normal(gx, gz)
			cols[v] = biome[gi]
			uvs[v] = Vector2(x, z)
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			idx.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	# Skirts: a short wall down from every edge hides cracks between levels.
	var drop := 2.0 * step
	var edges := []
	for i in n:
		edges.append(i)
	var e2 := []
	for i in n:
		e2.append((n - 1) * n + (n - 1 - i))
	var e3 := []
	for j in n:
		e3.append(j * n + n - 1)
	var e4 := []
	for j in n:
		e4.append((n - 1 - j) * n)
	for ring in [edges, e3, e2, e4]:
		var r: Array = ring
		var start := verts.size()
		for vi in r:
			verts.append(verts[int(vi)] - Vector3(0, drop, 0))
			norms.append(norms[int(vi)])
			cols.append(cols[int(vi)])
			uvs.append(uvs[int(vi)])
		for m in r.size() - 1:
			var a := int(r[m])
			var b := int(r[m + 1])
			var c2 := start + m
			var d := start + m + 1
			idx.append_array([a, c2, b, b, c2, d])
			idx.append_array([a, b, c2, b, d, c2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func _grid_normal(gx: int, gz: int) -> Vector3:
	var l := heights[gz * N + maxi(gx - 1, 0)]
	var r := heights[gz * N + mini(gx + 1, N - 1)]
	var d := heights[maxi(gz - 1, 0) * N + gx]
	var u := heights[mini(gz + 1, N - 1) * N + gx]
	return Vector3(l - r, 2.0 * CELL, d - u).normalized()


## A spot of open ground, optionally in one habitat (tries a few times).
func random_spot(rng: RandomNumberGenerator, habitat: String = "", tries: int = 40) -> Vector3:
	for i in tries:
		var x := rng.randf_range(-HALF + 160.0, HALF - 160.0)
		var z := rng.randf_range(-HALF + 160.0, HALF - 160.0)
		var h := height_at(x, z)
		if h < WATER + 0.5:
			continue
		if habitat != "" and habitat != "any" and habitat_at(x, z) != habitat:
			continue
		return Vector3(x, h, z)
	return Vector3.INF
