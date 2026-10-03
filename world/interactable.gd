class_name Interactable
extends Node3D
## Something you can use: look at it, get close, press E.

var text := "Use"
var radius := 2.6
var hold := 0.0
var action: Callable


static func make(parent: Node, at: Vector3, label: String, act: Callable, r: float = 2.6) -> Interactable:
	var it := Interactable.new()
	it.text = label
	it.action = act
	it.radius = r
	parent.add_child(it)
	it.global_position = at
	it.add_to_group("interact")
	return it


func interact_pos() -> Vector3:
	return global_position


func interact_radius() -> float:
	return radius


func interact_hold() -> float:
	return hold


func interact_text() -> String:
	return text


func interact(p: Node) -> void:
	if action.is_valid():
		action.call(p)
