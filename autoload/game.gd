extends Node
## The run: your money, rank, guns, gear, what you're carrying, what's on
## your wall, the contracts on the board, and the save file.

signal changed
signal toast(text: String, color: Color)
signal ranked_up(rank: int)

const SAVE := "user://hornfall_save.json"

var scrip := 0
var xp := 0
var weapons: Array = ["lever"]
var weapon := "lever"
var gear: Dictionary = {"binoculars": 1}
var ammo: Dictionary = {"30-30": 30}
var mag: Dictionary = {"lever": 6}
var carried: Array = [] # trophies on you: {kind, species, ...}
var wall: Array = [] # mounted horns: the best you kept
var sold_total := 0
var contracts: Array = []
var stats: Dictionary = {}
var log_entries: Array = [] # the hunting journal
var day := 1
var time_of_day := 7.0 # hours
var seed_world := 1945
var story := 0 # Mae's radio thread
var seen_species: Dictionary = {}
var legend_down := false
var scent_until := 0.0
var player_pos := Vector3.ZERO
var has_save := false
var camps: Dictionary = {} # discovered hunting camps


func _ready() -> void:
	_inputs()
	has_save = FileAccess.file_exists(SAVE)


func rank() -> int:
	return Catalog.rank_for(xp)


func capacity() -> int:
	if gear.has("pack4"):
		return 10
	if gear.has("pack3"):
		return 6
	if gear.has("pack2"):
		return 4
	return 2


func has(g: String) -> bool:
	return gear.has(g) and int(gear[g]) > 0


func scanner_level() -> int:
	if has("scanner3"):
		return 3
	if has("scanner2"):
		return 2
	if has("scanner1"):
		return 1
	return 0


func add_xp(n: int) -> void:
	var r0 := rank()
	xp += n
	var r1 := rank()
	if r1 > r0:
		ranked_up.emit(r1)
		say("RANK UP: %s" % Catalog.RANK_NAMES[r1 - 1], Color(1.0, 0.8, 0.35))
	changed.emit()


func add_scrip(n: int) -> void:
	scrip += n
	changed.emit()


func stat(k: String, n: int = 1) -> void:
	stats[k] = int(stats.get(k, 0)) + n


func say(t: String, c: Color = Color(0.92, 0.88, 0.8)) -> void:
	toast.emit(t, c)


func journal(t: String) -> void:
	log_entries.push_front("Day %d, %s  %s" % [day, clock(), t])
	while log_entries.size() > 60:
		log_entries.pop_back()


func clock() -> String:
	var h := int(time_of_day)
	var m := int((time_of_day - h) * 60.0)
	return "%02d:%02d" % [h, m]


func is_night() -> bool:
	return time_of_day < 5.5 or time_of_day > 20.5


# ---------------------------------------------------------------- trophies

## Value of a trophy at the trader.
func value_of(t: Dictionary) -> int:
	var sp: Dictionary = Catalog.SPECIES[t["species"]]
	if t["kind"] == "hide":
		return int(round(float(sp["hide"]) * Catalog.hide_mult(float(t["quality"]))))
	# Horns: by score, with a premium for the big classes.
	var s := float(t["score"])
	var mult := {"BRONZE": 1.0, "SILVER": 1.3, "GOLD": 1.8, "DIAMOND": 2.6, "MYTHIC": 4.0}
	return int(round(s * float(sp["horn_value"]) * float(mult.get(t["class"], 1.0))))


func carry(t: Dictionary) -> bool:
	if carried.size() >= capacity():
		return false
	carried.append(t)
	changed.emit()
	return true


func sell(i: int) -> int:
	if i < 0 or i >= carried.size():
		return 0
	var t: Dictionary = carried[i]
	var v := value_of(t)
	carried.remove_at(i)
	scrip += v
	sold_total += v
	stat("sold")
	_check_contracts_on_sell(t)
	changed.emit()
	return v


func mount(i: int) -> void:
	if i < 0 or i >= carried.size():
		return
	var t: Dictionary = carried[i]
	if t["kind"] != "horn":
		return
	carried.remove_at(i)
	wall.append(t)
	wall.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	# Mounting is prestige: a slice of the horn's worth as rank.
	add_xp(int(float(t["score"]) * 0.4))
	_check_contracts_on_sell(t)
	changed.emit()


