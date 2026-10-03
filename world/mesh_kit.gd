class_name MeshKit
extends RefCounted
## Builds meshes out of code: tubes and lofts along curves (trees, horns,
## creature bodies), boxes, rocks, cylinders. Vertex colour carries the base
## colour; UV runs along (x) and around (y) every tube for the shaders.

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var uvs := PackedVector2Array()
var uv2s := PackedVector2Array()
var idx := PackedInt32Array()
var tag := Vector2.ZERO # written to UV2 for everything added


func clear() -> void:
	verts.clear()
	norms.clear()
	cols.clear()
	uvs.clear()
	uv2s.clear()
	idx.clear()


func empty() -> bool:
	return verts.is_empty()


func _v(p: Vector3, n: Vector3, c: Color, uv: Vector2) -> int:
	verts.append(p)
	norms.append(n)
	cols.append(c)
	uvs.append(uv)
	uv2s.append(tag)
	return verts.size() - 1


## Frames along a path (parallel transport), so tubes don't twist.
static func frames(path: PackedVector3Array, up_hint: Vector3 = Vector3.UP) -> Array:
	var out: Array = []
	var n := path.size()
	var prev_n := Vector3.ZERO
	for i in n:
		var t: Vector3
		if i == 0:
			t = path[1] - path[0]
		elif i == n - 1:
			t = path[n - 1] - path[n - 2]
		else:
			t = path[i + 1] - path[i - 1]
		t = t.normalized()
		var nn: Vector3
		if i == 0:
			nn = up_hint - t * up_hint.dot(t)
			if nn.length() < 0.01:
				nn = Vector3.RIGHT - t * t.x
			nn = nn.normalized()
		else:
			nn = (prev_n - t * prev_n.dot(t)).normalized()
		var b := t.cross(nn).normalized()
		out.append([t, nn, b])
		prev_n = nn
	return out


## A tube along a path. radii per point; rx/ry scales give an elliptical
## section (ry along the frame normal). shape(i, a) can bump the radius.
func tube(path: PackedVector3Array, radii: PackedFloat32Array, sides: int, col: Variant, cap: bool = true, up_hint: Vector3 = Vector3.UP, ry_scale: PackedFloat32Array = PackedFloat32Array(), bump: Callable = Callable()) -> void:
	var n := path.size()
	if n < 2:
		return
	var fr := frames(path, up_hint)
	var base := verts.size()
	var length := 0.0
	for i in n:
		if i > 0:
			length += path[i].distance_to(path[i - 1])
		var f: Array = fr[i]
		var nn: Vector3 = f[1]
		var bb: Vector3 = f[2]
		var r := radii[i]
		var ry := r * (ry_scale[i] if ry_scale.size() == n else 1.0)
		var c: Color = col[i] if col is Array else col
		for s in sides + 1:
			var a := TAU * float(s) / float(sides)
			var rr := r
			var rry := ry
			if bump.is_valid():
				var k: float = bump.call(i, a)
				rr *= k
				rry *= k
			var off := nn * cos(a) * rry + bb * sin(a) * rr
			var nrm := (nn * cos(a) / maxf(rry, 0.001) + bb * sin(a) / maxf(rr, 0.001)).normalized()
			_v(path[i] + off, nrm, c, Vector2(length, float(s) / float(sides)))
	for i in n - 1:
		for s in sides:
			var a0 := base + i * (sides + 1) + s
			var a1 := a0 + sides + 1
			idx.append_array([a0, a1, a0 + 1, a0 + 1, a1, a1 + 1])
	if cap:
		var tip := path[n - 1]
		var f2: Array = fr[n - 1]
		var cc: Color = col[n - 1] if col is Array else col
		var ti := _v(tip + (f2[0] as Vector3) * radii[n - 1] * 0.5, f2[0], cc, Vector2(length, 0.5))
		var ring0 := base + (n - 1) * (sides + 1)
		for s in sides:
			idx.append_array([ring0 + s, ti, ring0 + s + 1])
		var f0: Array = fr[0]
		var c0: Color = col[0] if col is Array else col
		var bi := _v(path[0] - (f0[0] as Vector3) * radii[0] * 0.3, -(f0[0] as Vector3), c0, Vector2(0, 0.5))
		for s in sides:
			idx.append_array([base + s + 1, bi, base + s])


