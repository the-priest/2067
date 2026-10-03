class_name Catalog
extends RefCounted
## Everything the game knows about: the hybrids, the guns, the gear, the
## ranks. Plain data; the systems read it.

## The hybrids. Each one is something the Visitors bred into an Earth animal.
## body: torso length / height / width (m) and leg length; horn: the horn
## kind the builder grows; heart_zone: where in the torso its heart can sit
## (fractions of the torso, front = -1, back = +1), every animal different.
const SPECIES := {
	"moorhorn": {
		"name": "Moorhorn",
		"latin": "Bos visitans",
		"blurb": "Cattle the Visitors got to first. Slow, heavy, gentle until it isn't. Its horns sweep out like a longhorn's and spiral at the tips; the ridge along its back glows teal when it's calm.",
		"tier": 1, "hp": 220.0, "speed": 2.0, "run": 9.0, "mass": 700.0,
		"body": {"len": 2.3, "h": 1.15, "w": 0.95, "leg": 0.75, "neck": 0.55, "head": 0.6},
		"fur": Color(0.36, 0.27, 0.2), "belly": Color(0.62, 0.55, 0.45), "glow": Color(0.2, 1.0, 0.85),
		"pattern": "ridge", "horn": "sweep", "horn_len": 1.2, "horn_r": 0.11,
		"heart_zone": [-0.75, 0.55], "heart_r": 0.2,
		"temper": "docile", "herd": [3, 7], "sight": 70.0, "hearing": 1.0, "smell": 1.0,
		"habitat": "fields", "hide": 70, "horn_value": 1.6, "xp": 40,
		"call": "moo",
	},
	"stagwraith": {
		"name": "Stagwraith",
		"latin": "Cervus spectralis",
		"blurb": "Whitetail crossed with something that sees in the dark. Skittish, quick, ears like satellite dishes. The antlers grow crystal tines that hum in the wind.",
		"tier": 1, "hp": 140.0, "speed": 2.4, "run": 15.0, "mass": 120.0,
		"body": {"len": 1.5, "h": 0.8, "w": 0.55, "leg": 1.0, "neck": 0.65, "head": 0.42},
		"fur": Color(0.5, 0.37, 0.25), "belly": Color(0.85, 0.8, 0.72), "glow": Color(0.55, 0.75, 1.0),
		"pattern": "spots", "horn": "antler", "horn_len": 0.85, "horn_r": 0.05,
		"heart_zone": [-0.85, 0.7], "heart_r": 0.13,
		"temper": "skittish", "herd": [2, 5], "sight": 95.0, "hearing": 1.8, "smell": 1.3,
		"habitat": "forest", "hide": 55, "horn_value": 2.0, "xp": 45,
		"call": "bugle",
	},
	"tuskmaw": {
		"name": "Tuskmaw",
		"latin": "Sus furiosus",
		"blurb": "Wild boar with a second jaw and a temper. It doesn't run from you. Its tusks curl up past its eyes and a crown of short horns rings its skull.",
		"tier": 2, "hp": 260.0, "speed": 2.2, "run": 11.0, "mass": 260.0,
		"body": {"len": 1.6, "h": 0.85, "w": 0.75, "leg": 0.5, "neck": 0.3, "head": 0.55},
		"fur": Color(0.2, 0.17, 0.15), "belly": Color(0.32, 0.27, 0.23), "glow": Color(1.0, 0.45, 0.15),
		"pattern": "bristle", "horn": "tusk", "horn_len": 0.6, "horn_r": 0.07,
		"heart_zone": [-0.6, 0.4], "heart_r": 0.15,
		"temper": "aggressive", "herd": [2, 4], "sight": 50.0, "hearing": 1.2, "smell": 2.0,
		"habitat": "scrub", "hide": 90, "horn_value": 2.2, "xp": 70,
		"call": "grunt",
	},
	"ramspire": {
		"name": "Ramspire",
		"latin": "Ovis helicis",
		"blurb": "Bighorn sheep from the ridges, where the ships came down. Eyes like a hawk's. Its horns coil in a perfect double spiral, ribbed and iridescent: the trophy every hunter in the valley wants on their wall.",
		"tier": 2, "hp": 170.0, "speed": 2.0, "run": 13.0, "mass": 140.0,
		"body": {"len": 1.4, "h": 0.85, "w": 0.65, "leg": 0.65, "neck": 0.4, "head": 0.42},
		"fur": Color(0.55, 0.47, 0.37), "belly": Color(0.86, 0.82, 0.74), "glow": Color(0.9, 0.5, 1.0),
		"pattern": "saddle", "horn": "spiral", "horn_len": 1.1, "horn_r": 0.09,
		"heart_zone": [-0.8, 0.6], "heart_r": 0.13,
		"temper": "skittish", "herd": [2, 6], "sight": 160.0, "hearing": 1.1, "smell": 1.0,
		"habitat": "ridges", "hide": 80, "horn_value": 3.0, "xp": 80,
		"call": "bleat",
	},
	"crownelk": {
		"name": "Crownelk",
		"latin": "Alces coronatus",
		"blurb": "A moose the size of a truck, with an antler crown wider than you are tall. Every tine ends in a glowing bead. At night it gets territorial.",
		"tier": 3, "hp": 420.0, "speed": 2.2, "run": 12.0, "mass": 650.0,
		"body": {"len": 2.4, "h": 1.3, "w": 0.95, "leg": 1.25, "neck": 0.7, "head": 0.75},
		"fur": Color(0.24, 0.19, 0.15), "belly": Color(0.36, 0.3, 0.24), "glow": Color(0.6, 1.0, 0.35),
		"pattern": "stripes", "horn": "palmate", "horn_len": 1.5, "horn_r": 0.09,
		"heart_zone": [-0.8, 0.65], "heart_r": 0.22,
		"temper": "territorial", "herd": [1, 3], "sight": 80.0, "hearing": 1.3, "smell": 1.6,
		"habitat": "marsh", "hide": 150, "horn_value": 3.4, "xp": 140,
		"call": "bellow",
	},
	"howler": {
		"name": "Howler",
		"latin": "Canis ululans",
		"blurb": "Wolves that took in something hungry. They hunt in packs, mostly at night, and they hunt you. No horns: just the pelt and the bone-white fangs.",
		"tier": 2, "hp": 110.0, "speed": 3.0, "run": 14.0, "mass": 60.0,
		"body": {"len": 1.15, "h": 0.6, "w": 0.42, "leg": 0.6, "neck": 0.3, "head": 0.4},
		"fur": Color(0.3, 0.3, 0.32), "belly": Color(0.55, 0.55, 0.56), "glow": Color(1.0, 0.15, 0.25),
		"pattern": "stripes", "horn": "fang", "horn_len": 0.18, "horn_r": 0.03,
		"heart_zone": [-0.7, 0.4], "heart_r": 0.1,
		"temper": "predator", "herd": [3, 5], "sight": 90.0, "hearing": 1.5, "smell": 2.4,
		"habitat": "any", "hide": 60, "horn_value": 1.0, "xp": 50,
		"call": "howl",
	},
	"ironcrown": {
		"name": "Ironcrown",
		"latin": "Bison rex",
		"blurb": "The legend of the crash basin: a bison grown to the size of a barn, two hearts beating somewhere in it, horns like iron girders. Nobody who's seen it up close has a mounted head to show for it.",
		"tier": 4, "hp": 1600.0, "speed": 2.0, "run": 10.0, "mass": 2400.0,
		"body": {"len": 3.6, "h": 2.0, "w": 1.6, "leg": 1.0, "neck": 0.6, "head": 1.0},
		"fur": Color(0.17, 0.13, 0.11), "belly": Color(0.28, 0.22, 0.18), "glow": Color(1.0, 0.85, 0.3),
		"pattern": "ridge", "horn": "crown", "horn_len": 2.0, "horn_r": 0.2,
		"heart_zone": [-0.85, 0.75], "heart_r": 0.28, "hearts": 2,
		"temper": "territorial", "herd": [1, 1], "sight": 70.0, "hearing": 1.0, "smell": 1.5,
		"habitat": "basin", "hide": 900, "horn_value": 6.0, "xp": 900,
		"call": "bellow", "legendary": true,
	},
}

