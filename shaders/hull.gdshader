shader_type spatial;
// Visitor hull: black metal with an oil-slick sheen, panel seams, and lines
// of light that still crawl along it.

global uniform float night;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform vec3 seam_col : source_color = vec3(0.25, 1.0, 0.85);

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 film(float t) {
	return 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + t));
}

void fragment() {
	vec3 n = abs(NORMAL);
	float d = texture(detail, wp.xz * 0.05).r * 0.5 + texture(detail, wp.xy * 0.05).g * 0.5;
	vec2 g = UV * vec2(0.25, 18.0);
	vec2 f = abs(fract(g) - 0.5);
	float seam = 1.0 - smoothstep(0.0, 0.03, min(f.x, f.y));
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 base = COLOR.rgb * (0.7 + d * 0.5);
	ALBEDO = mix(base, base * film(fr + d) * 1.8, 0.35);
	METALLIC = 0.85;
	ROUGHNESS = 0.25 + d * 0.3;
	float crawl = smoothstep(0.85, 1.0, sin(UV.x * 0.4 - TIME * 1.5 + floor(g.y) * 1.7));
	EMISSION = seam_col * seam * (0.15 + crawl * 1.5) * (1.0 + night * 2.0);
}
