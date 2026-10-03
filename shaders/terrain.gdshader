shader_type spatial;
// The valley floor, from real ground textures: grass (dried and bleached by
// thirty years of fallout), packed dirt and ash, mud, shore sand, layered rock
// on the steeps, and in the crash basin a black alien crust shot through with
// glowing veins. Every texture is sampled at two scales and blended by a slow
// macro noise so the tiling never shows. Layers are picked from height, slope
// and the biome painted into the vertex colour (r corruption, g wet, b ash).

uniform sampler2D tex_grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_grass_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rock_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_sand : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_sand_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_a : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D macro : filter_linear_mipmap, repeat_enable;
uniform vec3 vein_col : source_color = vec3(0.25, 1.0, 0.85);
global uniform float night;

varying vec3 wpos;
varying vec3 wnrm;
varying vec4 bio;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	bio = COLOR;
}

// Two scales, rotated against each other, mixed by macro noise: no tiling.
vec3 two(sampler2D t, vec2 uv, float s, float m) {
	vec2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv;
	vec3 a = texture(t, uv * s).rgb;
	vec3 b = texture(t, r * s * 0.37 + 0.31).rgb;
	return mix(a, b, smoothstep(0.3, 0.7, m));
}

vec3 tri(sampler2D t, vec3 p, vec3 n, float s) {
	vec3 b = pow(abs(n), vec3(4.0));
	b /= (b.x + b.y + b.z);
	return texture(t, p.zy * s).rgb * b.x + texture(t, p.xz * s).rgb * b.y + texture(t, p.xy * s).rgb * b.z;
}

vec3 desat(vec3 c, float k) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	return mix(c, vec3(l), k);
}

void fragment() {
	vec2 uv = wpos.xz;
	float slope = 1.0 - wnrm.y;
	float m = texture(macro, uv * 0.0021).r;
	float m2 = texture(macro, uv * 0.0007 + 0.3).g;
	float m3 = texture(macro, uv * 0.006 + 0.7).b;
	float d1 = texture(noise_a, uv * 0.11).r;
	float d3 = texture(noise_a, uv * 2.1).b;

	// Grass, dried out: the real green, bleached toward straw and olive.
	vec3 g = two(tex_grass, uv, 0.22, m3);
	vec3 dry = desat(g, 0.6) * vec3(1.02, 0.94, 0.72);
	vec3 grass = mix(dry, g * vec3(0.78, 0.84, 0.62), 0.25 + smoothstep(0.55, 0.85, m2) * 0.35);
	grass *= 0.72 + m * 0.25;
	// Dirt and ash from the sand: darker, browner, greyer.
	vec3 sd = two(tex_sand, uv, 0.15, m);
	vec3 dirt = desat(sd, 0.35) * vec3(0.62, 0.52, 0.42);
	vec3 ash = desat(sd, 0.9) * vec3(0.55, 0.54, 0.53);
	vec3 mud = desat(sd, 0.5) * vec3(0.3, 0.28, 0.2);
	vec3 sand = sd * vec3(0.78, 0.72, 0.62);
	vec3 rk = tri(tex_rock, wpos, wnrm, 0.09);
	vec3 rk2 = tri(tex_rock, wpos, wnrm, 0.023);
	vec3 rock = mix(rk, rk2, 0.45) * vec3(0.95, 0.9, 0.85);

	float bare = smoothstep(0.45, 0.78, d1 * 0.6 + (1.0 - m) * 0.45 + d3 * 0.15);
	vec3 col = mix(grass, dirt, bare * 0.75);
	col = mix(col, ash, smoothstep(0.45, 0.85, bio.b + d1 * 0.3 - 0.2) * 0.7);
	col = mix(col, mud, smoothstep(0.35, 0.7, bio.g) * 0.85);
	col = mix(col, sand, smoothstep(2.4, 0.6, wpos.y) * (1.0 - smoothstep(0.35, 0.6, slope)));
	col = mix(col, mud * 0.6, smoothstep(0.2, -1.0, wpos.y));

	// The alien crust: rock gone black and iridescent.
	float c = bio.r;
	vec3 crust = desat(rock, 0.6) * vec3(0.22, 0.17, 0.28);
	crust += vec3(0.04, 0.1, 0.12) * pow(d3, 3.0);
	float cm = smoothstep(0.25, 0.65, c + (d1 - 0.5) * 0.4);
	col = mix(col, crust, cm);

	float rkm = smoothstep(0.26, 0.46, slope + (d1 - 0.5) * 0.15);
	rkm = max(rkm, smoothstep(50.0, 95.0, wpos.y + (d1 - 0.5) * 25.0) * 0.85);
	col = mix(col, rock, rkm);

	ALBEDO = col;
	ROUGHNESS = mix(0.93, 0.8, rkm) - smoothstep(0.4, 0.8, bio.g) * 0.3 - cm * 0.35;
	SPECULAR = 0.3;
	vec3 ng = texture(tex_grass_n, uv * 0.22).rgb;
	vec3 ns = texture(tex_sand_n, uv * 0.15).rgb;
	vec3 nr = texture(tex_rock_n, (abs(wnrm.x) > abs(wnrm.z) ? wpos.zy : wpos.xy) * 0.09).rgb;
	vec3 nm = mix(ng, ns, max(bare * 0.75, smoothstep(2.4, 0.6, wpos.y)));
	nm = mix(nm, nr, max(rkm, cm));
	NORMAL_MAP = mix(nm, texture(noise_n, uv * 1.6).rgb, 0.2);
	NORMAL_MAP_DEPTH = mix(1.0, 1.8, rkm);

	float vn = texture(noise_a, uv * 0.012).r;
	float vein = 1.0 - smoothstep(0.0, 0.03, abs(vn - 0.5));
	float vein2 = 1.0 - smoothstep(0.0, 0.02, abs(texture(noise_a, uv * 0.03 + 0.5).r - 0.5));
	float glow = (vein + vein2 * 0.6) * smoothstep(0.35, 0.8, c);
	float pulse = 0.75 + 0.25 * sin(TIME * 1.3 + wpos.x * 0.05 + wpos.z * 0.03);
	EMISSION = vein_col * glow * pulse * (1.2 + night * 2.5);
}
