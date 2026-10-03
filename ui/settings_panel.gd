extends UIPanel
## Graphics preset, view, mouse, sound.


func panel_title() -> String:
	return "SETTINGS"


func panel_size() -> Vector2:
	return Vector2(720, 560)


func build() -> void:
	var renderer := "Forward+ (Vulkan)" if not Settings.compat() else "Compatibility (OpenGL)"
	box.add_child(UIStyle.label("Renderer: %s   ·   GPU: %s" % [renderer, RenderingServer.get_video_adapter_name()], 14, UIStyle.DIM))
	var q := OptionButton.new()
	for i in Settings.PRESETS.size():
		q.add_item(Settings.PRESETS[i], i)
	q.selected = Settings.preset
	q.item_selected.connect(func(i: int) -> void:
		Settings.preset = i
		Settings.save()
		_apply())
	_line("Graphics quality", q)
	box.add_child(UIStyle.label("LOW for laptops and integrated graphics. ULTRA adds global illumination. Grass, view distance and shadows change after a restart of the hunt.", 13, UIStyle.DIM))
	_slider("Render scale", 0.5, 1.0, Settings.render_scale, func(v: float) -> void:
		Settings.render_scale = v
		Settings.save()
		_apply())
	_slider("Field of view", 60.0, 100.0, Settings.fov, func(v: float) -> void:
		Settings.fov = v
		Settings.save())
	_slider("Mouse sensitivity", 0.0008, 0.006, Settings.sens, func(v: float) -> void:
		Settings.sens = v
		Settings.save())
	_slider("Volume", 0.0, 1.0, Settings.volume, func(v: float) -> void:
		Settings.set_volume(v)
		Settings.save())
	var inv := CheckBox.new()
	inv.text = "Invert mouse Y"
	inv.button_pressed = Settings.invert_y
	inv.toggled.connect(func(b: bool) -> void:
		Settings.invert_y = b
		Settings.save())
	box.add_child(inv)
	var kc := CheckBox.new()
	kc.text = "Bullet cam on long vital shots"
	kc.button_pressed = Settings.killcam
	kc.toggled.connect(func(b: bool) -> void:
		Settings.killcam = b
		Settings.save())
	box.add_child(kc)
	var vs := CheckBox.new()
	vs.text = "V-Sync"
	vs.button_pressed = Settings.vsync
	vs.toggled.connect(func(b: bool) -> void:
		Settings.vsync = b
		Settings.save()
		_apply())
	box.add_child(vs)


func _apply() -> void:
	if world != null and world.get("atmo") != null:
		world.atmo.apply_quality()


func _line(t: String, c: Control) -> void:
	var h := HBoxContainer.new()
	var l := UIStyle.label(t, 18)
	l.custom_minimum_size = Vector2(240, 0)
	h.add_child(l)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(c)
	box.add_child(h)


func _slider(t: String, lo: float, hi: float, v: float, cb: Callable) -> void:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 100.0
	s.value = v
	s.value_changed.connect(cb)
	_line(t, s)
