class_name UIPanel
extends Control
## A full-screen window over the game: dims the world, takes the mouse,
## Esc closes it.

var world: Node
var box: VBoxContainer
var panel: PanelContainer
var title_lbl: Label


func setup(w: Node) -> void:
	world = w
	theme = UIStyle.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.01, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	panel = PanelContainer.new()
	panel.custom_minimum_size = panel_size()
	cc.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	title_lbl = UIStyle.label(panel_title(), 30, Color(1.0, 0.88, 0.65), UIStyle.title())
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_lbl)
	head.add_child(UIStyle.button("CLOSE  [Esc]", close))
	var sep := HSeparator.new()
	outer.add_child(sep)
	box = VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	outer.add_child(box)
	if world != null and world.has_method("push_ui"):
		world.push_ui(self)
	build()


func panel_size() -> Vector2:
	return Vector2(980, 640)


func panel_title() -> String:
	return ""


func build() -> void:
	pass


func close() -> void:
	if world != null and world.has_method("pop_ui"):
		world.pop_ui(self)
	queue_free()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func clear_box(b: Container) -> void:
	for c in b.get_children():
		c.queue_free()


func scroll() -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	return v
