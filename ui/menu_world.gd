class_name MenuWorld
extends Node
## Stands in for the world on the title screen, so the animals there can
## breathe and look about without a valley under them.

var terrain := FlatGround.new()
var player: Node3D = null
var flora = null
var atmo = null
var creatures: Array = []
var herds: Dictionary = {}


class FlatGround:
	func height_at(_x: float, _z: float) -> float:
		return 0.0

	func normal_at(_x: float, _z: float) -> Vector3:
		return Vector3.UP

	func in_bounds(_x: float, _z: float, _m: float = 0.0) -> bool:
		return true
