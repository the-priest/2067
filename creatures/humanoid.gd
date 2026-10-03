class_name Humanoid
extends Node3D
## People, and things that were people. One procedural figure, dressed and
## proportioned by kind: Dale in his flannel and trucker cap, the shambling
## ghouls, the Burnt (Xhuul soldiers the bombs left behind, four arms and all
## of them glowing), the little grey Xhuul from the broadcasts, soldiers and
## civilians for the old footage, and Xyla. Animated in code: idle, walk,
## run, aim, attack, cheer, crouch, dead.

const KINDS := {
	"dale": {"h": 1.8, "skin": Color(0.78, 0.58, 0.45), "shirt": Color(0.6, 0.12, 0.1), "shirt2": Color(0.1, 0.08, 0.08), "pants": Color(0.2, 0.26, 0.42), "boots": Color(0.3, 0.2, 0.12), "w": 1.12, "beard": Color(0.35, 0.22, 0.12), "cap": Color(0.15, 0.32, 0.2)},
	"ghoul": {"h": 1.75, "skin": Color(0.45, 0.5, 0.38), "shirt": Color(0.3, 0.27, 0.22), "pants": Color(0.22, 0.2, 0.18), "boots": Color(0.15, 0.13, 0.1), "w": 0.9, "hunch": 0.45, "glow": Color(0.5, 1.0, 0.2), "sores": true},
	"burnt": {"h": 2.25, "skin": Color(0.32, 0.28, 0.4), "shirt": Color(0.12, 0.12, 0.16), "pants": Color(0.1, 0.1, 0.13), "boots": Color(0.08, 0.08, 0.1), "w": 0.8, "hunch": 0.25, "glow": Color(1.0, 0.35, 0.15), "arms4": true, "long_head": true, "sores": true},
	"grey": {"h": 1.35, "skin": Color(0.62, 0.66, 0.68), "shirt": Color(0.62, 0.66, 0.68), "pants": Color(0.62, 0.66, 0.68), "boots": Color(0.55, 0.58, 0.6), "w": 0.7, "big_head": true, "glow": Color(0.3, 1.0, 0.8)},
	"xyla": {"h": 1.9, "skin": Color(0.72, 0.8, 0.92), "shirt": Color(0.12, 0.1, 0.2), "pants": Color(0.12, 0.1, 0.2), "boots": Color(0.2, 0.15, 0.3), "w": 0.86, "glow": Color(0.45, 0.95, 1.0), "hair": Color(0.25, 0.18, 0.55), "elegant": true},
	"soldier": {"h": 1.8, "skin": Color(0.7, 0.52, 0.4), "shirt": Color(0.32, 0.36, 0.24), "pants": Color(0.3, 0.33, 0.22), "boots": Color(0.15, 0.12, 0.1), "w": 1.05, "helmet": Color(0.28, 0.32, 0.22)},
	"civilian": {"h": 1.75, "skin": Color(0.75, 0.56, 0.44), "shirt": Color(0.3, 0.45, 0.7), "pants": Color(0.25, 0.25, 0.3), "boots": Color(0.2, 0.18, 0.16), "w": 1.0},
}

var kind := "dale"
var k: Dictionary
var anim := "idle"
var speed := 1.0 # animation rate
var crouch := 0.0
var _t := 0.0
var _dead_t := 0.0
var hips: Node3D
var spine: Node3D
var head: Node3D
var legs: Array = [] # [hip, knee, side]
var arms: Array = [] # [shoulder, elbow, side, lower?]
var mat: ShaderMaterial
var holds_rifle := false


static func make(kind_: String, seed_: int = 0, rifle: bool = false) -> Humanoid:
	var hm := Humanoid.new()
	hm.kind = kind_
	hm.holds_rifle = rifle
	hm._build(seed_)
	return hm


