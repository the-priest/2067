shader_type spatial;
render_mode cull_disabled;
// Dead grass, reeds and alien tendrils. Instance colour (custom data) tints
// each clump; the tips bend with the wind, and part away from the player.

global uniform vec3 wind;
global uniform float night;
uniform vec3 player_pos;
uniform float fade_dist = 70.0;

varying float tipv;
varying vec4 ic;
varying float fadev;

void vertex() {
	ic = INSTANCE_CUSTOM;
	tipv = UV.y;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * (1.2 + wind.y * 1.5);
	float g = sin(t + w.x * 0.21 + w.z * 0.17) * 0.5 + sin(t * 1.7 + w.x * 0.5) * 0.25;
	float bend = tipv * tipv;
	vec3 push = vec3(wind.x, 0.0, wind.z) * (0.25 + wind.y * 0.6) * (0.6 + g) * bend * 0.6;
	vec3 away = w - player_pos;
	float pd = length(away.xz);
	push += normalize(vec3(away.x, 0.0, away.z) + 0.001) * smoothstep(1.2, 0.0, pd) * bend * 0.6;
	VERTEX += (inverse(mat3(MODEL_MATRIX)) * push);
	fadev = smoothstep(fade_dist, fade_dist * 0.75, length(w - player_pos));
	VERTEX.y *= mix(0.0, 1.0, fadev);
}

void fragment() {
	vec3 base = ic.rgb;
	vec3 col = mix(base * 0.45, base * 1.15, tipv);
	ALBEDO = col;
	ROUGHNESS = 0.9;
	BACKLIGHT = vec3(0.35, 0.3, 0.15) * tipv;
	AO = mix(0.5, 1.0, tipv);
	AO_LIGHT_AFFECT = 0.6;
	if (ic.a > 0.5) {
		EMISSION = vec3(0.6, 0.25, 1.0) * smoothstep(0.75, 1.0, tipv) * (0.8 + night * 3.0);
	}
}
