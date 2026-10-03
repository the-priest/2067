// Shared by the hide and the fur shells: the coat's colour and markings.

uniform sampler2D fur : filter_linear_mipmap, repeat_enable;
uniform sampler2D fur_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 glow_col : source_color = vec3(0.2, 1.0, 0.8);
uniform vec3 belly_col : source_color = vec3(0.6, 0.55, 0.45);
uniform int pattern = 0;
uniform float mark_k = 0.8;
uniform float mark_dark = 0.4;
uniform float stripe_f = 9.0;

vec3 coat(vec2 cuv, vec3 base, vec3 lnrm, out vec3 f) {
	vec2 fuv = cuv * vec2(1.6, 2.0);
	f = texture(fur, fuv).rgb;
	float belly = smoothstep(0.1, -0.6, lnrm.y);
	vec3 col = mix(base, belly_col, belly * 0.85);
	float mark = 0.0;
	float around = cuv.y; // 0..1 round the body, 0 = back
	float along = cuv.x;
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
	return col;
}