func _build(sd: int) -> void:
	k = (KINDS[kind] as Dictionary).duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	if kind == "civilian" or kind == "soldier" and sd != 0:
		k["shirt"] = (k["shirt"] as Color).lerp(Color(rng.randf(), rng.randf(), rng.randf()), 0.6 if kind == "civilian" else 0.1)
		k["skin"] = (k["skin"] as Color).lerp([Color(0.95, 0.8, 0.7), Color(0.45, 0.3, 0.2), Color(0.8, 0.62, 0.45)][rng.randi() % 3], 0.6)
		k["h"] = float(k["h"]) * rng.randf_range(0.92, 1.06)
	var h := float(k["h"])
	var wd := float(k["w"])
	mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/humanoid.gdshader")
	mat.set_shader_parameter("glow_col", k.get("glow", Color(0.3, 1.0, 0.8)))
	mat.set_shader_parameter("fabric", Tex.get_tex("fur"))
	var skin: Color = k["skin"]
	var shirt: Color = k["shirt"]
	var pants: Color = k["pants"]
	var boots: Color = k["boots"]
	hips = Node3D.new()
	hips.position = Vector3(0, 0.52 * h, 0)
	add_child(hips)
	spine = Node3D.new()
	hips.add_child(spine)
	spine.rotation.x = -float(k.get("hunch", 0.0)) * 0.6
	# Torso: pelvis to neck.
	var tk := MeshKit.new()
	var tp := PackedVector3Array()
	var tr := PackedFloat32Array()
	var ry := PackedFloat32Array()
	var tc: Array = []
	var waist := 0.085 if not k.has("elegant") else 0.07
	var chest := 0.105 if not k.has("elegant") else 0.095
	for i in 9:
		var u := float(i) / 8.0
		tp.append(Vector3(0, -0.02 * h + u * 0.34 * h, sin(u * PI) * 0.01 * h))
		var r := lerpf(0.1, waist, smoothstep(0.0, 0.35, u))
		r = lerpf(r, chest, smoothstep(0.35, 0.75, u))
		r = lerpf(r, 0.07, smoothstep(0.85, 1.0, u))
		tr.append(r * h * wd)
		ry.append(0.62)
		tc.append(pants if u < 0.18 else shirt)
	tk.tube(tp, tr, 12, tc, true, Vector3.FORWARD, ry)
	if k.has("shirt2"):
		# Flannel: a few dark bands.
		for j in 3:
			var y := (0.1 + j * 0.08) * h
			tk.cyl(Vector3(0, y, 0), Vector3(0, y + 0.015 * h, 0), chest * h * wd * 1.03, chest * h * wd * 1.03, 12, k["shirt2"], false)
	if k.has("elegant"):
		# Xyla's suit: glowing seams down the front.
		tk.tag = Vector2(1, 0)
		for sx: float in [-1.0, 1.0]:
			tk.cyl(Vector3(sx * 0.03 * h, 0.02 * h, -0.06 * h), Vector3(sx * 0.05 * h, 0.3 * h, -0.058 * h), 0.004 * h, 0.004 * h, 4, k["glow"], false)
		tk.tag = Vector2.ZERO
	if bool(k.get("sores", false)):
		tk.tag = Vector2(1, 0)
		for j in 6:
			var a := rng.randf() * TAU
			var y2 := rng.randf_range(0.05, 0.3) * h
			tk.blob(Vector3(cos(a) * 0.07 * h * wd, y2, sin(a) * 0.045 * h), Vector3.ONE * 0.012 * h, k["glow"], 4, 5)
		tk.tag = Vector2.ZERO
	_mi(tk.commit(), spine)
	# Head.
	head = Node3D.new()
	head.position = Vector3(0, 0.36 * h, 0)
	spine.add_child(head)
	var hk := MeshKit.new()
	var hr := 0.068 * h
	var hs := Vector3(hr * 0.88, hr * 1.12, hr)
	if k.has("big_head"):
		hs = Vector3(hr * 1.5, hr * 1.7, hr * 1.5)
	if k.has("long_head"):
		hs = Vector3(hr * 0.8, hr * 1.5, hr * 1.4)
	hk.cyl(Vector3(0, -0.03 * h, 0), Vector3(0, 0.03 * h, 0), 0.032 * h, 0.03 * h, 8, skin, false)
	hk.tag = Vector2(4, 0)
	hk.blob(Vector3(0, hs.y * 0.85, 0), hs, skin, 10, 14)
	hk.tag = Vector2(3, 0)
	var eye_s := 0.012 * h
	var eye_y := hs.y * 0.9
	var eye_x := hs.x * 0.36
	if k.has("big_head") or k.has("elegant") or k.has("long_head"):
		eye_s = 0.02 * h if not k.has("elegant") else 0.015 * h
		hk.blob(Vector3(-eye_x, eye_y, -hs.z * 0.82), Vector3(eye_s * 1.2, eye_s * 0.8, eye_s * 0.5), Color.BLACK, 5, 7, 0.0, 0, Basis(Vector3.FORWARD, 0.35))
		hk.blob(Vector3(eye_x, eye_y, -hs.z * 0.82), Vector3(eye_s * 1.2, eye_s * 0.8, eye_s * 0.5), Color.BLACK, 5, 7, 0.0, 0, Basis(Vector3.FORWARD, -0.35))
	else:
		for sx: float in [-1.0, 1.0]:
			hk.blob(Vector3(sx * eye_x, eye_y, -hs.z * 0.88), Vector3.ONE * eye_s * 0.55, Color(0.95, 0.95, 0.92) if kind != "ghoul" else Color(0.8, 1.0, 0.3), 4, 6)
	hk.tag = Vector2(4, 0)
	if not k.has("big_head") and not k.has("long_head"):
		hk.blob(Vector3(0, hs.y * 0.72, -hs.z * 0.98), Vector3(0.012, 0.02, 0.015) * h, skin.darkened(0.05), 4, 6)
	hk.tag = Vector2.ZERO
	if k.has("beard"):
		hk.blob(Vector3(0, hs.y * 0.45, -hs.z * 0.55), Vector3(hs.x * 0.85, hs.y * 0.45, hs.z * 0.55), k["beard"], 7, 10, 0.3, 4)
	if k.has("cap"):
		hk.blob(Vector3(0, hs.y * 1.35, 0.005 * h), Vector3(hs.x * 1.08, hs.y * 0.5, hs.z * 1.08), k["cap"], 6, 10)
		hk.box(Vector3(0, hs.y * 1.3, -hs.z * 1.2), Vector3(hs.x * 1.6, 0.006 * h, hs.z * 0.9), k["cap"].darkened(0.2))
	if k.has("helmet"):
		hk.blob(Vector3(0, hs.y * 1.25, 0), Vector3(hs.x * 1.25, hs.y * 0.65, hs.z * 1.25), k["helmet"], 6, 10)
	if k.has("hair"):
		# Xyla's hair: long tendrils that fall to her waist, glowing at the ends.
		for j in 9:
			var a := lerpf(-1.2, 1.2, float(j) / 8.0)
			var b := Vector3(sin(a) * hs.x * 0.9, hs.y * 1.3, cos(a) * hs.z * 0.6)
			var pts := PackedVector3Array([b, b + Vector3(sin(a) * 0.04, -0.12, 0.06) * h, b + Vector3(sin(a) * 0.06, -0.26, 0.08) * h, b + Vector3(sin(a) * 0.05, -0.4, 0.06) * h])
			hk.tube(pts, PackedFloat32Array([0.016 * h, 0.014 * h, 0.011 * h, 0.004 * h]), 5, k["hair"], true)
			hk.tag = Vector2(1, 0)
			hk.blob(pts[3], Vector3.ONE * 0.006 * h, k["glow"], 3, 4)
			hk.tag = Vector2.ZERO
		hk.blob(Vector3(0, hs.y * 1.25, 0.01 * h), Vector3(hs.x * 1.05, hs.y * 0.55, hs.z * 1.05), k["hair"], 8, 10)
		hk.tag = Vector2(1, 0)
		for sx: float in [-1.0, 1.0]:
			hk.blob(Vector3(sx * hs.x * 0.55, hs.y * 0.65, -hs.z * 0.8), Vector3.ONE * 0.003 * h, k["glow"], 3, 4)
		hk.tag = Vector2.ZERO
	_mi(hk.commit(), head)
	# Legs.
	for sx: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(sx * 0.055 * h * wd, -0.01 * h, 0)
		hips.add_child(hip)
		var lk := MeshKit.new()
		lk.tube(PackedVector3Array([Vector3(0, 0.03 * h, 0), Vector3(0, -0.12 * h, -0.005 * h), Vector3(0, -0.24 * h, 0)]), PackedFloat32Array([0.058 * h * wd, 0.05 * h * wd, 0.038 * h]), 10, pants, true)
		_mi(lk.commit(), hip)
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.245 * h, 0)
		hip.add_child(knee)
		var sk := MeshKit.new()
		sk.tube(PackedVector3Array([Vector3(0, 0.0, 0), Vector3(0, -0.12 * h, 0.006 * h), Vector3(0, -0.21 * h, 0)]), PackedFloat32Array([0.04 * h, 0.036 * h * wd, 0.028 * h]), 10, pants, true)
		sk.box(Vector3(0, -0.245 * h, -0.025 * h), Vector3(0.05 * h, 0.05 * h, 0.13 * h), boots)
		_mi(sk.commit(), knee)
		legs.append([hip, knee, sx])
	# Arms (the Burnt have a second, smaller pair).
	var pairs := 2 if k.has("arms4") else 1
	for pr in pairs:
		var sc := 1.0 if pr == 0 else 0.75
		for sx: float in [-1.0, 1.0]:
			var sh := Node3D.new()
			sh.position = Vector3(sx * 0.115 * h * wd, (0.31 if pr == 0 else 0.22) * h, 0)
			spine.add_child(sh)
			var ak := MeshKit.new()
			ak.blob(Vector3(0, 0, 0), Vector3.ONE * 0.042 * h * wd, shirt, 6, 8)
			ak.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, -0.09 * h, 0), Vector3(0, -0.17 * h * sc, 0)]), PackedFloat32Array([0.038 * h * wd, 0.033 * h, 0.028 * h]), 8, shirt if kind != "grey" else skin, true)
			_mi(ak.commit(), sh)
			var el := Node3D.new()
			el.position = Vector3(0, -0.17 * h * sc, 0)
			sh.add_child(el)
			var fk := MeshKit.new()
			var fl := 0.15 * h * sc * (1.25 if kind in ["ghoul", "burnt"] else 1.0)
			fk.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, -fl * 0.6, 0), Vector3(0, -fl, 0)]), PackedFloat32Array([0.028 * h, 0.025 * h, 0.022 * h]), 8, shirt if kind in ["dale", "soldier", "xyla"] else skin, true)
			fk.tag = Vector2(4, 0)
			fk.blob(Vector3(0, -fl - 0.035 * h, 0), Vector3(0.022, 0.04, 0.032) * h, skin, 5, 7)
			if kind in ["ghoul", "burnt"]:
				fk.tag = Vector2(1, 0) if kind == "burnt" else Vector2.ZERO
				for c in 3:
					fk.cyl(Vector3((c - 1) * 0.01 * h, -fl - 0.06 * h, -0.01 * h), Vector3((c - 1) * 0.012 * h, -fl - 0.11 * h, -0.03 * h), 0.004 * h, 0.001 * h, 4, skin.darkened(0.4), false)
			fk.tag = Vector2.ZERO
			_mi(fk.commit(), el)
			arms.append([sh, el, sx, pr == 1])
	if holds_rifle:
		var g := MeshKit.new()
		g.box(Vector3(0, 0, -0.25), Vector3(0.04, 0.07, 0.75), Color(0.35, 0.22, 0.12))
		g.cyl(Vector3(0, 0.03, -0.3), Vector3(0, 0.03, -0.95), 0.01, 0.01, 6, Color(0.12, 0.12, 0.13))
		g.cyl(Vector3(0, 0.08, 0.0), Vector3(0, 0.08, -0.3), 0.018, 0.018, 8, Color(0.08, 0.08, 0.09))
		var gm := MeshInstance3D.new()
		gm.mesh = g.commit()
		gm.material_override = mat
		gm.name = "Rifle"
		spine.add_child(gm)
		gm.position = Vector3(0.12 * h, 0.22 * h, -0.1 * h)


