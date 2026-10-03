class_name Horns
extends RefCounted
## Grows a pair of horns. Every animal's are different: the seed shapes the
## curl, the tines, the twist; size scales them. The same seed always grows
## the same horns, so the pair on your wall is the pair you shot.
## Vertex colour alpha runs 0 at the base to 1 at the tip (the shader uses it
## for the colour shift and the glowing tips).

const TIP_GLOW := Vector2(1, 0) # UV2 tag for glowing beads


## Horn data for an individual: {kind, size, seed, tines, twist, spread, score}.
static func roll(species: String, rng: RandomNumberGenerator, body_size: float) -> Dictionary:
	var sp: Dictionary = Catalog.SPECIES[species]
	# Bigger, older animals grow disproportionately bigger horns.
	var hs := pow(body_size, 1.6) * rng.randf_range(0.88, 1.12)
	var d := {
		"kind": sp["horn"], "size": hs, "seed": rng.randi(),
		"tines": rng.randi_range(3, 6) + int((hs - 1.0) * 6.0),
		"twist": rng.randf_range(-0.3, 0.3), "spread": rng.randf_range(0.85, 1.2),
		"sym": rng.randf_range(0.9, 1.0),
	}
	d["tines"] = clampi(int(d["tines"]), 2, 9)
	var base := float(sp["horn_len"]) * 100.0
	var tine_bonus := 0.0
	if d["kind"] in ["antler", "palmate"]:
		tine_bonus = (float(d["tines"]) - 4.0) * 0.035
	d["score"] = snappedf(base * hs * (1.0 + tine_bonus) * float(d["sym"]) * float(d["spread"]) ** 0.3, 0.1)
	return d


## Both horns, as one mesh, around a head at the origin facing -Z.
## head: the head's size (m); glow: the species glow colour.
static func build(h: Dictionary, head: float, glow: Color, base_col: Color = Color(0.25, 0.2, 0.16)) -> MeshKit:
	var k := MeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(h["seed"])
	var size := float(h["size"])
	var kind: String = h["kind"]
	for side: float in [-1.0, 1.0]:
		var one := MeshKit.new()
		rng.seed = int(h["seed"]) # mirror image, near enough
		var asym := 1.0 if side > 0.0 else float(h.get("sym", 1.0))
		match kind:
			"sweep":
				_sweep(one, rng, size * asym, head, glow, base_col, h)
			"spiral":
				_spiral(one, rng, size * asym, head, glow, base_col, h)
			"antler":
				_antler(one, rng, size * asym, head, glow, base_col, h, false)
			"palmate":
				_antler(one, rng, size * asym, head, glow, base_col, h, true)
			"tusk":
				_tusk(one, rng, size * asym, head, glow, base_col, h)
			"crown":
				_crown(one, rng, size * asym, head, glow, base_col, h)
			"fang":
				_fang(one, rng, size * asym, head, glow, base_col)
		var xf := Transform3D.IDENTITY
		if side < 0.0:
			xf = Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3.ZERO)
			# Mirroring flips the winding: swap two indices per triangle.
			for i in range(0, one.idx.size(), 3):
				var t := one.idx[i + 1]
				one.idx[i + 1] = one.idx[i + 2]
				one.idx[i + 2] = t
		one.append_to(k, xf)
	return k


static func _cols(n: int, c: Color) -> Array:
	var out: Array = []
	for i in n:
		var cc := c
		cc.a = float(i) / float(n - 1)
		out.append(cc)
	return out


static func _ridges(rings: float, depth: float) -> Callable:
	return func(i: int, a: float) -> float:
		return 1.0 + sin(float(i) * rings) * depth


## Longhorn sweep: out from the skull, forward, up, and a twist at the tip.
static func _sweep(k: MeshKit, rng: RandomNumberGenerator, s: float, head: float, glow: Color, col: Color, h: Dictionary) -> void:
	var L := 1.2 * s * float(h["spread"])
	var base := Vector3(head * 0.32, head * 0.35, head * 0.05)
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	var n := 16
	var tw := float(h["twist"])
	for i in n:
		var u := float(i) / (n - 1)
		var x := base.x + L * u
		var y := base.y + L * (0.15 * u + 0.5 * u * u * u)
		var z := base.z - L * 0.35 * sin(u * PI * 0.8) + tw * u * u * L * 0.3
		# The curl at the end.
		var c := smoothstep(0.7, 1.0, u)
		x -= c * L * 0.12
		y += c * L * 0.1
		pts.append(Vector3(x, y, z))
		rad.append(0.11 * s * pow(1.0 - u, 0.7) + 0.006)
	k.tube(pts, rad, 10, _cols(n, col), true, Vector3.UP, PackedFloat32Array(), _ridges(4.0, 0.03))
	k.tag = TIP_GLOW
	k.blob(pts[n - 1], Vector3.ONE * 0.025 * s, glow, 5, 6)
	k.tag = Vector2.ZERO


