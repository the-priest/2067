shader_type spatial;
// The valley floor. Layers are picked per pixel from height, slope and the
// biome painted into the vertex colour (r corruption, g wet, b ash):
// dead grass, bare dirt, ash, mud, shore sand, layered rock on the steeps,
// and in the crash basin a black alien crust shot through with glowing veins.

uniform sampler2D noise_a : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D macro : filter_linear_mipmap, repeat_enable;
uniform vec3 vein_col : source_color = vec3(0.25, 1.0, 0.85);
uniform float night = 0.0;

varying vec3 wpos;
varying vec3 wnrm;
varying vec4 bio;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	bio = COLOR;
}

vec3 tri(sampler2D t, vec3 p, vec3 n, float s) {
	vec3 b = pow(abs(n), vec3(4.0));
	b /= (b.x + b.y + b.z);
	return texture(t, p.zy * s).rgb * b.x + texture(t, p.xz * s).rgb * b.y + texture(t, p.xy * s).rgb * b.z;
}

void fragment() {
	vec2 uv = wpos.xz;
	float slope = 1.0 - wnrm.y;
	float d1 = texture(noise_a, uv * 0.11).r;
	float d2 = texture(noise_a, uv * 0.53).g;
	float d3 = texture(noise_a, uv * 2.1).b;
	float m = texture(macro, uv * 0.0021).r;
	float m2 = texture(macro, uv * 0.0007 + 0.3).g;
	float detail = d1 * 0.45 + d2 * 0.35 + d3 * 0.2;

	vec3 grass = mix(vec3(0.29, 0.28, 0.17), vec3(0.4, 0.37, 0.23), m) * (0.75 + detail * 0.5);
	grass = mix(grass, vec3(0.22, 0.26, 0.14), smoothstep(0.5, 0.8, m2) * 0.7);
	grass = mix(grass, vec3(0.34, 0.31, 0.27), smoothstep(0.6, 0.9, 1.0 - m2) * 0.5);
	vec3 dirt = mix(vec3(0.27, 0.21, 0.15), vec3(0.36, 0.29, 0.21), d2) * (0.8 + d3 * 0.35);
	vec3 ash = mix(vec3(0.29, 0.28, 0.27), vec3(0.4, 0.39, 0.37), d1) * (0.85 + d3 * 0.25);
	vec3 mud = mix(vec3(0.13, 0.14, 0.09), vec3(0.22, 0.22, 0.13), d2) * (0.8 + d3 * 0.3);
	vec3 sand = mix(vec3(0.3, 0.28, 0.23), vec3(0.38, 0.35, 0.29), d1);
	vec3 rock_t = tri(noise_a, wpos, wnrm, 0.08);
	float strata = sin(wpos.y * 0.9 + rock_t.r * 6.0 + d1 * 4.0) * 0.5 + 0.5;
	vec3 rock = mix(vec3(0.21, 0.2, 0.19), vec3(0.33, 0.3, 0.27), strata * 0.35 + rock_t.g * 0.65) * (0.75 + rock_t.b * 0.4);

	// Grass thins to dirt in patches and on worn ground.
	float bare = smoothstep(0.45, 0.75, detail + (1.0 - m) * 0.25);
	vec3 col = mix(grass, dirt, bare * 0.7);
	col = mix(col, ash, smoothstep(0.45, 0.85, bio.b + d1 * 0.3 - 0.2) * 0.75);
	col = mix(col, mud, smoothstep(0.35, 0.7, bio.g) * 0.85);
	col = mix(col, sand, smoothstep(2.2, 0.6, wpos.y) * (1.0 - smoothstep(0.35, 0.6, slope)));
	col = mix(col, mud * 0.6, smoothstep(0.2, -1.0, wpos.y));

	// The alien crust: near-black, iridescent, with veins that glow.
	float c = bio.r;
	vec3 crust = mix(vec3(0.06, 0.05, 0.08), vec3(0.16, 0.1, 0.2), d2);
	crust += vec3(0.05, 0.12, 0.14) * pow(d3, 3.0);
	col = mix(col, crust, smoothstep(0.25, 0.65, c + (d1 - 0.5) * 0.4));

	float rk = smoothstep(0.28, 0.48, slope + (d2 - 0.5) * 0.18);
	rk = max(rk, smoothstep(50.0, 95.0, wpos.y + (d1 - 0.5) * 25.0) * 0.85);
	col = mix(col, rock, rk);

	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.75, rk) - smoothstep(0.4, 0.8, bio.g) * 0.25 - c * 0.3;
	SPECULAR = 0.35;
	vec3 nm = texture(noise_n, uv * 0.35).rgb;
	vec3 nm2 = texture(noise_n, uv * 1.6).rgb;
	NORMAL_MAP = normalize(mix(nm, nm2, 0.4));
	NORMAL_MAP_DEPTH = mix(0.8, 1.6, rk);

	// Veins: thin ridges in the noise that only show in the corrupted ground.
	float vn = texture(noise_a, uv * 0.012).r;
	float vein = 1.0 - smoothstep(0.0, 0.03, abs(vn - 0.5));
	float vein2 = 1.0 - smoothstep(0.0, 0.02, abs(texture(noise_a, uv * 0.03 + 0.5).r - 0.5));
	float glow = (vein + vein2 * 0.6) * smoothstep(0.35, 0.8, c);
	float pulse = 0.75 + 0.25 * sin(TIME * 1.3 + wpos.x * 0.05 + wpos.z * 0.03);
	EMISSION = vein_col * glow * pulse * (1.2 + night * 2.5);
}
