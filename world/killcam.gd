class_name KillCam
extends Node3D
## The bullet cam. A long shot into the vitals plays back in slow motion:
## the camera rides the round from the muzzle to the animal, the hide goes
## see-through so you watch it find the heart (or the lungs, or the brain),
## then it swings round the animal before handing back to you.

const RIDE := 1.6 # seconds of real time riding the round
const ORBIT := 1.8 # seconds circling the animal

var world: Node
var cam: Camera3D
var from := Vector3.ZERO
var to := Vector3.ZERO
var target: Creature
var organ := ""
var _t := 0.0
var _round: MeshInstance3D
var _trail: MeshInstance3D
var _label: Label
var _layer: CanvasLayer
var _prev_cam: Camera3D


static func play(w: Node, a: Vector3, b: Vector3, c: Creature, what: String) -> void:
	var k := KillCam.new()
	k.name = "KillCam"
	k.world = w
	k.from = a
	k.to = b
	k.target = c
	k.organ = what
	k.process_mode = Node.PROCESS_MODE_ALWAYS
	w.add_child(k)


func _ready() -> void:
	_prev_cam = get_viewport().get_camera_3d()
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.far = 4000.0
	cam.cull_mask = 1
	add_child(cam)
	cam.make_current()
	_round = MeshInstance3D.new()
	var k := MeshKit.new()
	k.tube(PackedVector3Array([Vector3(0, 0, 0.02), Vector3(0, 0, -0.012), Vector3(0, 0, -0.03)]), PackedFloat32Array([0.0045, 0.0045, 0.0005]), 10, Color(0.75, 0.55, 0.3), true)
	_round.mesh = k.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.metallic = 1.0
	m.roughness = 0.2
	_round.material_override = m
	add_child(_round)
	_round.scale = Vector3.ONE * 6.0
	# A faint vapour trail behind it.
	_trail = MeshInstance3D.new()
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.albedo_color = Color(1, 1, 1, 0.18)
	_trail.material_override = tm
	add_child(_trail)
	Engine.time_scale = 0.04
	target.show_vitals(3)
	target.skin.set_shader_parameter("thermal", 1.0)
	_layer = CanvasLayer.new()
	_layer.layer = 8
	add_child(_layer)
	var bars := ColorRect.new()
	bars.color = Color(0, 0, 0, 1)
	bars.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bars.custom_minimum_size = Vector2(0, 70)
	_layer.add_child(bars)
	var bars2 := ColorRect.new()
	bars2.color = Color(0, 0, 0, 1)
	bars2.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bars2.offset_top = -70
	_layer.add_child(bars2)
	_label = UIStyle.label("%d m" % int(from.distance_to(to)), 30, Color(1.0, 0.9, 0.7), UIStyle.title())
	_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_label.position = Vector2(-300, -64)
	_label.custom_minimum_size = Vector2(600, 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layer.add_child(_label)
	Sfx.play("heart", -2.0, 0.6)


func _process(_d: float) -> void:
	var dt := 1.0 / maxf(Engine.get_frames_per_second(), 20.0)
	_t += dt
	var dir := (to - from).normalized()
	var side := dir.cross(Vector3.UP).normalized()
	if _t < RIDE:
		var u := ease(_t / RIDE, 0.6)
		var p := from.lerp(to, u)
		_round.global_position = p
		_round.look_at(to, Vector3.UP)
		var tk := MeshKit.new()
		tk.cyl(from.lerp(p, 0.6) - p, Vector3.ZERO, 0.002, 0.012, 6, Color.WHITE, false)
		_trail.mesh = tk.commit()
		_trail.global_position = p
		cam.global_position = p - dir * 1.2 + side * 0.35 + Vector3(0, 0.18, 0)
		cam.look_at(p + dir * 2.0, Vector3.UP)
	elif _t < RIDE + ORBIT:
		_round.visible = false
		_trail.visible = false
		if _label.text.ends_with(" m"):
			_label.text = "%s   ·   %d m" % [organ, int(from.distance_to(to))]
			_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.4) if organ == "HEART" else Color(1.0, 0.9, 0.7))
			Sfx.play("impact", 2.0, 0.5)
		var u2 := (_t - RIDE) / ORBIT
		var c := target.center()
		var r := float(target.sp["body"]["len"]) * target.size * 1.6 + 1.5
		var a := atan2(-dir.x, -dir.z) + PI * 0.5 + u2 * 1.4
		cam.global_position = c + Vector3(cos(a) * r, r * 0.35, sin(a) * r)
		cam.look_at(c, Vector3.UP)
	else:
		_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(target):
		target.show_vitals(0)
		target.skin.set_shader_parameter("thermal", 0.0)
	if _prev_cam != null and is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	queue_free()
