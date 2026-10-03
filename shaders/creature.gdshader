shader_type spatial;
// Hybrid hide. Fur detail along the body, a lighter belly, the species'
// markings (ridge, spots, stripes, saddle, bristle) and the alien in it:
// glowing nodes and markings that pulse with the heartbeat, and fade when
// it dies. UV2.x: 0 hide, 1 glow node, 3 eye, 4 hoof/nose.

global uniform float night;
uniform sampler2D fur : filter_linear_mipmap, repeat_enable;
uniform sampler2D fur_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 glow_col : source_color = vec3(0.2, 1.0, 0.8);
uniform vec3 belly_col : source_color = vec3(0.6, 0.55, 0.45);
uniform int pattern = 0;
uniform float alive = 1.0;
uniform float pulse_rate = 1.2;
uniform float thermal = 0.0;
uniform float wet = 0.0; // blood on the hide
uniform float mark_k = 0.8;
uniform float mark_dark = 0.4;
uniform float stripe_f = 9.0;

varying float part;
varying vec3 lnrm;
varying vec3 lpos;

void vertex() {
	part = UV2.x;
	lnrm = NORMAL;
	lpos = VERTEX;
}

void fragment() {
	vec3 base = COLOR.rgb;
	if (part > 2.5 && part < 3.5) {
		// Eyes: black glass with a glowing pupil.
		ALBEDO = vec3(0.02);
		ROUGHNESS = 0.05;
		SPECULAR = 0.9;
		EMISSION = glow_col * 2.5 * alive;
	} else if (part > 3.5) {
		ALBEDO = base;
		ROUGHNESS = 0.45;
	} else if (part > 0.5) {
		float p = 0.6 + 0.4 * pow(abs(sin(TIME * pulse_rate * 3.14159)), 6.0);
		ALBEDO = glow_col * 0.25;
		ROUGHNESS = 0.2;
		EMISSION = glow_col * (1.5 + night * 3.0) * p * alive;
		SSS_STRENGTH = 0.8;
	} else {
		vec2 fuv = UV * vec2(1.6, 2.0);
		vec3 f = texture(fur, fuv).rgb;
		float belly = smoothstep(0.1, -0.6, lnrm.y);
		vec3 col = mix(base, belly_col, belly * 0.85);
		float mark = 0.0;
		float around = UV.y; // 0..1 round the body, 0 = back
		float along = UV.x;
		float back = 1.0 - smoothstep(0.0, 0.14, min(around, 1.0 - around));
		if (pattern == 0) { // ridge: a dark stripe down the spine
			mark = back;
		} else if (pattern == 1) { // spots
			vec2 g = vec2(along * 5.0, around * 9.0);
			vec2 c = fract(g) - 0.5;
			float r = fract(sin(dot(floor(g), vec2(12.9, 78.2))) * 43758.5);
			mark = (1.0 - smoothstep(0.12, 0.2, length(c))) * step(0.4, r) * (1.0 - belly);
		} else if (pattern == 2) { // stripes
			mark = smoothstep(0.55, 0.8, sin(along * stripe_f + sin(around * 6.28 + along * 3.0) * 1.2 + f.g * 2.0)) * (1.0 - belly * 0.7);
		} else if (pattern == 3) { // saddle
			mark = smoothstep(0.25, 0.15, abs(around - 0.0)) + smoothstep(0.75, 0.85, around);
			mark *= smoothstep(0.1, 0.3, along) * smoothstep(1.4, 0.9, along);
		} else if (pattern == 5) { // patches: a giraffe's net of light lines between dark plates
			vec2 g = vec2(along * 4.0, around * 7.0) + f.rg * 0.4;
			vec2 cell = floor(g);
			vec2 fr = fract(g);
			float md = 1.0;
			for (int y = -1; y <= 1; y++) {
				for (int x = -1; x <= 1; x++) {
					vec2 o = vec2(float(x), float(y));
					vec2 pnt = o + 0.5 + 0.35 * sin(6.28 * fract(sin(dot(cell + o, vec2(127.1, 311.7))) * 43758.5) + vec2(0.0, 1.6));
					md = min(md, length(pnt - fr));
				}
			}
			mark = (1.0 - smoothstep(0.26, 0.4, md)) * (1.0 - belly);
		} else { // bristle
			mark = back * 0.8 + f.g * 0.3;
		}
		col = mix(col, col * mark_dark, clamp(mark, 0.0, 1.0) * mark_k);
		col *= 0.7 + f.r * 0.55;
		// Faint alien markings that glow along the flanks.
		float vein = 1.0 - smoothstep(0.0, 0.03, abs(fract(along * 2.5 + sin(around * 12.0) * 0.08) - 0.5));
		vein *= smoothstep(0.2, 0.35, around) * smoothstep(0.8, 0.65, around) * (1.0 - belly);
		col = mix(col, vec3(0.35, 0.02, 0.02), wet * 0.6);
		ALBEDO = col;
		ROUGHNESS = 0.85 - wet * 0.4;
		NORMAL_MAP = texture(fur_n, fuv).rgb;
		NORMAL_MAP_DEPTH = 1.2;
		SSS_STRENGTH = 0.15;
		RIM = 0.35;
		RIM_TINT = 0.6;
		EMISSION = glow_col * vein * 0.35 * (0.3 + night * 1.5) * alive;
	}
	if (thermal > 0.5) {
		float heat = 0.55 + 0.35 * dot(NORMAL, VIEW);
		ALBEDO = vec3(0.0);
		EMISSION = mix(vec3(0.9, 0.2, 0.05), vec3(1.0, 0.95, 0.6), heat) * (0.4 + alive * 1.2);
	}
}
