class_name Farm
extends Node3D
## Keeping the farm alive. A wall rings the yard, turrets watch it, lights
## burn at night. Every few nights the ghouls come, a couple at first, more
## as your name grows, as the farm grows, as the wall of horns grows.
## Something is drawing them. Build more: the workbench in the barn sells
## walls, turrets, spikes, lights, and (once Xyla's here) Tesla towers and
## a shield dome. It all runs whether you're home or not.

const R := 44.0 # the wall's radius
const TURRET_SLOTS := 6

var world: Node
var terrain: Terrain
var center := Vector3.ZERO
var wall_root: Node3D
var turrets: Array = []
var teslas: Array = []
var shield: MeshInstance3D = null
var lights: Array = []
var raid_on := false
var raid_ghouls: Array = []
var _raid_check := 0.0
var _breach_msg := 0.0
var _spike_t := 0.0
var _tesla_t := 0.0
var _rng := RandomNumberGenerator.new()


const UPGRADES := {
	"wall": {"name": "Wall", "levels": [0, 600, 1600, 3500], "desc": "Stakes, then scrap steel, then concrete and wire. More of it to tear through.", "hp": [200, 400, 700, 1100]},
	"turrets": {"name": "Auto-turret", "levels": [0, 400, 800, 1400, 2200, 3200], "desc": "Pre-war sentry guns, rewired. Each one watches its own stretch of wall."},
	"lights": {"name": "Floodlights", "levels": [0, 300, 900], "desc": "Turrets see further at night, and ghouls hate the light."},
	"spikes": {"name": "Spike trench", "levels": [0, 350, 900], "desc": "Anything clawing at the wall bleeds for it.", "start": 0},
	"tesla": {"name": "Xhuul Tesla tower", "levels": [0, 2500, 5000], "desc": "Xyla's design. Arcs lightning through everything near the wall.", "needs_xyla": true, "start": 0},
	"shield": {"name": "Shield dome", "levels": [0, 7000], "desc": "The same shields that won the war. Halves the damage to the wall.", "needs_xyla": true, "rank": 7, "start": 0},
}


func setup(w: Node, t: Terrain) -> void:
	world = w
	terrain = t
	_rng.randomize()
	center = Vector3(Terrain.FARM.x + 14.0, 0, Terrain.FARM.y - 4.0)
	center.y = terrain.height_at(center.x, center.z)
	if Game.defense.is_empty():
		Game.defense = {"wall": 1, "turrets": 1, "lights": 1, "spikes": 0, "tesla": 0, "shield": 0}
		Game.wall_hp = max_wall()
	rebuild()


func level(k: String) -> int:
	return int(Game.defense.get(k, 0))


func max_wall() -> float:
	var hp: Array = UPGRADES["wall"]["hp"]
	return float(hp[clampi(level("wall") - 1, 0, hp.size() - 1)])


func core() -> Vector3:
	return world.structures.farm_spawn


## The cost of the next level, or "" reasons it can't be bought.
func next_cost(k: String) -> int:
	var lv: Array = UPGRADES[k]["levels"]
	var l := level(k)
	if l >= lv.size():
		return -1
	var c := int(lv[l])
	if Game.xyla:
		c = int(c * 0.8) # Xyla knows a guy. The guy is her.
	return c


func why_not(k: String) -> String:
	var u: Dictionary = UPGRADES[k]
	var c := next_cost(k)
	if c < 0:
		return "maxed"
	if bool(u.get("needs_xyla", false)) and not Game.xyla:
		return "needs an alien engineer"
	if Game.rank() < int(u.get("rank", 0)):
		return "rank %d" % int(u["rank"])
	if Game.scrip < c:
		return "need %d" % c
	return ""


func buy(k: String) -> bool:
	if why_not(k) != "":
		return false
	Game.scrip -= next_cost(k)
	Game.defense[k] = level(k) + 1
	if k == "wall":
		Game.wall_hp = max_wall()
	Game.stat("defenses")
	Game.changed.emit()
	rebuild()
	return true


func repair_cost() -> int:
	return int(ceil(max_wall() - Game.wall_hp))


