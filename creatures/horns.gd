class_name Horns
extends RefCounted
## Grows a pair of horns. The Visitors made them bigger and stranger than
## anything on an Earth animal, and no two sets are the same: the seed picks
## a style, the curl, the twist, the ribbing, the colour of the keratin, how
## many tines, whether glowing beads ring the horn, and in a rare mutant a
## second pair. Size scales it all. The same seed always grows the same
## horns, so the pair on your wall is the pair you shot.
## Vertex colour alpha runs 0 at the base to 1 at the tip (the shader shifts
## colour along it); UV2.x 1 marks the glowing beads.

const TIP_GLOW := Vector2(1, 0)
const ALIEN := 1.35 # how much bigger than an Earth animal's

const PALETTE := [
	Color(0.13, 0.1, 0.09), # ebony
	Color(0.32, 0.22, 0.14), # walnut
	Color(0.62, 0.56, 0.44), # bone
	Color(0.2, 0.22, 0.26), # slate
	Color(0.45, 0.28, 0.1), # amber
	Color(0.12, 0.2, 0.2), # verdigris
	Color(0.3, 0.12, 0.18), # wine
]


## Horn data for an individual.
static func roll(species: String, rng: RandomNumberGenerator, body_size: float) -> Dictionary:
	var sp: Dictionary = Catalog.SPECIES[species]
	var hs := pow(body_size, 1.6) * rng.randf_range(0.88, 1.15)
	var kind: String = sp["horn"]
	var c1: Color = PALETTE[rng.randi() % PALETTE.size()]
	var c2: Color = PALETTE[rng.randi() % PALETTE.size()]
	var d := {
		"kind": kind, "size": hs, "seed": rng.randi(),
		"style": rng.randi() % 3,
		"tines": clampi(rng.randi_range(4, 7) + int((hs - 1.0) * 8.0), 3, 11),
		"twist": rng.randf_range(-0.35, 0.35), "spread": rng.randf_range(0.85, 1.25),
		"curl": rng.randf_range(0.7, 1.4), "rise": rng.randf_range(-0.2, 0.5),
		"ridges": rng.randf_range(3.0, 12.0), "ridge_d": rng.randf_range(0.02, 0.08),
		"sym": rng.randf_range(0.9, 1.0),
		"col": c1.lerp(c2, rng.randf_range(0.0, 0.4)).to_html(false),
		"hue": rng.randf_range(-0.09, 0.09),
		"beads": rng.randf() < 0.45,
		"pairs": 2 if rng.randf() < 0.12 and kind in ["sweep", "spiral", "antler", "palmate", "ossicone"] else 1,
	}
	var base := float(sp["horn_len"]) * 100.0
	var bonus := 0.0
	if kind in ["antler", "palmate"]:
		bonus = (float(d["tines"]) - 5.0) * 0.04
	if int(d["pairs"]) == 2:
		bonus += 0.18
	d["score"] = snappedf(base * hs * (1.0 + bonus) * float(d["sym"]) * pow(float(d["spread"]), 0.3) * (0.92 + float(d["curl"]) * 0.08), 0.1)
	return d


static func glow_of(h: Dictionary, base: Color) -> Color:
	var c := base
	c.h = fposmod(c.h + float(h.get("hue", 0.0)), 1.0)
	return c


