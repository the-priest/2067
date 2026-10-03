class_name Carcass
extends RefCounted
## A dead animal, as something you can use: hold E to skin it and take the horns.

var c: Creature
var world: Node


static func of(cr: Creature, w: Node) -> Carcass:
	if cr.has_meta("carcass"):
		return cr.get_meta("carcass")
	var k := Carcass.new()
	k.c = cr
	k.world = w
	cr.set_meta("carcass", k)
	return k


func interact_pos() -> Vector3:
	return c.center()


func interact_radius() -> float:
	return 2.5 + float(c.sp["body"]["len"]) * c.size * 0.5


func interact_hold() -> float:
	return 2.4 if not c.legendary else 4.0


func interact_text() -> String:
	var parts := []
	if not c.harvested_hide:
		parts.append("hide: %s" % Catalog.hide_grade(c.hide_q))
	if not c.harvested_horn:
		parts.append("%s: %.1f %s" % ["fangs" if c.species == "howler" else "horns", float(c.horn["score"]), Catalog.horn_class(float(c.horn["score"]), c.species)])
	return "Harvest %s  (%s)" % [c.name_text(), ", ".join(parts)]


func interact(_p: Node) -> void:
	world.harvest(c)