func repair() -> bool:
	var c := repair_cost()
	if c <= 0 or Game.scrip < c:
		return false
	Game.scrip -= c
	Game.wall_hp = max_wall()
	Game.changed.emit()
	rebuild()
	return true


# ---------------------------------------------------------------- building

func rebuild() -> void:
	if wall_root != null:
		wall_root.queue_free()
	for t in turrets:
		(t as Node).queue_free()
	for t in teslas:
		(t as Node).queue_free()
	for l in lights:
		(l as Node).queue_free()
	turrets.clear()
	teslas.clear()
	lights.clear()
	if shield != null:
		shield.queue_free()
		shield = null
	wall_root = Node3D.new()
	add_child(wall_root)
	_wall()
	for i in mini(level("turrets"), TURRET_SLOTS):
		var a := TAU * (float(i) / TURRET_SLOTS) + 0.3
		turrets.append(_turret(_ring(a, -2.5)))
	for i in level("lights") * 2:
		var a2 := TAU * (float(i) / maxf(1.0, float(level("lights") * 2))) + 0.9
		lights.append(_light(_ring(a2, -3.5)))
	for i in level("tesla") * 2:
		var a3 := TAU * (float(i) / maxf(1.0, float(level("tesla") * 2))) + 1.6
		teslas.append(_tesla(_ring(a3, -4.0)))
	if level("shield") > 0:
		shield = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = R + 6.0
		sm.height = (R + 6.0) * 1.2
		shield.mesh = sm
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.4, 0.9, 1.0, 0.06)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.rim_enabled = true
		shield.material_override = m
		add_child(shield)
		shield.global_position = center


func _ring(a: float, inset: float = 0.0) -> Vector3:
	var p := center + Vector3(cos(a) * (R + inset), 0, sin(a) * (R + inset))
	p.y = terrain.height_at(p.x, p.z)
	return p


## Is the gate here? (south, toward the road)
func _gate(a: float) -> bool:
	var gate_a := atan2(Terrain.FARM.y + 75.0 - center.z, Terrain.FARM.x - center.x)
	return absf(wrapf(a - gate_a, -PI, PI)) < 0.07


func _wall() -> void:
	var k := MeshKit.new()
	var lv := level("wall")
	var broken := Game.wall_hp <= 0.0
	var dmg := 1.0 - Game.wall_hp / maxf(max_wall(), 1.0)
	var n := 96
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = Tex.get_tex("rust") if lv >= 2 else Tex.get_tex("wood")
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.6, 0.6, 0.6)
	mat.roughness = 0.85
	var body := StaticBody3D.new()
	body.collision_layer = 1
	wall_root.add_child(body)
	for i in n:
		var a := TAU * float(i) / n
		if _gate(a):
			continue
		var p := _ring(a)
		var nx := _ring(TAU * float(i + 1) / n)
		var seg := p.distance_to(nx)
		# Damage shows as gaps and slumped sections.
		var hurt := broken and (i * 7) % 5 < 3 or dmg > 0.3 and (i * 13) % 7 == 0
		var hgt: float = [2.2, 2.6, 3.0, 3.4][clampi(lv - 1, 0, 3)] * (0.35 if hurt else 1.0)
		var mid := (p + nx) * 0.5
		var b := Basis(Vector3.UP, -a + PI * 0.5)
		match lv:
			1:
				for j in 4:
					var sp := p.lerp(nx, (j + 0.5) / 4.0)
					k.cyl(sp + Vector3(0, -0.4, 0), sp + Vector3(randf_range(-0.05, 0.05), hgt, 0), 0.11, 0.06, 5, Color(0.4, 0.32, 0.22))
				k.box(mid + Vector3(0, hgt * 0.45, 0), Vector3(seg, 0.12, 0.1), Color(0.35, 0.28, 0.2), b)
			2:
				k.box(mid + Vector3(0, hgt * 0.5 - 0.3, 0), Vector3(seg + 0.1, hgt + 0.6, 0.08), Color(0.5, 0.42, 0.36).darkened(randf() * 0.2), b * Basis(Vector3.FORWARD, randf_range(-0.04, 0.04)))
			_:
				k.box(mid + Vector3(0, hgt * 0.5 - 0.4, 0), Vector3(seg + 0.05, hgt + 0.8, 0.45), Color(0.52, 0.5, 0.47), b)
				k.cyl(mid + Vector3(0, hgt + 0.25, 0) - b.x * seg * 0.5, mid + Vector3(0, hgt + 0.25, 0) + b.x * seg * 0.5, 0.06, 0.06, 5, Color(0.25, 0.23, 0.2), false)
		if not hurt:
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(seg + 0.2, hgt + 1.0, 0.5)
			cs.shape = bs
			cs.transform = Transform3D(b, mid + Vector3(0, hgt * 0.5, 0))
			body.add_child(cs)
	if level("spikes") > 0:
		for i in n * 2:
			var a2 := TAU * float(i) / (n * 2)
			if _gate(a2):
				continue
			var sp2 := _ring(a2, 2.0)
			var out := (sp2 - center).normalized()
			k.cyl(sp2, sp2 + (out + Vector3(0, 1.2, 0)).normalized() * 1.1, 0.05, 0.005, 4, Color(0.3, 0.26, 0.22), false)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.material_override = mat
	wall_root.add_child(mi)