## Both horns (and a second pair if it has one), around a head at the origin
## facing -Z. head: the head's size (m).
static func build(h: Dictionary, head: float, glow: Color, base_col: Color = Color(0.25, 0.2, 0.16)) -> MeshKit:
	var k := MeshKit.new()
	var rng := RandomNumberGenerator.new()
	var size := float(h["size"]) * ALIEN
	var kind: String = h["kind"]
	if h.has("col"):
		base_col = Color.html(String(h["col"]))
	glow = glow_of(h, glow)
	var pairs := int(h.get("pairs", 1))
	for pair in pairs:
		var ps := size * (1.0 if pair == 0 else 0.55)
		var off := Transform3D.IDENTITY
		if pair == 1:
			# The mutant's second pair: lower, further back, swept the other way.
			off = Transform3D(Basis(Vector3.RIGHT, 0.7) * Basis(Vector3.UP, 0.35), Vector3(0, -head * 0.12, head * 0.18))
		for side: float in [-1.0, 1.0]:
			var one := MeshKit.new()
			rng.seed = int(h["seed"]) + pair * 7919
			var asym := 1.0 if side > 0.0 else float(h.get("sym", 1.0))
			match kind:
				"sweep":
					_sweep(one, rng, ps * asym, head, glow, base_col, h)
				"spiral":
					_spiral(one, rng, ps * asym, head, glow, base_col, h)
				"antler":
					_antler(one, rng, ps * asym, head, glow, base_col, h, false)
				"palmate":
					_antler(one, rng, ps * asym, head, glow, base_col, h, true)
				"tusk":
					_tusk(one, rng, ps * asym, head, glow, base_col, h)
				"crown":
					_crown(one, rng, ps * asym, head, glow, base_col, h)
				"fang":
					_fang(one, rng, size, head, glow, base_col)
				"sabre":
					_sabre(one, rng, ps * asym, head, glow, base_col, h)
				"ivory":
					_ivory(one, rng, ps * asym, head, glow, base_col, h)
				"nose":
					if side > 0.0:
						_nose(one, rng, ps, head, glow, base_col, h)
				"ossicone":
					_ossicone(one, rng, ps * asym, head, glow, base_col, h)
				"mane":
					_mane(one, rng, ps * asym, head, glow, base_col, h)
			var xf := off
			if side < 0.0:
				xf = Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3.ZERO) * off
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
	return func(i: int, _a: float) -> float:
		return 1.0 + sin(float(i) * rings) * depth


## Glowing beads ringing a horn every few segments: the alien in it.
static func _beads(k: MeshKit, pts: PackedVector3Array, rad: PackedFloat32Array, glow: Color, h: Dictionary) -> void:
	if not bool(h.get("beads", false)):
		return
	k.tag = TIP_GLOW
	var n := pts.size()
	for i in range(2, n - 2, 3):
		var t := (pts[i + 1] - pts[i - 1]).normalized()
		var side := t.cross(Vector3.UP)
		if side.length() < 0.1:
			side = Vector3.RIGHT
		side = side.normalized()
		var up := side.cross(t).normalized()
		for j in 4:
			var a := TAU * j / 4.0 + i * 0.7
			var p := pts[i] + (side * cos(a) + up * sin(a)) * rad[i] * 1.02
			k.blob(p, Vector3.ONE * rad[i] * 0.28, glow, 4, 5)
	k.tag = Vector2.ZERO


static func _tip(k: MeshKit, at: Vector3, r: float, glow: Color) -> void:
	k.tag = TIP_GLOW
	k.blob(at, Vector3(r, r * 1.5, r), glow, 6, 8)
	k.tag = Vector2.ZERO


## Sweeping horns. Style 0: a longhorn's wide sweep with upturned tips.
## 1: a lyre, out and then up with the tips turning in. 2: a buffalo's hooks,
## down, out and forward.
static func _sweep(k: MeshKit, rng: RandomNumberGenerator, s: float, head: float, glow: Color, col: Color, h: Dictionary) -> void:
	var L := 1.2 * s * float(h["spread"])
	var base := Vector3(head * 0.32, head * 0.35, head * 0.05)
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	var n := 22
	var tw := float(h["twist"])
	var curl := float(h.get("curl", 1.0))
	var rise := float(h.get("rise", 0.0))
	var style := int(h.get("style", 0))
	for i in n:
		var u := float(i) / (n - 1)
		var p := Vector3.ZERO
		match style:
			0:
				p = Vector3(L * u, L * (0.12 * u + (0.45 + rise * 0.3) * u * u * u), -L * 0.32 * sin(u * PI * 0.8))
				p.x -= smoothstep(0.7, 1.0, u) * L * 0.14 * curl
				p.y += smoothstep(0.65, 1.0, u) * L * 0.16 * curl
			1:
				p = Vector3(L * 0.55 * sin(u * PI * 0.55), L * (0.9 + rise * 0.3) * u * u, -L * 0.18 * sin(u * PI))
				p.x -= smoothstep(0.6, 1.0, u) * L * 0.18 * curl
				p.z += smoothstep(0.75, 1.0, u) * L * 0.12
			_:
				p = Vector3(L * 0.75 * sin(u * PI * 0.5), L * (-0.25 * sin(u * PI * 0.9) + (0.35 + rise * 0.2) * u * u * u), -L * 0.5 * u * u)
				p.y += smoothstep(0.7, 1.0, u) * L * 0.2 * curl
		p.z += tw * u * u * L * 0.3
		pts.append(base + p)
		rad.append(0.13 * s * pow(1.0 - u, 0.7) + 0.006)
	k.tube(pts, rad, 12, _cols(n, col), true, Vector3.UP, PackedFloat32Array(), _ridges(float(h.get("ridges", 4.0)), float(h.get("ridge_d", 0.03))))
	_beads(k, pts, rad, glow, h)
	_tip(k, pts[n - 1], 0.03 * s, glow)


