shader_type spatial;
// Hybrid hide. Fur detail along the body, a lighter belly, the species'
// markings (ridge, spots, stripes, saddle, bristle) and the alien in it:
// glowing nodes and markings that pulse with the heartbeat, and fade when
// it dies. UV2.x: 0 hide, 1 glow node, 3 eye, 4 hoof/nose.

global uniform float night;
#include "res://shaders/coat.gdshaderinc"
uniform float alive = 1.0;
uniform float pulse_rate = 1.2;
uniform float thermal = 0.0;
uniform float wet = 0.0; // blood on the hide

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
		EMISSION = glow_col * (0.5 + night * 1.6) * p * alive;
		SSS_STRENGTH = 0.8;
	} else {
		vec2 fuv = UV * vec2(1.6, 2.0);
		vec3 f;
		vec3 col = coat(UV, base, lnrm, f);
		float around = UV.y;
		float along = UV.x;
		float belly = smoothstep(0.1, -0.6, lnrm.y);
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