## The guns, from Grandpa's lever gun to a rail gun pulled out of a wreck.
## vel: muzzle velocity (m/s), dmg at the muzzle, hide: how badly a hole
## from it marks a hide, noise: how far the shot carries (m), zoom: scope
## magnifications (empty = iron sights).
const WEAPONS := {
	"lever": {
		"name": "Grandpa's .30-30", "desc": "Lever action. Iron sights, six in the tube. It got your family through the first winter.",
		"rank": 1, "price": 0, "dmg": 70.0, "vel": 640.0, "mag": 6, "reload": 0.55, "per_round": true,
		"rof": 0.75, "hide": 12.0, "noise": 420.0, "zoom": [], "spread": 0.0016, "ammo": "30-30",
		"sound": "rifle", "kind": "lever",
	},
	"bolt": {
		"name": "Ranch .308", "desc": "Bolt action with a 4x scope. Flat, honest and accurate past three hundred.",
		"rank": 2, "price": 900, "dmg": 92.0, "vel": 820.0, "mag": 5, "reload": 2.4,
		"rof": 1.2, "hide": 12.0, "noise": 480.0, "zoom": [4.0], "spread": 0.0007, "ammo": "308",
		"sound": "rifle", "kind": "bolt",
	},
	"thumper": {
		"name": "Thumper .45-70", "desc": "Big bore for big animals. Hits like a truck, tears like one too. 6x scope.",
		"rank": 3, "price": 2100, "dmg": 150.0, "vel": 610.0, "mag": 4, "reload": 2.8,
		"rof": 1.4, "hide": 22.0, "noise": 560.0, "zoom": [6.0], "spread": 0.0009, "ammo": "45-70",
		"sound": "big", "kind": "bolt",
	},
	"coil": {
		"name": "Whisper Coil Rifle", "desc": "Salvaged Visitor tech. Magnetic, near silent, needle-thin holes. Herds don't even look up. 8x scope.",
		"rank": 5, "price": 5200, "dmg": 115.0, "vel": 1500.0, "mag": 8, "reload": 2.0,
		"rof": 0.6, "hide": 4.0, "noise": 45.0, "zoom": [4.0, 8.0], "spread": 0.0004, "ammo": "needles",
		"sound": "coil", "kind": "coil",
	},
	"plasma": {
		"name": "Helix Plasma Lance", "desc": "A slow, burning bolt of plasma. Drops anything, cooks the hide. Use it when the hide doesn't matter and the animal does.",
		"rank": 7, "price": 9800, "dmg": 260.0, "vel": 260.0, "mag": 3, "reload": 3.0, "drop": 0.0,
		"rof": 1.5, "hide": 38.0, "noise": 300.0, "zoom": [3.0], "spread": 0.0012, "ammo": "cells",
		"sound": "plasma", "kind": "plasma", "burn": true, "splash": 1.4,
	},
	"rail": {
		"name": "Skypiercer Rail", "desc": "The gun that brought down a Visitor scout. Goes straight through anything, at any range. 6-16x variable scope.",
		"rank": 9, "price": 22000, "dmg": 330.0, "vel": 5000.0, "mag": 2, "reload": 3.6,
		"rof": 2.0, "hide": 8.0, "noise": 650.0, "zoom": [6.0, 10.0, 16.0], "spread": 0.0002, "ammo": "slugs",
		"sound": "rail", "kind": "rail", "pierce": true,
	},
}