func _mi(m: Mesh, parent: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.visibility_range_end = 400.0
	parent.add_child(mi)


func set_anim(a: String) -> void:
	if anim == a:
		return
	anim = a
	if a == "dead":
		_dead_t = 0.0


func _process(dt: float) -> void:
	_t += dt * speed
	var h := float(k["h"])
	var walk := 0.0
	var arm_swing := 0.0
	match anim:
		"walk":
			walk = 0.5
			arm_swing = 0.4
		"run":
			walk = 0.85
			arm_swing = 0.8
		"attack":
			walk = 0.3
	var ph := _t * (5.0 if anim == "walk" else (9.0 if anim == "run" else (3.5 if anim == "attack" else 1.0)))
	if kind == "ghoul" and anim in ["walk", "attack"]:
		ph *= 0.7
	for l in legs:
		var hip: Node3D = l[0]
		var knee: Node3D = l[1]
		var side: float = l[2]
		var s := sin(ph + (PI if side > 0 else 0.0))
		hip.rotation.x = s * walk - crouch * 1.1
		knee.rotation.x = maxf(0.0, -cos(ph + (PI if side > 0 else 0.0))) * walk * 1.4 + crouch * 1.9
	hips.position.y = 0.52 * h - crouch * 0.18 * h + absf(sin(ph)) * walk * 0.02 * h
	hips.rotation.x = crouch * 0.6
	var breathe := sin(_t * 2.0) * 0.02
	spine.rotation.x = -float(k.get("hunch", 0.0)) * 0.6 - crouch * 0.5 + breathe * 0.3 - (0.12 if anim == "run" else 0.0)
	spine.rotation.z = sin(ph) * 0.04 * walk
	head.rotation.x = float(k.get("hunch", 0.0)) * 0.5 + crouch * 0.3
	for a in arms:
		var sh: Node3D = a[0]
		var el: Node3D = a[1]
		var side: float = a[2]
		var lower: bool = a[3]
		match anim:
			"aim":
				sh.rotation = Vector3(-1.35, side * 0.25, 0)
				el.rotation = Vector3(-0.3 if side > 0 else -0.9, 0, 0)
			"attack":
				var sw := sin(ph * 2.0 + (0.0 if side > 0 else PI))
				sh.rotation = Vector3(-1.2 - sw * 0.6, 0, side * 0.2)
				el.rotation = Vector3(-0.6 - maxf(0.0, sw) * 0.6, 0, 0)
			"cheer":
				sh.rotation = Vector3(0, 0, side * (2.6 + sin(_t * 8.0) * 0.2))
				el.rotation = Vector3(0, 0, side * 0.3)
			"wave":
				if side > 0:
					sh.rotation = Vector3(0, 0, 2.4)
					el.rotation = Vector3(0, 0, 0.4 + sin(_t * 9.0) * 0.4)
				else:
					sh.rotation = Vector3(0.05, 0, -0.1)
					el.rotation = Vector3(-0.1, 0, 0)
			_:
				var sw2 := sin(ph + (0.0 if side > 0 else PI)) * arm_swing
				var reach := 0.0
				if kind in ["ghoul", "burnt"]:
					reach = -0.9 # arms out in front, the way they shamble
				sh.rotation = Vector3(sw2 + reach - (0.3 if lower else 0.0), 0, side * (0.08 + breathe + (0.4 if lower else 0.0)))
				el.rotation = Vector3(-0.15 - absf(sw2) * 0.5 - (0.5 if anim == "run" else 0.0), 0, 0)
		if holds_rifle and anim != "aim" and not lower:
			pass
	if anim == "dead":
		_dead_t = minf(1.0, _dead_t + dt * 2.0)
		rotation.x = lerpf(0.0, -PI * 0.48, ease(_dead_t, 0.4))
		position.y = 0.0
