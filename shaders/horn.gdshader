shader_type spatial;
// Visitor keratin: dark and ridged at the skull, paling and turning
// iridescent toward the tip like oil on water, where the beads glow.
// COLOR.a: 0 base .. 1 tip. UV2.x 1: glowing bead.

global uniform float night;
uniform vec3 glow_col : source_color = vec3(0.3, 1.0, 0.9);
uniform float alive = 1.0;
uniform float mounted = 0.0;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;

varying float part;

void vertex() {
	part = UV2.x;
}

vec3 film(float t) {
	return 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + t));
}

void fragment() {
	if (part > 1.5) {
		// Moss, vines, grass and flowers growing on the horn.
		ALBEDO = COLOR.rgb;
		ROUGHNESS = 0.95;
		SPECULAR = 0.2;
		BACKLIGHT = COLOR.rgb * 0.4;
	} else if (part > 0.5) {
		ALBEDO = COLOR.rgb;
		ROUGHNESS = 0.5;
	} else {
		float u = COLOR.a;
		vec3 base = COLOR.rgb;
		float n = texture(detail, UV * vec2(2.0, 1.0)).g;
		float rings = 0.85 + 0.15 * sin(UV.x * 60.0 + n * 3.0);
		vec3 col = mix(base * 0.6, mix(base, vec3(0.88, 0.84, 0.74), 0.55), smoothstep(0.1, 0.9, u)) * rings;
		float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
		vec3 irid = film(f * 1.5 + u * 0.8 + n * 0.3);
		col = mix(col, col * irid * 1.4, smoothstep(0.5, 1.0, u) * (0.08 + f * 0.25));
		ALBEDO = col;
		ROUGHNESS = mix(0.65, 0.22, u);
		SPECULAR = 0.6;
		CLEARCOAT = 0.5 * u;
		CLEARCOAT_ROUGHNESS = 0.2;
	}
}
