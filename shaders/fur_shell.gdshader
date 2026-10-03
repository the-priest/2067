shader_type spatial;
render_mode cull_back;
// One shell of fur: the body pushed out along its normals, drawn only where
// a strand reaches this high. Several shells stacked give real, soft fur that
// catches the light and darkens toward the roots. Glow nodes, eyes, hooves
// and horns aren't furred.

global uniform float night;
global uniform vec3 wind;
#include "res://shaders/coat.gdshaderinc"
uniform float shell = 0.5;
uniform float fur_len = 0.03;
uniform float density = 16.0;

varying float part;
varying vec3 lnrm;

void vertex() {
	part = UV2.x;
	lnrm = NORMAL;
	vec3 push = NORMAL * fur_len * shell;
	push.y -= shell * shell * fur_len * 0.35; // fur settles under its weight
	push.xz += wind.xz * shell * shell * fur_len * 0.25 * wind.y;
	VERTEX += push;
}

void fragment() {
	if (part > 0.5) {
		discard;
	}
	vec2 suv = UV * vec2(density * 1.4, density * 2.0);
	vec2 cell = floor(suv);
	vec2 fr = fract(suv) - 0.5;
	float h = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	// Strands taper: thinner the higher up the shell.
	float r = 0.48 * (1.0 - shell * 0.85);
	if (length(fr) > r || h < shell * 0.9) {
		discard;
	}
	vec3 f;
	vec3 col = coat(UV, COLOR.rgb, lnrm, f);
	col *= mix(0.55, 1.12, shell) * (0.8 + h * 0.35);
	ALBEDO = col;
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
	BACKLIGHT = col * 0.3 * shell;
}