const AMMO := {
	"30-30": {"name": ".30-30 rounds", "pack": 20, "price": 40},
	"308": {"name": ".308 rounds", "pack": 20, "price": 70},
	"45-70": {"name": ".45-70 rounds", "pack": 12, "price": 110},
	"needles": {"name": "Coil needles", "pack": 24, "price": 160},
	"cells": {"name": "Plasma cells", "pack": 6, "price": 240},
	"slugs": {"name": "Rail slugs", "pack": 6, "price": 380},
}

## Gear. Some is one-off kit, some you use up (uses).
const GEAR := {
	"binoculars": {"name": "Binoculars", "desc": "Glass from before the Fall. Right mouse to look. Shows species at a glance.", "rank": 1, "price": 0},
	"rangefinder": {"name": "Rangefinder", "desc": "Adds range in metres to your binoculars and scope.", "rank": 1, "price": 180},
	"wind": {"name": "Wind Gauge", "desc": "A ribbon on your sleeve, and a needle on your compass. Animals downwind smell you.", "rank": 1, "price": 120},
	"pack2": {"name": "Hauler's Pack", "desc": "Carry 4 trophies instead of 2.", "rank": 2, "price": 450},
	"tracker": {"name": "Bio-Tracker Visor", "desc": "Hybrid blood glows through it, and so do fresh tracks. Never lose a wounded animal again.", "rank": 2, "price": 800},
	"scanner1": {"name": "Heart Scanner Mk I", "desc": "Their hearts aren't where they should be. This shows roughly where, when you're scoped in under 120 m.", "rank": 2, "price": 1300},
	"scent": {"name": "Scent Mask", "desc": "Spray. Five minutes where nothing smells you.", "rank": 2, "price": 70, "uses": 1},
	"caller": {"name": "Hybrid Caller", "desc": "Blows a call they can't ignore. Animals nearby come to look.", "rank": 3, "price": 950},
	"pack3": {"name": "Frame Pack", "desc": "Carry 6 trophies.", "rank": 3, "price": 1500, "needs": "pack2"},
	"scanner2": {"name": "Heart Scanner Mk II", "desc": "Exact heart, lungs too, out to 300 m.", "rank": 4, "price": 3800, "needs": "scanner1"},
	"thermal": {"name": "Thermal Optic", "desc": "T while scoped: hybrid hearts burn white-hot through hide, day or night.", "rank": 5, "price": 3200},
	"cloak": {"name": "Phase Cloak", "desc": "Visitor cloth that bends light. C to wear: animals see you at a third of the distance while it charges down.", "rank": 6, "price": 6800},
	"scanner3": {"name": "Heart Scanner Mk III", "desc": "Every vital, both hearts on anything that has two, out to 600 m.", "rank": 6, "price": 8200, "needs": "scanner2"},
	"pack4": {"name": "Grav Sled", "desc": "Carry 10 trophies. It floats behind you.", "rank": 7, "price": 7500, "needs": "pack3"},
	"drone": {"name": "Recon Drone", "desc": "G: send it up, fly it, and it tags every hybrid it sees for a minute.", "rank": 7, "price": 7200},
}