## The ram's double spiral: up and back, round past the ear, forward again.
static func _spiral(k: MeshKit, rng: RandomNumberGenerator, s: float, head: float, glow: Color, col: Color, h: Dictionary) -> void:
	var turns := 1.15 + (s - 1.0) * 0.5
	var R0 := 0.07 * s
	var R1 := 0.24 * s * float(h["spread"])
	var base := Vector3(head * 0.22, head * 0.42, head * 0.05)
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	var n := 30
	for i in n:
		var u := float(i) / (n - 1)
		var th := u * turns * TAU
		var R := lerpf(R0, R1, u)
		# The coil turns in the y-z plane, drifting outward in x.
		var p := base + Vector3(u * 0.32 * s, sin(th) * R + R * 0.2, -cos(th) * R + R0 * 0.9 + 0.08 * s * u)
		pts.append(p)
		rad.append(0.1 * s * pow(1.0 - u, 0.6) + 0.008)
	k.tube(pts, rad, 10, _cols(n, col), true, Vector3.RIGHT, PackedFloat32Array(), _ridges(9.0, 0.06))
	k.tag = TIP_GLOW
	k.blob(pts[n - 1], Vector3.ONE * 0.02 * s, glow, 5, 6)
	k.tag = Vector2.ZERO


## Antlers: a main beam and tines off it. Palmate ones flatten into a palm
## with a fan of tines round its edge. Every tip ends in a glowing crystal.
static func _antler(k: MeshKit, rng: RandomNumberGenerator, s: float, head: float, glow: Color, col: Color, h: Dictionary, palm: bool) -> void:
	var L := (1.5 if palm else 0.85) * s * float(h["spread"])
	var base := Vector3(head * 0.2, head * 0.45, head * 0.1)
	var beam := PackedVector3Array()
	var rad := PackedFloat32Array()
	var n := 12
	var out := Vector3(0.7, 0.55, 0.25).normalized() if not palm else Vector3(1.0, 0.25, 0.1).normalized()
	var p := base
	for i in n:
		var u := float(i) / (n - 1)
		beam.append(p)
		rad.append((0.09 if palm else 0.05) * s * lerpf(1.0, 0.35, u) + 0.006)
		var bend := Vector3(-0.15, 0.05, -0.55) * u if not palm else Vector3(-0.05, 0.35, -0.2) * u
		p += (out + bend).normalized() * L / (n - 1)
	var ry := PackedFloat32Array()
	if palm:
		for i in n:
			ry.append(lerpf(1.0, 0.35, smoothstep(0.3, 0.7, float(i) / (n - 1))))
	k.tube(beam, rad, 8, _cols(n, col), true, Vector3.UP, ry)
	var tips: Array = [beam[n - 1]]
	var tines := int(h["tines"])
	# Brow tine, forward over the face.
	if not palm:
		var bt := beam[1]
		var tl := L * 0.35
		var bp := PackedVector3Array([bt, bt + Vector3(0.02, 0.06, -0.6).normalized() * tl * 0.5, bt + Vector3(0.0, 0.25, -1.0).normalized() * tl])
		k.tube(bp, PackedFloat32Array([rad[1] * 0.7, rad[1] * 0.5, 0.005]), 6, _cols(3, col), true)
		tips.append(bp[2])
	for t in tines:
		var u2 := lerpf(0.3, 0.92, float(t) / maxf(1.0, float(tines - 1)))
		var ip := int(u2 * (n - 1))
		var at := beam[ip]
		var dir := Vector3(rng.randf_range(-0.2, 0.3), 1.0, rng.randf_range(-0.4, 0.3)).normalized()
		if palm:
			# Fan out from the palm's edge.
			var fa := lerpf(-0.6, 1.1, float(t) / maxf(1.0, float(tines - 1)))
			dir = Vector3(sin(fa) * 0.6 + 0.3, cos(fa), -0.15).normalized()
		var tl2 := L * rng.randf_range(0.25, 0.42) * (1.15 if palm else 1.0)
		var mid := at + dir * tl2 * 0.55 + Vector3(0, 0, -0.05) * tl2
		var tip := at + dir * tl2 + Vector3(rng.randf_range(-0.04, 0.04), 0, -0.08 * tl2)
		k.tube(PackedVector3Array([at, mid, tip]), PackedFloat32Array([rad[ip] * 0.75, rad[ip] * 0.45, 0.004]), 6, _cols(3, col), true)
		tips.append(tip)
	k.tag = TIP_GLOW
	for tp in tips:
		var c: Vector3 = tp
		var cs := 0.035 * s if palm else 0.022 * s
		k.blob(c, Vector3(cs, cs * 1.6, cs), glow, 5, 6)
	k.tag = Vector2.ZERO