func best_on_wall(species: String) -> float:
	var b := 0.0
	for t in wall:
		if t["species"] == species:
			b = maxf(b, float(t["score"]))
	return b


# ---------------------------------------------------------------- shop

func can_buy_weapon(w: String) -> String:
	var d: Dictionary = Catalog.WEAPONS[w]
	if weapons.has(w):
		return "owned"
	if rank() < int(d["rank"]):
		return "rank %d" % int(d["rank"])
	if scrip < int(d["price"]):
		return "need %d" % int(d["price"])
	return ""


func buy_weapon(w: String) -> bool:
	if can_buy_weapon(w) != "":
		return false
	var d: Dictionary = Catalog.WEAPONS[w]
	scrip -= int(d["price"])
	weapons.append(w)
	mag[w] = int(d["mag"])
	var a: String = d["ammo"]
	ammo[a] = int(ammo.get(a, 0)) + int(Catalog.AMMO[a]["pack"])
	weapon = w
	stat("guns")
	changed.emit()
	return true


func can_buy_gear(g: String) -> String:
	var d: Dictionary = Catalog.GEAR[g]
	if gear.has(g) and not d.has("uses"):
		return "owned"
	if d.has("needs") and not gear.has(d["needs"]):
		return "needs %s" % Catalog.GEAR[d["needs"]]["name"]
	if rank() < int(d["rank"]):
		return "rank %d" % int(d["rank"])
	if scrip < int(d["price"]):
		return "need %d" % int(d["price"])
	return ""


func buy_gear(g: String) -> bool:
	if can_buy_gear(g) != "":
		return false
	var d: Dictionary = Catalog.GEAR[g]
	scrip -= int(d["price"])
	gear[g] = int(gear.get(g, 0)) + int(d.get("uses", 1))
	changed.emit()
	return true


func buy_ammo(a: String) -> bool:
	var d: Dictionary = Catalog.AMMO[a]
	if scrip < int(d["price"]):
		return false
	scrip -= int(d["price"])
	ammo[a] = int(ammo.get(a, 0)) + int(d["pack"])
	changed.emit()
	return true


# ---------------------------------------------------------------- contracts

## Three jobs on the board at a time, matched to what you can handle.
func refresh_contracts() -> void:
	var r := rank()
	var pool: Array = []
	for k in Catalog.SPECIES.keys():
		var sp: Dictionary = Catalog.SPECIES[k]
		if bool(sp.get("legendary", false)):
			continue
		if int(sp["tier"]) <= 1 + int(r / 2.0):
			pool.append(k)
	while contracts.size() < 3 and not pool.is_empty():
		var sp_k: String = pool[randi() % pool.size()]
		var sp: Dictionary = Catalog.SPECIES[sp_k]
		var c := {}
		match randi() % 3:
			0:
				var q: float = [45.0, 70.0, 90.0][mini(2, randi() % (1 + int(r / 3.0)))]
				c = {"type": "hide", "species": sp_k, "min": q,
					"text": "%s hide, %s or better" % [sp["name"], Catalog.hide_grade(q)],
					"pay": int(float(sp["hide"]) * (1.2 + q / 60.0)), "xp": int(sp["xp"])}
			1:
				var s: float = float(sp["horn_len"]) * 100.0 * [0.85, 1.0, 1.1][mini(2, randi() % (1 + int(r / 3.0)))]
				if sp_k == "howler":
					s = 15.0
				c = {"type": "horn", "species": sp_k, "min": round(s),
					"text": "%s %s, score %d+" % [sp["name"], "fangs" if sp_k == "howler" else "horns", int(round(s))],
					"pay": int(s * float(sp["horn_value"]) * 1.2), "xp": int(sp["xp"]) * 2}
			_:
				c = {"type": "heart", "species": sp_k, "min": 0,
					"text": "One-shot heart kill on a %s" % sp["name"],
					"pay": int(float(sp["hide"]) * 2.5), "xp": int(sp["xp"]) * 2}
		var dup := false
		for o in contracts:
			if o["text"] == c["text"]:
				dup = true
		if not dup:
			contracts.append(c)
	changed.emit()


func _check_contracts_on_sell(t: Dictionary) -> void:
	for c in contracts.duplicate():
		if c["species"] != t["species"] or c["type"] != t["kind"]:
			continue
		if c["type"] == "hide" and float(t["quality"]) >= float(c["min"]) or c["type"] == "horn" and float(t["score"]) >= float(c["min"]):
			_complete(c)
			return


