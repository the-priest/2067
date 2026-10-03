extends Node
## Pictures of every intro scene. SHOTDIR=... xvfb-run godot --path . res://test/intro_shots.tscn
var intro: Node
var taken := {}
func _ready() -> void:
	IntroScene.then_scene = "res://test/check.tscn"
	intro = load("res://ui/intro.tscn").instantiate()
	add_child(intro)
func _process(_dt: float) -> void:
	if not is_instance_valid(intro):
		return
	var s: int = intro._shot
	var want := {1: 2.5, 4: 2.5, 8: 3.5, 12: 1.5, 14: 2.5, 15: 3.0, 17: 2.0, 19: 3.0, 21: 2.5, 23: 3.0}
	if want.has(s) and not taken.has(s) and intro._t > float(want[s]):
		taken[s] = true
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/intro_%02d.png" % [OS.get_environment("SHOTDIR"), s])
		print("SHOT ", s)
