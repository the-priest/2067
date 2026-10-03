extends Node
## The hunt scene: a loading screen while the valley is built, then the world.

var world: World
var load_ui: Control
var bar: ProgressBar
var what: Label


func _ready() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)
	load_ui = Control.new()
	load_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	load_ui.theme = UIStyle.theme()
	cl.add_child(load_ui)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.035)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	load_ui.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.position = Vector2(-300, -60)
	v.custom_minimum_size = Vector2(600, 0)
	load_ui.add_child(v)
	var t := UIStyle.label("2067", 72, Color(0.95, 0.85, 0.65), UIStyle.title())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	what = UIStyle.label("", 18, UIStyle.DIM, UIStyle.body())
	what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(what)
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(600, 6)
	v.add_child(bar)
	var tip := UIStyle.label(_tip(), 16, UIStyle.BONE, UIStyle.body())
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(600, 0)
	v.add_child(tip)
	world = World.new()
	world.name = "World"
	world.progress.connect(func(p: float, w: String) -> void:
		bar.value = p * 100.0
		what.text = w)
	world.loaded.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(load_ui, "modulate:a", 0.0, 0.8)
		tw.tween_callback(cl.queue_free))
	add_child(world)


func _tip() -> String:
	var tips := [
		"Every hybrid's heart sits somewhere different. A heart scanner shows you where.",
		"Keep the wind in your face. If it blows from you to them, they'll smell you long before they see you.",
		"Crouch. Footsteps carry.",
		"A heart-shot animal runs a few seconds before it drops. Don't shoot again: every hole costs the hide.",
		"Hybrid blood glows. Follow it.",
		"Tuskmaws don't run away. They run at you.",
		"Hold your breath on the scope: Shift.",
		"The rail gun goes through anything. Including the animal behind it.",
	]
	return tips[randi() % tips.size()]