## Tusks curling up out of the jaw, and a ring of short horns on the skull.
static func _tusk(k: MeshKit, rng: RandomNumberGenerator, s: float, head: float, glow: Color, col: Color, h: Dictionary) -> void:
	var base := Vector3(head * 0.18, -head * 0.12, -head * 0.55)
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	var n := 12
	var L := 0.6 * s
	for i in n:
		var u := float(i) / (n - 1)
		var th := u * PI * 0.95
		pts.append(base + Vector3(0.08 * L * u, sin(th) * L * 0.45, -cos(th) * L * 0.25 + L * 0.25 - u * 0.05))
		rad.append(0.06 * s * (1.0 - u * 0.9) + 0.004)
	var ivory := Color(0.85, 0.8, 0.68)
	k.tube(pts, rad, 8, _cols(n, ivory), true)
	# The crown.
	for c in 3:
		var a := 0.3 + c * 0.45
		var b := Vector3(sin(a) * head * 0.3, head * 0.38, cos(a) * head * 0.15 + head * 0.05)
		var l := (0.18 + rng.randf() * 0.08) * s
		var tip := b + Vector3(sin(a) * 0.4, 1.0, 0.25).normalized() * l
		k.tube(PackedVector3Array([b, b.lerp(tip, 0.6) + Vector3(0, 0, 0.02), tip]), PackedFloat32Array([0.035 * s, 0.022 * s, 0.003]), 6, _cols(3, col), true)
		k.tag = TIP_GLOW
		k.blob(tip, Vector3.ONE * 0.012 * s, glow, 4, 5)
		k.tag = Vector2.ZERO


## Ironcrown: girder horns out, up and in like a bison's, and spikes along the boss.
static func _crown(k: MeshKit, rng: RandomNumberGenerator, s: float, head: float, glow: Color, col: Color, h: Dictionary) -> void:
	var L := 2.0 * s * float(h["spread"])
	var base := Vector3(head * 0.38, head * 0.3, 0.0)
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	var n := 18
	for i in n:
		var u := float(i) / (n - 1)
		var x := base.x + L * 0.55 * sin(u * PI * 0.65)
		var y := base.y + L * 0.6 * (u * u)
		var z := base.z - L * 0.25 * sin(u * PI)
		x -= smoothstep(0.6, 1.0, u) * L * 0.2
		pts.append(Vector3(x, y, z))
		rad.append(0.2 * s * pow(1.0 - u, 0.65) + 0.01)
	k.tube(pts, rad, 12, _cols(n, col), true, Vector3.UP, PackedFloat32Array(), _ridges(5.0, 0.05))
	for c in 4:
		var b := Vector3(head * (0.05 + c * 0.08), head * 0.48, head * (0.1 - c * 0.1))
		var tip := b + Vector3(0.15, 1.0, 0.3).normalized() * (0.3 + c * 0.05) * s
		k.tube(PackedVector3Array([b, tip]), PackedFloat32Array([0.06 * s, 0.004]), 6, _cols(2, col), true)
		k.tag = TIP_GLOW
		k.blob(tip, Vector3.ONE * 0.03 * s, glow, 4, 6)
		k.tag = Vector2.ZERO
	k.tag = TIP_GLOW
	k.blob(pts[n - 1], Vector3.ONE * 0.05 * s, glow, 5, 6)
	k.tag = Vector2.ZERO


static func _fang(k: MeshKit, rng: RandomNumberGenerator, s: float, head: float, glow: Color, col: Color) -> void:
	var b := Vector3(head * 0.1, -head * 0.15, -head * 0.62)
	var L := 0.16 * s
	var pts := PackedVector3Array([b, b + Vector3(0, -L * 0.5, -L * 0.1), b + Vector3(0, -L, 0.03)])
	k.tube(pts, PackedFloat32Array([0.018 * s, 0.012 * s, 0.002]), 6, _cols(3, Color(0.92, 0.9, 0.84)), true)