## Spirals. Style 0: the bighorn's full curl round past the ear. 1: a
## markhor's corkscrew, twisting straight up and out. 2: a tight double coil.
static func _spiral(k: MeshKit, rng: RandomNumberGenerator, s: float, head: float, glow: Color, col: Color, h: Dictionary) -> void:
	s = pow(s, 0.75) * 0.85 # a coil grows round, not long: keep it to the skull
	var curl := float(h.get("curl", 1.0))
	var style := int(h.get("style", 0))
	var base := Vector3(head * 0.2, head * 0.42, head * 0.08)
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	var n := 40
	var r0 := 0.075 * s
	if style == 1:
		# Corkscrew: a helix round an axis leaning up, out and back.
		var axis := Vector3(0.45, 1.0, 0.35).normalized()
		var side := axis.cross(Vector3.FORWARD).normalized()
		var up := side.cross(axis).normalized()
		var Lc := 1.25 * s * float(h["spread"])
		var turns := 2.2 + curl
		for i in n:
			var u := float(i) / (n - 1)
			var th := u * turns * TAU
			var R := 0.13 * s * (1.0 - u * 0.5)
			pts.append(base + axis * Lc * u + (side * cos(th) + up * sin(th)) * R)
			rad.append(r0 * 0.5 * pow(1.0 - u, 0.65) + 0.006)
	else:
		var turns := (1.05 + (s - 1.0) * 0.35) * curl * (1.35 if style == 2 else 1.0)
		var R0 := 0.1 * s
		var R1 := (0.3 if style == 0 else 0.22) * s * float(h["spread"])
		for i in n:
			var u := float(i) / (n - 1)
			var th := u * turns * TAU
			var R := lerpf(R0, R1, pow(u, 0.8))
			# Up and back first, round past the ear, forward under the jaw.
			pts.append(base + Vector3(u * (0.42 if style == 0 else 0.3) * s, sin(th) * R + R0 * 0.6, cos(th) * R - R0 + 0.04 * s * u))
			rad.append(r0 * pow(1.0 - u, 0.55) + 0.008)
	k.tube(pts, rad, 12, _cols(n, col), true, Vector3.RIGHT, PackedFloat32Array(), _ridges(float(h.get("ridges", 9.0)) + 4.0, float(h.get("ridge_d", 0.05)) + 0.02))
	_beads(k, pts, rad, glow, h)
	_tip(k, pts[n - 1], 0.025 * s, glow)


