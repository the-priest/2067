class_name Atmosphere
extends Node3D
## Sun, moon, sky, haze and the wind. A day lasts 24 real minutes. The
## wind matters: it carries your scent, and it swings through the day.

const DAY_MINUTES := 24.0

var env: Environment
var we: WorldEnvironment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_mat: ShaderMaterial
var wind_dir := Vector2(1, 0) # where the wind blows towards (xz)
var wind_strength := 0.5
var _wind_angle := 0.6
var _wind_t := 0.0
var ash: GPUParticles3D = null
var paused := false
var night_amt := 0.0


func _ready() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.7, 0.6, 0.48)
	env.fog_density = 0.7
	env.fog_depth_begin = 150.0
	env.fog_depth_end = 1500.0
	env.fog_depth_curve = 1.6
	env.fog_sun_scatter = 0.35
	env.fog_aerial_perspective = 0.3
	env.fog_sky_affect = 0.25
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.78, 0.7, 0.6)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 160.0
	env.volumetric_fog_ambient_inject = 0.25
	env.volumetric_fog_sky_affect = 0.0
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.ssil_radius = 4.0
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.ssr_max_steps = 48
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.92
	we = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.light_angular_distance = 0.8
	sun.directional_shadow_fade_start = 0.85
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.55, 0.65, 0.85)
	moon.shadow_enabled = false
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(moon)
	_make_ash()
	tick(0.0)


func apply_quality() -> void:
	Settings.apply_to(get_viewport(), env, sun)
	var d := Settings.q()
	env.fog_depth_end = float(d["view"]) * 1.3
	if ash != null:
		ash.amount = int(600 * float(d["grass"])) + 100


func _process(delta: float) -> void:
	if not paused:
		Game.time_of_day += delta * 24.0 / (DAY_MINUTES * 60.0)
		if Game.time_of_day >= 24.0:
			Game.time_of_day -= 24.0
			Game.day += 1
			Game.refresh_contracts()
	tick(delta)


func tick(delta: float) -> void:
	var t := Game.time_of_day
	# The sun climbs from the east (x+) at 6, peaks at noon, sets west at 18.
	var ang := (t - 6.0) / 12.0 * PI
	var elev := sin(ang)
	var sd := Vector3(cos(ang), elev, 0.35).normalized()
	sun.look_at_from_position(Vector3.ZERO, -sd, Vector3(0, 0, 1) if absf(sd.y) > 0.99 else Vector3.UP)
	var day := smoothstep(-0.05, 0.25, elev)
	var dusk := clampf(1.0 - absf(elev) / 0.22, 0.0, 1.0) * smoothstep(-0.2, 0.0, elev)
	night_amt = 1.0 - smoothstep(-0.15, 0.08, elev)
	sun.light_energy = lerpf(0.0, 1.6, day) + dusk * 0.4
	sun.light_color = Color(1.0, 0.92, 0.8).lerp(Color(1.0, 0.55, 0.3), dusk)
	sun.visible = elev > -0.08
	var md := Vector3(-cos(ang) * 0.6, -elev * 0.8 + 0.25, -0.6).normalized()
	moon.look_at_from_position(Vector3.ZERO, -md, Vector3.UP)
	moon.light_energy = 0.22 * night_amt
	moon.visible = night_amt > 0.05
	moon.shadow_enabled = night_amt > 0.5 and Settings.preset >= 2
	sky_mat.set_shader_parameter("day", day)
	sky_mat.set_shader_parameter("dusk", dusk)
	sky_mat.set_shader_parameter("moon_dir", md)
	env.ambient_light_energy = lerpf(0.35, 1.0, day)
	env.fog_light_color = Color(0.08, 0.1, 0.13).lerp(Color(0.6, 0.53, 0.44), day).lerp(Color(0.85, 0.5, 0.3), dusk * 0.6)
	env.volumetric_fog_albedo = env.fog_light_color
	env.volumetric_fog_density = lerpf(0.004, 0.009, dusk + night_amt * 0.5)
	env.tonemap_exposure = lerpf(1.6, 1.0, day)
	# Wind: drifts round the compass through the day, with gusts.
	_wind_t += delta
	_wind_angle += sin(_wind_t * 0.013) * delta * 0.03
	wind_dir = Vector2(cos(_wind_angle), sin(_wind_angle))
	wind_strength = clampf(0.45 + 0.3 * sin(_wind_t * 0.07) + 0.15 * sin(_wind_t * 0.31), 0.05, 1.0)
	RenderingServer.global_shader_parameter_set("wind", Vector3(wind_dir.x, wind_strength, wind_dir.y))
	RenderingServer.global_shader_parameter_set("night", night_amt)
	Sfx.wind_level(wind_strength)


## Ash drifting down around the camera.
func _make_ash() -> void:
	ash = GPUParticles3D.new()
	ash.amount = 500
	ash.lifetime = 9.0
	ash.preprocess = 9.0
	ash.visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 40, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(35, 12, 35)
	pm.gravity = Vector3(0.6, -0.35, 0.2)
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.4
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 4.0
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	ash.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.035, 0.035)
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(0.82, 0.8, 0.76, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	qm.material = mat
	ash.draw_pass_1 = qm
	add_child(ash)


func follow(p: Vector3) -> void:
	if ash != null:
		ash.global_position = p + Vector3(0, 6, 0)


## Is a point downwind of another (does the wind carry from 'from' to 'to')?
func downwind(from: Vector3, to: Vector3) -> float:
	var d := Vector2(to.x - from.x, to.z - from.z)
	if d.length() < 0.01:
		return 1.0
	return clampf(d.normalized().dot(wind_dir), -1.0, 1.0)
