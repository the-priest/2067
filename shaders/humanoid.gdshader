shader_type spatial;
// People. Vertex colour carries skin and clothes; UV2.x: 0 cloth, 1 glow
// (sores, alien seams), 3 eyes, 4 skin.

global uniform float night;
uniform vec3 glow_col : source_color = vec3(0.3, 1.0, 0.8);
uniform sampler2D fabric : filter_linear_mipmap, repeat_enable;
uniform float alive = 1.0;

varying float part;

void vertex() {
	part = UV2.x;
}

void fragment() {
	vec3 c = COLOR.rgb;
	if (part > 3.5) {
		ALBEDO = c;
		ROUGHNESS = 0.55;
		SSS_STRENGTH = 0.4;
	} else if (part > 2.5) {
		ALBEDO = c;
		ROUGHNESS = 0.08;
		SPECULAR = 0.9;
		EMISSION = c * 0.1;
	} else if (part > 0.5) {
		ALBEDO = glow_col * 0.3;
		EMISSION = glow_col * (1.5 + night * 2.5) * alive;
	} else {
		float f = texture(fabric, UV * vec2(3.0, 4.0)).r;
		ALBEDO = c * (0.75 + f * 0.4);
		ROUGHNESS = 0.9;
	}
}