func _turret(at: Vector3) -> Node3D:
	var t := Node3D.new()
	add_child(t)
	t.global_position = at
	var k := MeshKit.new()
	for a in 3:
		var ang := TAU * a / 3.0
		k.cyl(Vector3(cos(ang) * 0.9, -0.3, sin(ang) * 0.9), Vector3(0, 3.2, 0), 0.06, 0.05, 5, Color(0.3, 0.3, 0.3))
	k.cyl(Vector3(0, 3.0, 0), Vector3(0, 3.35, 0), 0.6, 0.6, 10, Color(0.25, 0.25, 0.27))
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.material_override = _metal()
	t.add_child(mi)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 3.7, 0)
	t.add_child(head)
	var hk := MeshKit.new()
	hk.box(Vector3(0, 0, 0), Vector3(0.7, 0.5, 0.9), Color(0.32, 0.34, 0.3))
	for s: float in [-1.0, 1.0]:
		hk.cyl(Vector3(s * 0.15, 0.0, -0.4), Vector3(s * 0.15, 0.0, -1.3), 0.05, 0.045, 6, Color(0.1, 0.1, 0.1))
	hk.tag = Vector2(1, 0)
	hk.box(Vector3(0, 0.1, -0.46), Vector3(0.2, 0.08, 0.02), Color(1.0, 0.2, 0.1))
	var hm := MeshInstance3D.new()
	hm.mesh = hk.commit()
	hm.material_override = _metal()
	head.add_child(hm)
	t.set_meta("cool", 0.0)
	return t


func _light(at: Vector3) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	n.global_position = at
	var k := MeshKit.new()
	k.cyl(Vector3(0, -0.3, 0), Vector3(0, 6.0, 0), 0.08, 0.06, 6, Color(0.3, 0.3, 0.3))
	k.box(Vector3(0, 6.1, 0), Vector3(0.6, 0.4, 0.3), Color(0.2, 0.2, 0.2))
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.material_override = _metal()
	n.add_child(mi)
	var sl := SpotLight3D.new()
	sl.light_energy = 6.0
	sl.spot_range = 55.0
	sl.spot_angle = 40.0
	sl.light_color = Color(1.0, 0.95, 0.85)
	n.add_child(sl)
	sl.position = Vector3(0, 6.0, 0)
	sl.look_at_from_position(sl.global_position, at + (at - center).normalized() * 25.0, Vector3.UP)
	n.set_meta("light", sl)
	return n