## A kill happened: heart-shot contracts finish on the spot.
func on_kill(species: String, heart: bool, shots: int) -> void:
	stat("kills")
	stat("kill_" + species)
	if heart and shots == 1:
		stat("heart_shots")
		for c in contracts.duplicate():
			if c["type"] == "heart" and c["species"] == species:
				_complete(c)
				return


func _complete(c: Dictionary) -> void:
	contracts.erase(c)
	scrip += int(c["pay"])
	stat("contracts")
	say("CONTRACT DONE  +%d scrip" % int(c["pay"]), Color(0.5, 1.0, 0.6))
	journal("Finished a contract: %s." % c["text"])
	add_xp(int(c["xp"]))
	refresh_contracts()


# ---------------------------------------------------------------- save

func new_game() -> void:
	scrip = 150
	xp = 0
	weapons = ["lever"]
	weapon = "lever"
	gear = {"binoculars": 1}
	ammo = {"30-30": 30}
	mag = {"lever": 6}
	carried = []
	wall = []
	sold_total = 0
	contracts = []
	stats = {}
	log_entries = []
	day = 1
	time_of_day = 6.5
	seed_world = 1945
	story = 0
	seen_species = {}
	legend_down = false
	scent_until = 0.0
	player_pos = Vector3.ZERO
	camps = {}
	refresh_contracts()
	journal("Grandpa's rifle, thirty rounds, and the trader's on the radio. Time to hunt.")


func save_game() -> void:
	var d := {
		"v": 1, "scrip": scrip, "xp": xp, "weapons": weapons, "weapon": weapon, "gear": gear,
		"ammo": ammo, "mag": mag, "carried": carried, "wall": wall, "sold_total": sold_total,
		"contracts": contracts, "stats": stats, "log": log_entries, "day": day,
		"time": time_of_day, "seed": seed_world, "story": story, "seen": seen_species,
		"legend_down": legend_down, "camps": camps, "pos": [player_pos.x, player_pos.y, player_pos.z],
	}
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d, "  "))
		has_save = true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE):
		return false
	var txt := FileAccess.get_file_as_string(SAVE)
	var d: Variant = JSON.parse_string(txt)
	if not (d is Dictionary):
		return false
	var s: Dictionary = d
	scrip = int(s.get("scrip", 0))
	xp = int(s.get("xp", 0))
	weapons = s.get("weapons", ["lever"])
	weapon = String(s.get("weapon", "lever"))
	gear = _ints(s.get("gear", {}))
	ammo = _ints(s.get("ammo", {}))
	mag = _ints(s.get("mag", {}))
	carried = s.get("carried", [])
	wall = s.get("wall", [])
	sold_total = int(s.get("sold_total", 0))
	contracts = s.get("contracts", [])
	stats = _ints(s.get("stats", {}))
	log_entries = s.get("log", [])
	day = int(s.get("day", 1))
	time_of_day = float(s.get("time", 8.0))
	seed_world = int(s.get("seed", 1945))
	story = int(s.get("story", 0))
	seen_species = s.get("seen", {})
	legend_down = bool(s.get("legend_down", false))
	camps = s.get("camps", {})
	var p: Array = s.get("pos", [0, 0, 0])
	player_pos = Vector3(float(p[0]), float(p[1]), float(p[2]))
	if contracts.size() < 3:
		refresh_contracts()
	changed.emit()
	return true


func _ints(d: Dictionary) -> Dictionary:
	var o := {}
	for k in d.keys():
		o[k] = int(d[k])
	return o


# ---------------------------------------------------------------- input

