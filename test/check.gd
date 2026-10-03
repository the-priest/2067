extends Node
## Load every script so parse errors show up. Run: godot --headless --path . res://test/check.tscn
func _ready() -> void:
	var dirs := ["res://autoload", "res://world", "res://creatures", "res://player", "res://ui", "res://test"]
	for d in dirs:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				var s = load(d + "/" + f)
				if s == null:
					print("FAILED ", f)
	print("CHECK DONE")
	get_tree().quit()