func _tesla(at: Vector3) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	n.global_position = at
	var k := MeshKit.new()
	k.tube(PackedVector3Array([Vector3(0, -0.3, 0), Vector3(0, 3.0, 0), Vector3(0, 5.0, 0)]), PackedFloat32Array([0.5, 0.25, 0.15]), 8, Color(0.15, 0.15, 0.2), false)
	k.tag = Vector2(1, 0)
	k.blob(Vector3(0, 5.4, 0), Vector3.ONE * 0.6, Color(0.45, 0.95, 1.0), 8, 10)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true
	m.emission = Color(0.3, 0.8, 1.0)
	m.emission_energy_multiplier = 0.6
	mi.material_override = m
	n.add_child(mi)
	return n


static var _metal_mat: StandardMaterial3D = null


func _metal() -> StandardMaterial3D:
	if _metal_mat == null:
		_metal_mat = StandardMaterial3D.new()
		_metal_mat.vertex_color_use_as_albedo = true
		_metal_mat.metallic = 0.6
		_metal_mat.roughness = 0.5
		_metal_mat.albedo_texture = Tex.get_tex("rust")
	return _metal_mat


# ---------------------------------------------------------------- the wall

## A ghoul heading for 'to' has reached the standing wall.
func blocks(pos: Vector3, to: Vector3) -> bool:
	if Game.wall_hp <= 0.0:
		return false
	var dp := Vector2(pos.x - center.x, pos.z - center.z).length()
	var dt := Vector2(to.x - center.x, to.z - center.z).length()
	return dp < R + 1.6 and dp > R - 1.0 and dt < R


func hit_wall(d: float, at: Vector3) -> void:
	if level("shield") > 0:
		d *= 0.5
	var was := Game.wall_hp
	Game.wall_hp = maxf(0.0, Game.wall_hp - d)
	Sfx.play_at("thud", at + Vector3(0, 1, 0), -2.0, 50.0, randf_range(0.7, 0.9))
	if was > 0.0 and Game.wall_hp <= 0.0:
		Game.say("THE WALL IS DOWN. They're in the yard!", UIStyle.BAD)
		Game.journal("The ghouls broke through the wall.")
		rebuild()
	elif int(was / (max_wall() * 0.25)) != int(Game.wall_hp / (max_wall() * 0.25)):
		rebuild()


## Ghouls in the yard: they wreck what they can reach and carry off scrip.
func breach(d: float) -> void:
	var lost := mini(Game.scrip, int(d * 2.0))
	Game.scrip -= lost
	if Time.get_ticks_msec() / 1000.0 > _breach_msg:
		_breach_msg = Time.get_ticks_msec() / 1000.0 + 12.0
		Game.say("Ghouls are wrecking the farm! -%d scrip and counting" % lost, UIStyle.BAD)
	Game.changed.emit()


# ---------------------------------------------------------------- raids

func _process(dt: float) -> void:
	if world == null or not world.ready_done:
		return
	_turrets(dt)
	_spikes(dt)
	_tesla_tick(dt)
	var night := Game.is_night()
	for l in lights:
		(l.get_meta("light") as SpotLight3D).visible = night
	if shield != null:
		(shield.material_override as StandardMaterial3D).albedo_color.a = 0.06 + (0.06 if raid_on else 0.0)
	_raid_check -= dt
	if _raid_check <= 0.0:
		_raid_check = 2.0
		_raids()


## How big tonight's raid is. It grows with your rank, with the horns on
## your wall (they sing to them) and with the farm itself.
func raid_size() -> int:
	var defs := 0
	for k in Game.defense.keys():
		defs += int(Game.defense[k])
	var n := 1 + int(Game.rank() * 0.6) + int(Game.wall.size() * 0.35) + int(maxf(0.0, defs - 3) * 0.3) + int(Game.day / 8.0)
	return clampi(n + _rng.randi_range(-1, 1), 1, 30)


func _raids() -> void:
	if raid_on:
		raid_ghouls = raid_ghouls.filter(func(g: Variant) -> bool: return is_instance_valid(g) and not (g as Ghoul).dead)
		if raid_ghouls.is_empty():
			raid_on = false
			var bounty := 40 + Game.rank() * 20
			Game.add_scrip(bounty)
			Game.raids_done += 1
			Game.say("RAID REPELLED. The farm stands.  +%d scrip" % bounty, UIStyle.GOOD)
			Game.journal("Held off a raid on the farm.")
			Sfx.play("rank", -4.0)
		return
	var t := Game.time_of_day
	if Game.day >= Game.next_raid_day and (t > 21.0 or t < 3.0):
		start_raid()