## Hunter ranks: XP needed for each.
const RANKS := [0, 150, 450, 1000, 1900, 3200, 5000, 7500, 11000, 16000]
const RANK_NAMES := ["Farmhand", "Stalker", "Tracker", "Skinner", "Horn Hunter", "Ridge Runner", "Visitor-Slayer", "Crown Taker", "Wraith Walker", "Legend of the Valley"]

## Trophy classes from the horn score.
static func horn_class(score: float, species: String) -> String:
	var base := float(SPECIES[species].get("horn_len", 1.0)) * 100.0
	var r := score / maxf(base, 1.0)
	if r >= 1.45:
		return "MYTHIC"
	if r >= 1.25:
		return "DIAMOND"
	if r >= 1.08:
		return "GOLD"
	if r >= 0.9:
		return "SILVER"
	return "BRONZE"


static func class_color(c: String) -> Color:
	match c:
		"MYTHIC":
			return Color(1.0, 0.35, 0.9)
		"DIAMOND":
			return Color(0.55, 0.95, 1.0)
		"GOLD":
			return Color(1.0, 0.8, 0.3)
		"SILVER":
			return Color(0.8, 0.82, 0.86)
	return Color(0.8, 0.55, 0.35)


static func hide_grade(q: float) -> String:
	if q >= 90.0:
		return "PRISTINE"
	if q >= 70.0:
		return "FINE"
	if q >= 45.0:
		return "FAIR"
	if q >= 20.0:
		return "POOR"
	return "RUINED"


static func hide_mult(q: float) -> float:
	if q >= 90.0:
		return 1.6
	if q >= 70.0:
		return 1.0
	if q >= 45.0:
		return 0.6
	if q >= 20.0:
		return 0.3
	return 0.08


static func rank_for(xp: int) -> int:
	var r := 1
	for i in RANKS.size():
		if xp >= int(RANKS[i]):
			r = i + 1
	return r
