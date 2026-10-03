class_name Guns
extends RefCounted
## The first-person models: Grandpa's lever gun in oiled walnut, the ranch
## rifle with its scope, the big-bore Thumper, and the Visitor-built coil
## rifle, plasma lance and rail gun with their glowing parts. Plus the
## binoculars. Each model's sight line runs along -Z at y = SIGHT.

const SIGHT := 0.045

static var _mats: Dictionary = {}


static func mats() -> Dictionary:
	if not _mats.is_empty():
		return _mats
	var wood := StandardMaterial3D.new()
	wood.vertex_color_use_as_albedo = true
	wood.albedo_texture = Tex.get_tex("wood")
	wood.roughness = 0.45
	wood.uv1_scale = Vector3(1.5, 1.5, 1)
	var metal := StandardMaterial3D.new()
	metal.vertex_color_use_as_albedo = true
	metal.metallic = 0.85
	metal.roughness = 0.32
	metal.albedo_texture = Tex.get_tex("rust")
	metal.uv1_scale = Vector3(3, 3, 1)
	var glow := StandardMaterial3D.new()
	glow.vertex_color_use_as_albedo = true
	glow.emission_enabled = true
	glow.emission = Color(0.3, 1.0, 0.9)
	glow.emission_energy_multiplier = 2.5
	glow.roughness = 0.2
	var alien := StandardMaterial3D.new()
	alien.vertex_color_use_as_albedo = true
	alien.metallic = 0.7
	alien.roughness = 0.18
	alien.clearcoat_enabled = true
	alien.rim_enabled = true
	alien.rim = 0.4
	var lens := StandardMaterial3D.new()
	lens.albedo_color = Color(0.05, 0.08, 0.12)
	lens.metallic = 1.0
	lens.roughness = 0.0
	_mats = {"wood": wood, "metal": metal, "glow": glow, "alien": alien, "lens": lens}
	return _mats