## Antlers: a main beam and tines off it, every tip a glowing crystal.
## Palmate ones flatten into a broad palm with a fan of tines round its edge.
## Style 2 grows "non-typical": extra drop tines and kickers at odd angles.
static func _antler(k: MeshKit, rng: RandomNumberGenerator, s: float, head: float, glow: Color, col: Color, h: Dictionary, palm: bool) -> void:
	var L := (1.5 if palm else 0.95) * s * float(h["spread"])
	var base := Vector3(head * 0.2, head * 0.45, head * 0.1)
	var beam := PackedVector3Array()
	var rad := PackedFloat32Array()
	var n := 14
	var rise := float(h.get("rise", 0.0))
	var out := Vector3(0.7, 0.6 + rise * 0.3, 0.3).normalized() if not palm else Vector3(1.0, 0.3 + rise * 0.2, 0.15).normalized()
	var p := base
	for i in n:
		var u := float(i) / (n - 1)
		beam.append(p)
		rad.append((0.065 * (1.0 + 0.5 * sin(clampf((u - 0.3) / 0.6, 0.0, 1.0) * PI)) if palm else 0.055) * s * lerpf(1.0, 0.4, u) + 0.006)
		var bend := Vector3(-0.2, 0.05, -0.65) * u * float(h.get("curl", 1.0)) if not palm else Vector3(-0.05, 0.4, -0.2) * u
		p += (out + bend).normalized() * L / (n - 1)
	var ry := PackedFloat32Array()
	if palm:
		for i in n:
			ry.append(lerpf(1.0, 0.3, smoothstep(0.3, 0.7, float(i) / (n - 1))))
	k.tube(beam, rad, 10, _cols(n, col), true, Vector3.UP, ry, _ridges(13.0, 0.04))
	var tips: Array = [beam[n - 1]]
	var tines := int(h["tines"])
	if not palm:
		var bt := beam[1]
		var tl := L * 0.38
		var bp := PackedVector3Array([bt, bt + Vector3(0.02, 0.06, -0.6).normalized() * tl * 0.5, bt + Vector3(0.0, 0.3, -1.0).normalized() * tl])
		k.tube(bp, PackedFloat32Array([rad[1] * 0.7, rad[1] * 0.5, 0.005]), 7, _cols(3, col), true)
		tips.append(bp[2])
	var wild := int(h.get("style", 0)) == 2
	for t in tines:
		var u2 := lerpf(0.28, 0.93, float(t) / maxf(1.0, float(tines - 1)))
		var ip := int(u2 * (n - 1))
		var at := beam[ip]
		var dir := Vector3(rng.randf_range(-0.2, 0.3), 1.0, rng.randf_range(-0.4, 0.3)).normalized()
		if palm:
			var fa := lerpf(-0.6, 1.2, float(t) / maxf(1.0, float(tines - 1)))
			dir = Vector3(sin(fa) * 0.6 + 0.3, cos(fa), -0.15).normalized()
		elif wild and t % 3 == 2:
			dir = Vector3(rng.randf_range(-0.3, 0.8), rng.randf_range(-1.0, 0.2), rng.randf_range(-0.6, 0.6)).normalized()
		var tl2 := L * rng.randf_range(0.28, 0.46) * (1.15 if palm else 1.0)
		var mid := at + dir * tl2 * 0.55 + Vector3(0, 0, -0.05) * tl2
		var tip := at + dir * tl2 + Vector3(rng.randf_range(-0.04, 0.04), 0, -0.08 * tl2)
		k.tube(PackedVector3Array([at, mid, tip]), PackedFloat32Array([rad[ip] * 0.75, rad[ip] * 0.45, 0.004]), 7, _cols(3, col), true)
		tips.append(tip)
	_beads(k, beam, rad, glow, h)
	for tp in tips:
		_tip(k, tp, (0.04 if palm else 0.026) * s, glow)


## Tusks curling up out of the jaw, and a ring of short horns on the skull.
static func _tusk(k: MeshKit, rng: RandomNumberGenerator, s: float, head: float, glow: Color, col: Color, h: Dictionary) -> void:
	var base := Vector3(head * 0.18, -head * 0.12, -head * 0.55)
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	var n := 14
	var L := 0.42 * s
	var curl := float(h.get("curl", 1.0))
	for i in n:
		var u := float(i) / (n - 1)
		var th := u * PI * 0.95 * curl
		pts.append(base + Vector3(0.1 * L * u, sin(th) * L * 0.45, -cos(th) * L * 0.25 + L * 0.25 - u * 0.05))
		rad.append(0.045 * s * (1.0 - u * 0.9) + 0.004)
	k.tube(pts, rad, 10, _cols(n, Color(0.86, 0.8, 0.66)), true)
	var horns := 3 + int(h.get("style", 0))
	for c in horns:
		var a := 0.25 + c * (1.3 / horns)
		var b := Vector3(sin(a) * head * 0.3, head * 0.38, cos(a) * head * 0.15 + head * 0.05)
		var l := (0.1 + rng.randf() * 0.06) * s
		var tip := b + Vector3(sin(a) * 0.4, 1.0, 0.25).normalized() * l
		k.tube(PackedVector3Array([b, b.lerp(tip, 0.6) + Vector3(0, 0, 0.02), tip]), PackedFloat32Array([0.025 * s, 0.016 * s, 0.003]), 7, _cols(3, col), true)
		_tip(k, tip, 0.01 * s, glow)