func start_raid(count: int = -1) -> void:
	var n := count if count > 0 else raid_size()
	raid_on = true
	Game.next_raid_day = Game.day + maxi(1, 3 - Game.rank() / 3) + _rng.randi_range(0, 1)
	var burnt_chance := 0.0 if Game.rank() < 4 else minf(0.35, (Game.rank() - 3) * 0.08)
	var groups := clampi(1 + n / 4, 1, 4)
	for gi in groups:
		var a := _rng.randf() * TAU
		var base := center + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(200.0, 260.0)
		for j in int(ceil(float(n) / groups)):
			if raid_ghouls.size() >= n:
				break
			var p := base + Vector3(_rng.randf_range(-12, 12), 0, _rng.randf_range(-12, 12))
			p.y = terrain.height_at(p.x, p.z)
			var g: Ghoul = world.spawn_ghoul("burnt" if _rng.randf() < burnt_chance else "ghoul", p, true)
			raid_ghouls.append(g)
	Sfx.play("howl", 2.0, 0.55)
	Game.say("RAID: %d coming for the farm. Get home or trust the turrets." % raid_ghouls.size(), Color(1.0, 0.45, 0.35))
	Game.journal("A raid: %d of them." % raid_ghouls.size())
	if world.hud != null:
		world.hud.call("radio_alert", "RAID INCOMING  ·  %d HOSTILES" % raid_ghouls.size())
	world.companion_react("raid")


func _turrets(dt: float) -> void:
	var night := Game.is_night()
	var reach := 55.0 + (15.0 * level("lights") if night else 15.0)
	for t in turrets:
		var tn := t as Node3D
		var cool := float(tn.get_meta("cool")) - dt
		tn.set_meta("cool", cool)
		var best: Ghoul = null
		var bd := reach
		for g in world.ghouls:
			var gh := g as Ghoul
			if not is_instance_valid(gh) or gh.dead:
				continue
			var d := gh.global_position.distance_to(tn.global_position)
			if d < bd:
				bd = d
				best = gh
		if best == null:
			continue
		var head: Node3D = tn.get_node("Head")
		var aim := best.global_position + Vector3(0, best.h * 0.6, 0)
		head.look_at(aim, Vector3.UP)
		if cool <= 0.0:
			tn.set_meta("cool", 0.85)
			Sfx.play_at("rifle", head.global_position, -6.0, 90.0, 1.35)
			world.muzzle_flash(head.global_position - head.global_transform.basis.z * 1.3, Catalog.WEAPONS["lever"])
			world.call("_beam", head.global_position - head.global_transform.basis.z * 1.3, aim)
			if _rng.randf() < 0.65:
				best.hurt(32.0, head.global_position)


func _spikes(dt: float) -> void:
	if level("spikes") <= 0:
		return
	_spike_t -= dt
	if _spike_t > 0.0:
		return
	_spike_t = 1.0
	for g in world.ghouls:
		var gh := g as Ghoul
		if is_instance_valid(gh) and not gh.dead and gh.at_wall:
			gh.hurt(6.0 * level("spikes"), gh.global_position)


func _tesla_tick(dt: float) -> void:
	if teslas.is_empty():
		return
	_tesla_t -= dt
	if _tesla_t > 0.0:
		return
	_tesla_t = 2.2
	for t in teslas:
		var tn := t as Node3D
		var top := tn.global_position + Vector3(0, 5.4, 0)
		for g in world.ghouls:
			var gh := g as Ghoul
			if is_instance_valid(gh) and not gh.dead and gh.global_position.distance_to(tn.global_position) < 26.0:
				world.call("_beam", top, gh.global_position + Vector3(0, 1.2, 0))
				gh.hurt(45.0 * level("tesla"), top)
				Sfx.play_at("rail", top, -8.0, 60.0, 1.8)