func box(c: Vector3, size: Vector3, col: Color, b: Basis = Basis.IDENTITY) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
		[Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)],
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
		[Vector3(0, -1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)],
		[Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)],
		[Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var ctr := n * h
		var su := absf(u.dot(h))
		var sv := absf(v.dot(h))
		var i0 := verts.size()
		var corners := [ctr - u * su - v * sv, ctr - u * su + v * sv, ctr + u * su + v * sv, ctr + u * su - v * sv]
		var uvc := [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]
		for k in 4:
			var p: Vector3 = corners[k]
			_v(c + b * p, (b * n).normalized(), col, (uvc[k] as Vector2) * Vector2(su * 2.0, sv * 2.0))
		# Wind so the front face is counter-clockwise from outside.
		if (corners[1] - corners[0]).cross(corners[2] - corners[0]).dot(n) > 0.0:
			idx.append_array([i0, i0 + 2, i0 + 1, i0, i0 + 3, i0 + 2])
		else:
			idx.append_array([i0, i0 + 1, i0 + 2, i0, i0 + 2, i0 + 3])


func cyl(a: Vector3, b: Vector3, r1: float, r2: float, sides: int, col: Color, cap: bool = true) -> void:
	var p := PackedVector3Array([a, b])
	var r := PackedFloat32Array([r1, r2])
	var up := Vector3.UP if absf((b - a).normalized().y) < 0.95 else Vector3.RIGHT
	tube(p, r, sides, col, cap, up)


## A lumpy sphere: rocks, bulbs, eyes. noise 0 gives a clean ellipsoid.
func blob(c: Vector3, scale: Vector3, col: Color, rings: int = 8, segs: int = 12, noise: float = 0.0, sd: int = 0, b: Basis = Basis.IDENTITY) -> void:
	var base := verts.size()
	var fn: FastNoiseLite = null
	if noise > 0.0:
		fn = FastNoiseLite.new()
		fn.seed = sd
		fn.frequency = 1.6
		fn.fractal_octaves = 3
	for r in rings + 1:
		var th := PI * float(r) / float(rings)
		for s in segs + 1:
			var ph := TAU * float(s) / float(segs)
			var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			var k := 1.0
			if fn != null:
				k += fn.get_noise_3dv(d * 1.3) * noise
			_v(c + b * (d * scale * k), (b * (d / scale)).normalized(), col, Vector2(float(s) / segs, float(r) / rings))
	for r in rings:
		for s in segs:
			var a0 := base + r * (segs + 1) + s
			var a1 := a0 + segs + 1
			idx.append_array([a0, a1, a0 + 1, a0 + 1, a1, a1 + 1])


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, two_sided: bool = false) -> void:
	var n := (b - a).cross(c - a).normalized()
	var i0 := _v(a, n, col, Vector2(0, 1))
	_v(b, n, col, Vector2(1, 1))
	_v(c, n, col, Vector2(1, 0))
	_v(d, n, col, Vector2(0, 0))
	idx.append_array([i0, i0 + 2, i0 + 1, i0, i0 + 3, i0 + 2])
	if two_sided:
		var j0 := _v(a, -n, col, Vector2(0, 1))
		_v(b, -n, col, Vector2(1, 1))
		_v(c, -n, col, Vector2(1, 0))
		_v(d, -n, col, Vector2(0, 0))
		idx.append_array([j0, j0 + 1, j0 + 2, j0, j0 + 2, j0 + 3])


## Recompute smooth normals from the triangles (for welded-looking blobs).
func smooth_normals() -> void:
	var acc := PackedVector3Array()
	acc.resize(verts.size())
	for i in range(0, idx.size(), 3):
		var a := idx[i]
		var b := idx[i + 1]
		var c := idx[i + 2]
		var n := (verts[b] - verts[a]).cross(verts[c] - verts[a])
		acc[a] += n
		acc[b] += n
		acc[c] += n
	for i in acc.size():
		if acc[i].length() > 0.0:
			norms[i] = -acc[i].normalized()


func commit(m: ArrayMesh = null) -> ArrayMesh:
	var mesh := m if m != null else ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_TEX_UV2] = uv2s
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## Make a transformed copy of everything into another kit.
func append_to(o: MeshKit, xf: Transform3D) -> void:
	var base := o.verts.size()
	for i in verts.size():
		o.verts.append(xf * verts[i])
		o.norms.append((xf.basis * norms[i]).normalized())
		o.cols.append(cols[i])
		o.uvs.append(uvs[i])
		o.uv2s.append(uv2s[i])
	for i in idx:
		o.idx.append(base + i)
