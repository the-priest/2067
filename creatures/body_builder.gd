class_name BodyBuilder
extends RefCounted
## Builds a hybrid's body from its species numbers: a lofted torso, neck and
## head, four two-part legs and a tail, plus the alien parts: glowing nodes
## down the spine, extra eyes, tendrils at the jaw. Built once per species
## (the parts are shared); each animal scales and dresses it.
## Coordinates: the animal faces -Z, its feet at y 0.

static var _cache: Dictionary = {}


static func parts(species: String) -> Dictionary:
	if _cache.has(species):
		return _cache[species]
	var sp: Dictionary = Catalog.SPECIES[species]
	var b: Dictionary = sp["body"]
	var L := float(b["len"])
	var H := float(b["h"])
	var W := float(b["w"])
	var lg := float(b["leg"])
	var nk := float(b["neck"])
	var hd := float(b["head"])
	var fur: Color = sp["fur"]
	var glow: Color = sp["glow"]
	var out := {}
	var cy := lg + H * 0.5
	out["torso_y"] = cy
	out["L"] = L
	out["H"] = H
	out["W"] = W

	# --- torso: rump (z+) to chest (z-)
	var k := MeshKit.new()
	var pts := PackedVector3Array()
	var rx := PackedFloat32Array()
	var ryk := PackedFloat32Array()
	var n := 14
	var heavy_front := species in ["crownelk", "ironcrown", "moorhorn"]
	for i in n:
		var u := float(i) / (n - 1)
		var z := L * 0.5 - u * L
		var prof := pow(sin(PI * (0.04 + 0.92 * u)), 0.42)
		var hump := 0.0
		if heavy_front:
			hump = smoothstep(0.45, 0.8, u) * smoothstep(1.0, 0.8, u) * H * (0.35 if species == "ironcrown" else 0.15)
		var back_dip := sin(u * PI) * H * -0.04
		pts.append(Vector3(0, cy + hump * 0.5 + back_dip, z))
		var wr := W * 0.5 * prof * (1.0 + (0.1 if u > 0.55 else 0.0) * float(heavy_front))
		var hr := H * 0.5 * prof * (1.0 + hump / H)
		rx.append(wr)
		ryk.append(hr / maxf(wr, 0.01))
	var sag := func(i: int, a: float) -> float:
		var u2 := float(i) / (n - 1)
		var belly := maxf(0.0, -cos(a)) * sin(u2 * PI) * 0.12
		var shoulder := maxf(0.0, cos(a)) * smoothstep(0.65, 0.85, u2) * smoothstep(1.0, 0.85, u2) * 0.06
		return 1.0 + belly + shoulder
	k.tube(pts, rx, 16, fur, true, Vector3.UP, ryk, sag)
	# Glowing nodes down the spine.
	k.tag = Vector2(1, 0)
	var nodes := 7 if species != "howler" else 5
	for i in nodes:
		var u3 := lerpf(0.12, 0.85, float(i) / (nodes - 1))
		var ii := int(u3 * (n - 1))
		var top := pts[ii] + Vector3(0, rx[ii] * ryk[ii] * 0.98, 0)
		var s := H * 0.05 * (1.0 + 0.5 * sin(u3 * PI))
		k.blob(top, Vector3(s, s * 0.8, s * 1.4), glow, 5, 7)
	k.tag = Vector2.ZERO
	out["torso"] = k.commit()

	# --- neck and head, under a pivot at the top of the chest
	var piv := Vector3(0, cy + H * 0.22, -L * 0.42)
	out["neck_pivot"] = piv
	var k2 := MeshKit.new()
	var npts := PackedVector3Array()
	var nr := PackedFloat32Array()
	var nry := PackedFloat32Array()
	var up := 0.8 # how upright the neck carries
	match species:
		"tuskmaw", "howler":
			up = 0.15
		"stagwraith":
			up = 1.1
		"ironcrown":
			up = -0.1
		"moorhorn":
			up = 0.35
	var ndir := Vector3(0, up, -1.0).normalized()
	var neck_end := ndir * nk
	var head_dir := Vector3(0, -0.55, -1.0).normalized() if species not in ["tuskmaw", "howler", "ironcrown"] else Vector3(0, -0.25, -1.0).normalized()
	var snout := neck_end + head_dir * hd
	var segs := 12
	for i in segs:
		var u := float(i) / (segs - 1)
		var p: Vector3
		var r: float
		var ry: float
		if u < 0.5:
			var t := u / 0.5
			p = Vector3(0, -H * 0.12, H * 0.08).lerp(neck_end, t)
			r = lerpf(W * 0.36, hd * 0.26, t)
			ry = lerpf(1.35, 1.15, t)
		else:
			var t2 := (u - 0.5) / 0.5
			p = neck_end.lerp(snout, t2)
			r = lerpf(hd * 0.26, hd * 0.14, t2 * t2)
			ry = lerpf(1.15, 0.95, t2)
		npts.append(p)
		nr.append(r)
		nry.append(ry)
	k2.tube(npts, nr, 12, fur, true, Vector3.UP, nry)
	var head_c := neck_end + head_dir * hd * 0.35
	out["head_c"] = head_c # relative to the neck pivot
	out["head_dir"] = head_dir
	out["snout"] = snout
	# Nose / muzzle.
	k2.tag = Vector2(4, 0)
	k2.blob(snout + head_dir * hd * 0.02, Vector3(hd * 0.12, hd * 0.1, hd * 0.08), Color(0.08, 0.06, 0.06), 5, 7)
	# Eyes: two, and two smaller alien ones above them.
	k2.tag = Vector2(3, 0)
	var side := head_dir.cross(Vector3.UP).normalized()
	for sgn: float in [-1.0, 1.0]:
		var e := head_c + side * sgn * hd * 0.2 + Vector3(0, hd * 0.1, 0) + head_dir * hd * 0.05
		k2.blob(e, Vector3.ONE * hd * 0.06, Color.BLACK, 5, 7)
		k2.blob(e + Vector3(0, hd * 0.1, 0) - head_dir * hd * 0.06, Vector3.ONE * hd * 0.035, Color.BLACK, 4, 6)
	k2.tag = Vector2.ZERO
	# Ears.
	if species != "ironcrown":
		for sgn: float in [-1.0, 1.0]:
			var eb := head_c + side * sgn * hd * 0.22 + Vector3(0, hd * 0.2, 0) - head_dir * hd * 0.15
			var el := hd * (0.55 if species == "stagwraith" else 0.3)
			var et := eb + (side * sgn * 0.8 + Vector3(0, 0.7, 0.25)).normalized() * el
			var ery := PackedFloat32Array([0.35, 0.3, 0.3])
			k2.tube(PackedVector3Array([eb, eb.lerp(et, 0.5), et]), PackedFloat32Array([hd * 0.07, hd * 0.08, hd * 0.01]), 6, fur, true, Vector3.UP, ery)
	# Jaw tendrils, glowing at the tips.
	if species in ["moorhorn", "stagwraith", "crownelk", "ironcrown"]:
		for t in 4:
			var tb := snout - head_dir * hd * (0.25 + t * 0.05) + Vector3(0, -hd * 0.12, 0) + side * ((t - 1.5) * hd * 0.06)
			var tl := hd * (0.4 + 0.15 * (t % 2))
			var tp := PackedVector3Array([tb, tb + Vector3(0, -tl * 0.5, tl * 0.1), tb + Vector3(side.x * 0.05, -tl, tl * 0.25)])
			k2.tube(tp, PackedFloat32Array([hd * 0.025, hd * 0.018, hd * 0.006]), 5, fur.darkened(0.3), false)
			k2.tag = Vector2(1, 0)
			k2.blob(tp[2], Vector3.ONE * hd * 0.025, glow, 4, 5)
			k2.tag = Vector2.ZERO
	out["neck"] = k2.commit()

	# --- legs
	var hip_f := Vector3(W * 0.28, lg + H * 0.18, -L * 0.36)
	var hip_h := Vector3(W * 0.3, lg + H * 0.22, L * 0.36)
	out["hip_f"] = hip_f
	out["hip_h"] = hip_h
	for which in ["f", "h"]:
		var hy: float = (hip_f if which == "f" else hip_h).y
		var l1 := hy * 0.5
		var l2 := hy * 0.5
		var tr := W * (0.17 if which == "f" else 0.23)
		var kt := MeshKit.new()
		# Thigh: from inside the body down to the knee.
		var bend := 0.05 if which == "f" else -0.1
		kt.tube(PackedVector3Array([Vector3(0, H * 0.25, 0), Vector3(0, -l1 * 0.4, bend * l1), Vector3(0, -l1, 0)]),
			PackedFloat32Array([tr, tr * 0.8, tr * 0.42]), 9, fur, true)
		out["thigh_" + which] = kt.commit()
		out["l1_" + which] = l1
		var ks := MeshKit.new()
		var sr := tr * 0.4
		var hoof_y := -l2 + 0.03
		ks.tube(PackedVector3Array([Vector3(0, 0.02, 0), Vector3(0, -l2 * 0.55, -bend * l2 * 0.5), Vector3(0, hoof_y + 0.08, 0)]),
			PackedFloat32Array([sr, sr * 0.65, sr * 0.6]), 8, fur, true)
		ks.tag = Vector2(4, 0)
		var hoof := Color(0.07, 0.06, 0.05)
		if species == "howler":
			ks.blob(Vector3(0, hoof_y + 0.03, -0.03), Vector3(sr * 1.2, sr * 0.6, sr * 1.6), fur.darkened(0.4), 5, 6)
		else:
			ks.cyl(Vector3(0, hoof_y + 0.08, 0), Vector3(0, hoof_y - 0.02, -0.02), sr * 0.8, sr * 1.0, 8, hoof, true)
		ks.tag = Vector2.ZERO
		out["shin_" + which] = ks.commit()
		out["l2_" + which] = l2

	# --- tail
	var kt2 := MeshKit.new()
	var tl2 := L * (0.45 if species in ["moorhorn", "ironcrown", "howler"] else 0.18)
	var tpts := PackedVector3Array()
	var tr2 := PackedFloat32Array()
	for i in 6:
		var u := float(i) / 5.0
		tpts.append(Vector3(0, -u * tl2 * (0.9 if species != "howler" else 0.4), u * tl2 * (0.25 if species != "howler" else 0.9)))
		tr2.append(lerpf(W * 0.07, W * 0.025, u))
	kt2.tube(tpts, tr2, 6, fur, true)
	if species in ["moorhorn", "ironcrown"]:
		kt2.blob(tpts[5], Vector3(W * 0.06, W * 0.12, W * 0.06), fur.darkened(0.4), 5, 6, 0.3, 3)
	out["tail"] = kt2.commit()
	out["tail_pivot"] = Vector3(0, cy + H * 0.3, L * 0.5)
	_cache[species] = out
	return out