## Ironcrown: girder horns out, up and in like a bison's, and spikes along the boss.
static func _crown(k: MeshKit, rng: RandomNumberGenerator, s: float, head: float, glow: Color, col: Color, h: Dictionary) -> void:
	var L := 2.0 * s * float(h["spread"])
	var base := Vector3(head * 0.38, head * 0.3, 0.0)
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	var n := 22
	for i in n:
		var u := float(i) / (n - 1)
		var x := base.x + L * 0.55 * sin(u * PI * 0.65)
		var y := base.y + L * 0.6 * (u * u)
		var z := base.z - L * 0.25 * sin(u * PI)
		x -= smoothstep(0.6, 1.0, u) * L * 0.2
		pts.append(Vector3(x, y, z))
		rad.append(0.24 * s * pow(1.0 - u, 0.65) + 0.01)
	k.tube(pts, rad, 14, _cols(n, col), true, Vector3.UP, PackedFloat32Array(), _ridges(5.0, 0.06))
	var hb := h.duplicate()
	hb["beads"] = true
	_beads(k, pts, rad, glow, hb)
	for c in 5:
		var b := Vector3(head * (0.04 + c * 0.07), head * 0.48, head * (0.12 - c * 0.09))
		var tip := b + Vector3(0.15, 1.0, 0.3).normalized() * (0.32 + c * 0.05) * s
		k.tube(PackedVector3Array([b, tip]), PackedFloat32Array([0.06 * s, 0.004]), 7, _cols(2, col), true)
		_tip(k, tip, 0.03 * s, glow)
	_tip(k, pts[n - 1], 0.05 * s, glow)


static func _fang(k: MeshKit, rng: RandomNumberGenerator, s: float, head: float, glow: Color, col: Color) -> void:
	var b := Vector3(head * 0.1, -head * 0.15, -head * 0.62)
	var L := 0.16 * s
	var pts := PackedVector3Array([b, b + Vector3(0, -L * 0.5, -L * 0.1), b + Vector3(0, -L, 0.03)])
	k.tube(pts, PackedFloat32Array([0.018 * s, 0.012 * s, 0.002]), 6, _cols(3, Color(0.92, 0.9, 0.84)), true)



## Tigrath: sabre fangs down past the jaw, and horns swept straight back.
static func _sabre(k: MeshKit, rng: RandomNumberGenerator, s: float, head: float, glow: Color, col: Color, h: Dictionary) -> void:
	var fb := Vector3(head * 0.12, -head * 0.1, -head * 0.55)
	var fl := 0.32 * s
	k.tube(PackedVector3Array([fb, fb + Vector3(0, -fl * 0.5, -fl * 0.08), fb + Vector3(0.01, -fl, 0.04)]), PackedFloat32Array([0.028 * s, 0.02 * s, 0.002]), 8, _cols(3, Color(0.93, 0.9, 0.82)), true)
	var base := Vector3(head * 0.24, head * 0.38, head * 0.02)
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	var n := 16
	var L := 0.9 * s * float(h["spread"])
	var rise := float(h.get("rise", 0.0))
	for i in n:
		var u := float(i) / (n - 1)
		pts.append(base + Vector3(L * 0.22 * u, L * (0.25 + rise * 0.2) * sin(u * PI * 0.6), L * u))
		rad.append(0.06 * s * pow(1.0 - u, 0.7) + 0.004)
	k.tube(pts, rad, 10, _cols(n, col), true, Vector3.UP, PackedFloat32Array(), _ridges(float(h.get("ridges", 6.0)), 0.04))
	_beads(k, pts, rad, glow, h)
	_tip(k, pts[n - 1], 0.02 * s, glow)


