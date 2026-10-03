extends Node
## Drives the main menu with a simulated controller: d-pad down, A to select.
func _ready() -> void:
	var menu: Node = load("res://ui/main_menu.tscn").instantiate()
	add_child(menu)
	for i in 10:
		await get_tree().process_frame
	var f := get_viewport().gui_get_focus_owner()
	print("focused: ", (f as Button).text if f is Button else str(f))
	await _press(JOY_BUTTON_DPAD_DOWN)
	f = get_viewport().gui_get_focus_owner()
	print("after down: ", (f as Button).text if f is Button else str(f))
	# Open settings with A, then back out with B.
	while f is Button and (f as Button).text != "SETTINGS":
		await _press(JOY_BUTTON_DPAD_DOWN)
		f = get_viewport().gui_get_focus_owner()
	await _press(JOY_BUTTON_A)
	var open := false
	for c in menu.ui.get_children():
		if c is UIPanel:
			open = true
	print("A opened settings: ", open)
	f = get_viewport().gui_get_focus_owner()
	print("settings focus: ", f)
	await _press(JOY_BUTTON_B)
	await get_tree().process_frame
	var still := false
	for c in menu.ui.get_children():
		if c is UIPanel and not c.is_queued_for_deletion():
			still = true
	print("B closed settings: ", not still)
	print("PAD TEST DONE ", "ok" if open and not still else "FAIL")
	get_tree().quit()
func _press(b: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	e.device = 0
	Input.parse_input_event(e)
	await get_tree().process_frame
	var r := InputEventJoypadButton.new()
	r.button_index = b
	r.pressed = false
	Input.parse_input_event(r)
	for i in 3:
		await get_tree().process_frame
