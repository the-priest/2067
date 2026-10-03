extends UIPanel
## Paused.


func panel_title() -> String:
	return "PAUSED"


func panel_size() -> Vector2:
	return Vector2(520, 460)


func build() -> void:
	get_tree().paused = false
	box.add_child(UIStyle.button("RESUME", close))
	box.add_child(UIStyle.button("SAVE GAME", func() -> void:
		Game.player_pos = world.player.global_position
		Game.save_game()
		Game.say("Saved.", UIStyle.GOOD)))
	box.add_child(UIStyle.button("SETTINGS", func() -> void:
		var s: Control = load("res://ui/settings_panel.gd").new()
		s.call("setup", world)
		get_parent().add_child(s)))
	box.add_child(UIStyle.button("FIELD GUIDE", func() -> void:
		var s: Control = load("res://ui/help.gd").new()
		s.call("setup", world)
		get_parent().add_child(s)))
	box.add_child(UIStyle.button("SAVE AND QUIT TO MENU", func() -> void:
		Game.player_pos = world.player.global_position
		Game.save_game()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://ui/main_menu.tscn")))
	box.add_child(UIStyle.button("QUIT TO DESKTOP", func() -> void:
		Game.player_pos = world.player.global_position
		Game.save_game()
		get_tree().quit()))