## Mammothar: great tusks out of the upper jaw, sweeping forward, up and in.
static func _ivory(k: MeshKit, rng: RandomNumberGenerator, s: float, head: float, glow: Color, col: Color, h: Dictionary) -> void:
	var base := Vector3(head * 0.2, -head * 0.25, -head * 0.42)
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	var n := 20
	var L := 1.8 * s * float(h["spread"])
	var curl := float(h.get("curl", 1.0))
	for i in n:
		var u := float(i) / (n - 1)
		var th := u * PI * 0.55 * curl
		pts.append(base + Vector3(L * 0.12 * sin(u * PI) - L * 0.12 * u * u, -L * 0.25 * sin(th) + L * 0.45 * u * u, -L * 0.75 * sin(u * PI * 0.5)))
		rad.append(0.1 * s * pow(1.0 - u, 0.5) + 0.006)
	var ivory := Color(0.9, 0.86, 0.74).lerp(col, 0.15)
	k.tube(pts, rad, 12, _cols(n, ivory), true, Vector3.UP, PackedFloat32Array(), _ridges(3.0, 0.015))
	_beads(k, pts, rad, glow, h)
	_tip(k, pts[n - 1], 0.025 * s, glow)


## Rhinox: a great curved horn on the nose, a second behind it, and a third,
## the Visitors' addition, that glows.
static func _nose(k: MeshKit, rng: RandomNumberGenerator, s: float, head: float, glow: Color, col: Color, h: Dictionary) -> void:
	var specs := [[Vector3(0, head * 0.05, -head * 0.62), 1.0], [Vector3(0, head * 0.18, -head * 0.3), 0.55], [Vector3(0, head * 0.3, -head * 0.02), 0.35]]
	for i in specs.size():
		var b: Vector3 = specs[i][0]
		var f: float = specs[i][1]
		var L := 1.0 * s * f * float(h["spread"])
		var pts := PackedVector3Array()
		var rad := PackedFloat32Array()
		var n := 12
		for j in n:
			var u := float(j) / (n - 1)
			pts.append(b + Vector3(0, L * u, L * 0.35 * u * u * float(h.get("curl", 1.0))))
			rad.append(0.16 * s * f * pow(1.0 - u, 0.8) + 0.004)
		k.tube(pts, rad, 10, _cols(n, col), true, Vector3.FORWARD, PackedFloat32Array(), _ridges(float(h.get("ridges", 5.0)), 0.03))
		if i == 2:
			_beads(k, pts, rad, glow, {"beads": true})
		_tip(k, pts[n - 1], 0.02 * s * f + 0.01, glow)


## Girafflux: two stubby ossicones, each sprouting a crown of crystal.
static func _ossicone(k: MeshKit, rng: RandomNumberGenerator, s: float, head: float, glow: Color, col: Color, h: Dictionary) -> void:
	var b := Vector3(head * 0.14, head * 0.35, head * 0.12)
	var top := b + Vector3(0.05, 0.3, 0.06) * s
	k.tube(PackedVector3Array([b, b.lerp(top, 0.5), top]), PackedFloat32Array([0.05 * s, 0.04 * s, 0.045 * s]), 8, _cols(3, col), true)
	k.tag = TIP_GLOW
	for i in int(h.get("tines", 5)):
		var a := TAU * i / float(h.get("tines", 5)) + float(h.get("twist", 0.0))
		var d := Vector3(cos(a) * 0.5, 1.0, sin(a) * 0.5).normalized()
		var l := (0.12 + rng.randf() * 0.18) * s
		k.tube(PackedVector3Array([top, top + d * l]), PackedFloat32Array([0.018 * s, 0.002]), 5, glow, true)
	k.tag = Vector2.ZERO


## Leonix: crystal quills fanned through the mane, longest at the crown.
static func _mane(k: MeshKit, rng: RandomNumberGenerator, s: float, head: float, glow: Color, col: Color, h: Dictionary) -> void:
	var n := 5 + int(h.get("tines", 5)) / 2
	var c := Vector3(0, 0, head * 0.3)
	for i in n:
		var a := lerpf(0.15, PI * 0.5, float(i) / float(n - 1))
		var d := Vector3(cos(a) * 1.0, sin(a) * 1.1, 0.45).normalized()
		var l := (0.32 + 0.25 * sin(a)) * s * float(h["spread"])
		var b := c + d * head * 0.55
		k.tube(PackedVector3Array([b, b + d * l * 0.6 + Vector3(0, 0, 0.04), b + d * l]), PackedFloat32Array([0.022 * s, 0.014 * s, 0.002]), 6, _cols(3, col), true)
		_tip(k, b + d * l, 0.012 * s, glow)
