shader_type spatial;
// Trees, snags, bushes, rocks, crystals. UV2.x picks the part: 0 bark/wood,
// 1 glowing alien growth, 2 rock, 3 crystal. Branch tips sway in the wind.

global uniform vec3 wind;
global uniform float night;
uniform sampler2D bark : filter_linear_mipmap, repeat_enable;
uniform sampler2D bark_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform float sway = 1.0;

varying float part;
varying vec3 wp;
varying vec3 lp;

void vertex() {
	part = UV2.x;
	lp = VERTEX;
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	float s = sway * h * h * 0.0025 * (0.4 + wind.y);
	float t = TIME * (0.8 + wind.y) + w.x * 0.05 + w.z * 0.07;
	VERTEX.x += (sin(t) * 0.6 + sin(t * 2.3) * 0.25) * s * (0.5 + wind.x);
	VERTEX.z += (cos(t * 0.9) * 0.6) * s * (0.5 + wind.z);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = COLOR.rgb;
	if (part < 0.5) {
		float b = texture(bark, UV * vec2(0.6, 1.0)).r;
		ALBEDO = c * (0.55 + b * 0.7);
		NORMAL_MAP = texture(bark_n, UV * vec2(0.6, 1.0)).rgb;
		NORMAL_MAP_DEPTH = 1.4;
		ROUGHNESS = 0.92;
	} else if (part < 1.5) {
		ALBEDO = c * 0.4;
		float p = 0.7 + 0.3 * sin(TIME * 2.0 + wp.x + wp.y * 2.0);
		EMISSION = c * (1.2 + night * 3.0) * p;
		ROUGHNESS = 0.3;
		SSS_STRENGTH = 0.6;
	} else if (part < 2.5) {
		vec3 n = abs(normalize(lp) + 0.001);
		float d = texture(detail, wp.xz * 0.35).r * n.y + texture(detail, wp.xy * 0.35).g * n.z + texture(detail, wp.zy * 0.35).b * n.x;
		ALBEDO = c * (0.6 + d * 0.65);
		NORMAL_MAP = texture(bark_n, wp.xz * 0.2 + wp.y * 0.1).rgb;
		NORMAL_MAP_DEPTH = 1.0;
		ROUGHNESS = 0.88;
	} else {
		ALBEDO = c * 0.3;
		METALLIC = 0.3;
		ROUGHNESS = 0.08;
		RIM = 0.6;
		float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
		EMISSION = c * (0.35 + f * 1.6) * (1.0 + night * 2.5);
	}
}
