shader_type spatial;
render_mode cull_disabled;
// The lake: murky, greenish, slow ripples, a dusty sheen at grazing angles.

global uniform vec3 wind;
global uniform float night;
uniform sampler2D noise_n : hint_normal, filter_linear_mipmap, repeat_enable;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wp.x * 0.15 + TIME * 0.8) * cos(wp.z * 0.12 + TIME * 0.6) * 0.06;
}

void fragment() {
	vec2 flow = vec2(wind.x, wind.z) * TIME * 0.02 * (0.5 + wind.y);
	vec3 n1 = texture(noise_n, wp.xz * 0.04 + flow).rgb;
	vec3 n2 = texture(noise_n, wp.xz * 0.11 - flow * 1.6).rgb;
	NORMAL_MAP = normalize(mix(n1, n2, 0.5));
	NORMAL_MAP_DEPTH = 0.6;
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(vec3(0.05, 0.07, 0.05), vec3(0.22, 0.24, 0.2), f);
	ROUGHNESS = 0.08;
	METALLIC = 0.2;
	SPECULAR = 0.7;
	ALPHA = mix(0.88, 1.0, f);
}
