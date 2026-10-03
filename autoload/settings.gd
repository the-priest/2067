extends Node
## Options, and the graphics presets that keep it running on a laptop.

signal applied

const FILE := "user://hornfall_settings.cfg"
const PRESETS := ["LOW", "MEDIUM", "HIGH", "ULTRA"]

var preset := 1
var sens := 0.0025
var fov := 75.0
var volume := 0.8
var invert_y := false
var render_scale := 1.0
var vsync := true
var killcam := true
var rumble := true
var dynamic_res := true # drop resolution to hold 60 fps
var pad_sens := 2.6


func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(FILE) == OK:
		preset = int(cf.get_value("gfx", "preset", -1))
		sens = float(cf.get_value("input", "sens", sens))
		fov = float(cf.get_value("gfx", "fov", fov))
		volume = float(cf.get_value("audio", "volume", volume))
		invert_y = bool(cf.get_value("input", "invert_y", false))
		render_scale = float(cf.get_value("gfx", "scale", 1.0))
		vsync = bool(cf.get_value("gfx", "vsync", true))
		killcam = bool(cf.get_value("game", "killcam", true))
		rumble = bool(cf.get_value("input", "rumble", true))
		dynamic_res = bool(cf.get_value("gfx", "dynamic_res", true))
		pad_sens = float(cf.get_value("input", "pad_sens", pad_sens))
	else:
		preset = -1
	if preset < 0:
		preset = auto_preset()
	_apply_audio()


## A first guess at what this machine can take.
func auto_preset() -> int:
	if compat():
		return 0
	var name := RenderingServer.get_video_adapter_name().to_lower()
	if name.contains("rtx 40") or name.contains("rtx 50") or name.contains("rx 7") or name.contains("rx 9"):
		return 2
	if name.contains("rtx") or name.contains("gtx 16") or name.contains("rx 6"):
		return 1
	# Laptops, integrated graphics and anything we don't recognise start on Low.
	return 0


## Running on the OpenGL fallback (no Vulkan).
func compat() -> bool:
	return RenderingServer.get_current_rendering_method() != "forward_plus"


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("gfx", "preset", preset)
	cf.set_value("gfx", "fov", fov)
	cf.set_value("gfx", "scale", render_scale)
	cf.set_value("gfx", "vsync", vsync)
	cf.set_value("input", "sens", sens)
	cf.set_value("input", "invert_y", invert_y)
	cf.set_value("audio", "volume", volume)
	cf.set_value("game", "killcam", killcam)
	cf.set_value("input", "rumble", rumble)
	cf.set_value("gfx", "dynamic_res", dynamic_res)
	cf.set_value("input", "pad_sens", pad_sens)
	cf.save(FILE)


## Numbers the world reads for the current preset.
func q() -> Dictionary:
	match preset:
		0:
			return {"shadow": 2048, "shadow_dist": 90.0, "splits": 2, "ssao": false, "ssil": false, "vfog": false, "sdfgi": false,
				"grass": 0.3, "grass_r": 40.0, "trees": 0.55, "view": 900.0, "lod0": 130.0, "lod1": 360.0, "glow": true, "taa": false, "ssr": false, "scale": 0.8}
		1:
			return {"shadow": 2048, "shadow_dist": 140.0, "splits": 2, "ssao": true, "ssil": false, "vfog": false, "sdfgi": false,
				"grass": 0.6, "grass_r": 60.0, "trees": 0.8, "view": 1400.0, "lod0": 200.0, "lod1": 520.0, "glow": true, "taa": false, "ssr": false, "scale": 1.0}
		2:
			return {"shadow": 4096, "shadow_dist": 260.0, "splits": 4, "ssao": true, "ssil": true, "vfog": true, "sdfgi": false,
				"grass": 1.0, "grass_r": 95.0, "trees": 1.0, "view": 2200.0, "lod0": 300.0, "lod1": 750.0, "glow": true, "taa": true, "ssr": true, "scale": 1.0}
	return {"shadow": 4096, "shadow_dist": 380.0, "splits": 4, "ssao": true, "ssil": true, "vfog": true, "sdfgi": true,
		"grass": 1.4, "grass_r": 120.0, "trees": 1.0, "view": 3000.0, "lod0": 380.0, "lod1": 900.0, "glow": true, "taa": true, "ssr": true, "scale": 1.0}


## Put the preset on a viewport, an environment and the sun.
func apply_to(vp: Viewport, env: Environment, sun: DirectionalLight3D) -> void:
	var d := q()
	var c := compat()
	vp.scaling_3d_scale = minf(float(d["scale"]), render_scale)
	if not c and vp.scaling_3d_scale < 0.99:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	vp.use_taa = bool(d["taa"]) and not c
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if not bool(d["taa"]) else Viewport.SCREEN_SPACE_AA_DISABLED
	RenderingServer.directional_shadow_atlas_set_size(int(d["shadow"]), true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	if sun != null:
		sun.directional_shadow_max_distance = float(d["shadow_dist"])
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if int(d.get("splits", 4)) == 2 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	if env != null:
		env.ssao_enabled = bool(d["ssao"]) and not c
		env.ssil_enabled = bool(d["ssil"]) and not c
		env.sdfgi_enabled = bool(d["sdfgi"]) and not c
		env.ssr_enabled = bool(d["ssr"]) and not c
		env.volumetric_fog_enabled = bool(d["vfog"]) and not c
		env.glow_enabled = bool(d["glow"])
	applied.emit()


func _apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))


func set_volume(v: float) -> void:
	volume = v
	_apply_audio()