## A model as a Node3D with one MeshInstance per material.
static func build(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Gun_" + kind
	var parts := {"wood": MeshKit.new(), "metal": MeshKit.new(), "glow": MeshKit.new(), "alien": MeshKit.new(), "lens": MeshKit.new()}
	var dark := Color(0.16, 0.16, 0.17)
	var blue := Color(0.22, 0.23, 0.26)
	var walnut := Color(0.42, 0.24, 0.13)
	var scope := false
	var muzzle := -0.7
	match kind:
		"lever":
			_stock(parts["wood"], walnut, 0.0)
			parts["metal"].box(Vector3(0, 0.0, -0.08), Vector3(0.045, 0.07, 0.2), blue)
			parts["metal"].cyl(Vector3(0, 0.022, -0.16), Vector3(0, 0.022, -0.72), 0.011, 0.01, 10, dark)
			parts["metal"].cyl(Vector3(0, 0.0, -0.18), Vector3(0, 0.0, -0.66), 0.009, 0.009, 8, dark)
			parts["wood"].box(Vector3(0, 0.005, -0.32), Vector3(0.042, 0.04, 0.24), walnut)
			# The lever loop.
			parts["metal"].tube(PackedVector3Array([Vector3(0, -0.035, -0.02), Vector3(0, -0.08, -0.01), Vector3(0, -0.085, 0.07), Vector3(0, -0.04, 0.08)]), PackedFloat32Array([0.006, 0.006, 0.006, 0.006]), 6, dark, false)
			# Sights.
			parts["metal"].box(Vector3(0, SIGHT - 0.008, -0.69), Vector3(0.004, 0.016, 0.006), dark)
			parts["metal"].box(Vector3(0, SIGHT - 0.012, -0.12), Vector3(0.03, 0.01, 0.006), dark)
			muzzle = -0.73
		"bolt", "thumper":
			var big := kind == "thumper"
			_stock(parts["wood"], walnut.darkened(0.2) if big else Color(0.35, 0.3, 0.22), 0.0)
			parts["metal"].cyl(Vector3(0, 0.0, 0.0), Vector3(0, 0.0, -0.2), 0.022, 0.022, 12, blue)
			parts["metal"].cyl(Vector3(0, 0.005, -0.2), Vector3(0, 0.005, -0.8), 0.016 if big else 0.012, 0.014 if big else 0.009, 12, dark)
			parts["wood"].box(Vector3(0, -0.012, -0.36), Vector3(0.05, 0.045, 0.34), walnut.darkened(0.2) if big else Color(0.35, 0.3, 0.22))
			parts["metal"].cyl(Vector3(0.02, 0.0, -0.02), Vector3(0.06, -0.02, -0.02), 0.005, 0.005, 6, dark)
			parts["metal"].blob(Vector3(0.062, -0.022, -0.02), Vector3.ONE * 0.011, dark, 5, 6)
			scope = true
			muzzle = -0.82
		"coil":
			parts["alien"].box(Vector3(0, -0.01, 0.12), Vector3(0.05, 0.09, 0.28), Color(0.1, 0.1, 0.12))
			parts["alien"].box(Vector3(0, 0.0, -0.15), Vector3(0.06, 0.07, 0.36), Color(0.14, 0.15, 0.17))
			parts["alien"].cyl(Vector3(0, 0.0, -0.3), Vector3(0, 0.0, -0.85), 0.012, 0.012, 10, Color(0.1, 0.1, 0.12))
			for i in 6:
				var z := -0.38 - i * 0.075
				parts["glow"].cyl(Vector3(0, 0.0, z), Vector3(0, 0.0, z - 0.018), 0.024, 0.024, 12, Color(0.3, 1.0, 0.9))
			parts["alien"].box(Vector3(0, -0.07, -0.02), Vector3(0.035, 0.08, 0.04), Color(0.1, 0.1, 0.12), Basis(Vector3.RIGHT, 0.3))
			scope = true
			muzzle = -0.87
		"plasma":
			parts["alien"].box(Vector3(0, -0.01, 0.1), Vector3(0.06, 0.1, 0.26), Color(0.18, 0.12, 0.1))
			parts["alien"].blob(Vector3(0, 0.0, -0.22), Vector3(0.07, 0.07, 0.22), Color(0.2, 0.16, 0.14), 8, 12)
			parts["glow"].blob(Vector3(0, 0.0, -0.22), Vector3(0.045, 0.045, 0.16), Color(1.0, 0.5, 0.2), 6, 10)
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				parts["alien"].tube(PackedVector3Array([Vector3(cos(a) * 0.05, sin(a) * 0.05, -0.1), Vector3(cos(a) * 0.08, sin(a) * 0.08, -0.3), Vector3(cos(a) * 0.035, sin(a) * 0.035, -0.6)]), PackedFloat32Array([0.01, 0.012, 0.006]), 6, Color(0.25, 0.2, 0.17), true)
			parts["glow"].cyl(Vector3(0, 0, -0.55), Vector3(0, 0, -0.62), 0.03, 0.02, 10, Color(1.0, 0.6, 0.3))
			scope = true
			muzzle = -0.63
		"rail":
			parts["alien"].box(Vector3(0, -0.01, 0.12), Vector3(0.05, 0.1, 0.3), Color(0.12, 0.12, 0.14))
			parts["alien"].box(Vector3(0, -0.005, -0.12), Vector3(0.07, 0.08, 0.3), Color(0.16, 0.16, 0.18))
			for s: float in [-1.0, 1.0]:
				parts["alien"].box(Vector3(s * 0.022, 0.0, -0.6), Vector3(0.012, 0.05, 0.7), Color(0.2, 0.2, 0.22))
			parts["glow"].box(Vector3(0, 0.0, -0.6), Vector3(0.008, 0.02, 0.68), Color(0.6, 0.85, 1.0))
			scope = true
			muzzle = -0.95
		"binoculars":
			for s: float in [-1.0, 1.0]:
				parts["metal"].cyl(Vector3(s * 0.035, 0, 0.02), Vector3(s * 0.035, 0, -0.12), 0.024, 0.028, 14, Color(0.12, 0.12, 0.12))
				parts["lens"].cyl(Vector3(s * 0.035, 0, -0.121), Vector3(s * 0.035, 0, -0.123), 0.025, 0.025, 14, Color.BLACK)
			parts["metal"].box(Vector3(0, 0, -0.05), Vector3(0.05, 0.02, 0.05), Color(0.1, 0.1, 0.1))
	if scope:
		var sy := SIGHT
		var sc := Color(0.08, 0.08, 0.09)
		parts["metal"].cyl(Vector3(0, sy, 0.06), Vector3(0, sy, -0.3), 0.017, 0.017, 14, sc)
		parts["metal"].cyl(Vector3(0, sy, 0.1), Vector3(0, sy, 0.05), 0.021, 0.018, 14, sc)
		parts["metal"].cyl(Vector3(0, sy, -0.3), Vector3(0, sy, -0.36), 0.018, 0.026, 14, sc)
		parts["lens"].cyl(Vector3(0, sy, -0.361), Vector3(0, sy, -0.362), 0.024, 0.024, 14, Color.BLACK)
		parts["metal"].box(Vector3(0, sy * 0.5, -0.02), Vector3(0.012, sy, 0.02), sc)
		parts["metal"].box(Vector3(0, sy * 0.5, -0.2), Vector3(0.012, sy, 0.02), sc)
	for k in parts.keys():
		var mk: MeshKit = parts[k]
		if mk.empty():
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mk.commit()
		mi.material_override = mats()[k]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = 2
		root.add_child(mi)
	var mz := Marker3D.new()
	mz.name = "Muzzle"
	mz.position = Vector3(0, 0.005, muzzle)
	root.add_child(mz)
	return root


static func _stock(k: MeshKit, c: Color, y: float) -> void:
	k.tube(PackedVector3Array([Vector3(0, y - 0.01, 0.02), Vector3(0, y - 0.03, 0.14), Vector3(0, y - 0.055, 0.32)]), PackedFloat32Array([0.022, 0.026, 0.04]), 8, c, true, Vector3.UP, PackedFloat32Array([1.3, 1.6, 2.0]))
	k.box(Vector3(0, y - 0.05, -0.0), Vector3(0.03, 0.06, 0.05), c, Basis(Vector3.RIGHT, 0.4))