func _inputs() -> void:
	var keys := {
		"fwd": [KEY_W, KEY_UP], "back": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "crouch": [KEY_CTRL, KEY_Z], "use": [KEY_E], "reload": [KEY_R],
		"breath": [KEY_SHIFT], "thermal": [KEY_T], "cloak": [KEY_C], "drone": [KEY_G], "caller": [KEY_Q],
		"scent": [KEY_V], "map": [KEY_M], "journal": [KEY_J], "pause": [KEY_ESCAPE], "slot1": [KEY_1],
		"slot2": [KEY_2], "slot3": [KEY_3], "slot4": [KEY_4], "slot5": [KEY_5], "slot6": [KEY_6],
		"flash": [KEY_F], "help": [KEY_F1], "binos": [KEY_B], "inv": [KEY_TAB, KEY_I],
	}
	for a in keys.keys():
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in keys[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
	for a in ["fire", "aim"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
	var m1 := InputEventMouseButton.new()
	m1.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire", m1)
	var m2 := InputEventMouseButton.new()
	m2.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("aim", m2)
	# Controller, laid out like the big hunting games: sticks move and look,
	# triggers aim and fire, bumpers breath and next gun, d-pad gear.
	var axes := {"fire": [JOY_AXIS_TRIGGER_RIGHT, 1.0], "aim": [JOY_AXIS_TRIGGER_LEFT, 1.0],
		"fwd": [JOY_AXIS_LEFT_Y, -1.0], "back": [JOY_AXIS_LEFT_Y, 1.0], "left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0],
		"look_up": [JOY_AXIS_RIGHT_Y, -1.0], "look_down": [JOY_AXIS_RIGHT_Y, 1.0], "look_left": [JOY_AXIS_RIGHT_X, -1.0], "look_right": [JOY_AXIS_RIGHT_X, 1.0]}
	for a in axes.keys():
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.2)
		var ja := InputEventJoypadMotion.new()
		ja.axis = axes[a][0]
		ja.axis_value = axes[a][1]
		InputMap.action_add_event(a, ja)
	var btn := {"jump": JOY_BUTTON_A, "use": JOY_BUTTON_X, "reload": JOY_BUTTON_Y, "pad_crouch": JOY_BUTTON_B,
		"sprint": JOY_BUTTON_LEFT_STICK, "pause": JOY_BUTTON_START, "map": JOY_BUTTON_BACK,
		"breath": JOY_BUTTON_LEFT_SHOULDER, "next_gun": JOY_BUTTON_RIGHT_SHOULDER, "pad_mod": JOY_BUTTON_LEFT_SHOULDER,
		"binos": JOY_BUTTON_DPAD_UP, "flash": JOY_BUTTON_DPAD_DOWN, "caller": JOY_BUTTON_DPAD_LEFT, "scent": JOY_BUTTON_DPAD_RIGHT,
		"thermal": JOY_BUTTON_RIGHT_STICK}
	for a in btn.keys():
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		var jb := InputEventJoypadButton.new()
		jb.button_index = btn[a]
		InputMap.action_add_event(a, jb)
	var nk := InputEventKey.new()
	nk.physical_keycode = KEY_X
	InputMap.action_add_event("next_gun", nk)


## Was the last thing pressed on a controller? (for the button hints)
var using_pad := false


func _input(e: InputEvent) -> void:
	if e is InputEventJoypadButton or e is InputEventJoypadMotion and absf((e as InputEventJoypadMotion).axis_value) > 0.4:
		using_pad = true
	elif e is InputEventKey or e is InputEventMouseButton or e is InputEventMouseMotion and (e as InputEventMouseMotion).relative.length() > 2.0:
		using_pad = false


## The right button name for the device in use.
func key(action: String) -> String:
	var pad := {"use": "X", "reload": "Y", "jump": "A", "pause": "START", "map": "BACK", "binos": "D-UP", "caller": "D-LEFT",
		"scent": "D-RIGHT", "flash": "D-DOWN", "thermal": "R3", "breath": "LB", "next_gun": "RB", "aim": "LT", "fire": "RT",
		"cloak": "LB+B", "drone": "LB+A", "crouch": "B", "sprint": "L3", "journal": "BACK", "help": "BACK"}
	var kb := {"use": "E", "reload": "R", "jump": "SPACE", "pause": "ESC", "map": "M", "binos": "B", "caller": "Q", "scent": "V",
		"flash": "F", "thermal": "T", "breath": "SHIFT", "next_gun": "X", "aim": "RMB", "fire": "LMB", "cloak": "C", "drone": "G",
		"crouch": "CTRL", "sprint": "SHIFT", "journal": "J", "help": "F1"}
	return String((pad if using_pad else kb).get(action, action.to_upper()))


func rumble(weak: float, strong: float, t: float) -> void:
	if using_pad and Settings.rumble:
		for d in Input.get_connected_joypads():
			Input.start_joy_vibration(d, weak, strong, t)
