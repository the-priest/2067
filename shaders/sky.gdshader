shader_type sky;
// After the Fall: a sky full of dust. Ochre at the horizon, bruised blue
// above, a sun that never quite gets clear of the haze. Across it all runs
// the Ring: the wreckage of the Visitors' fleet, still in orbit, glinting.
// At night there are stars, a big pale moon, and the green sheet of light
// the Visitors left in the upper air.

uniform float day = 1.0;
uniform float dusk = 0.0;
uniform vec3 moon_dir = vec3(0.3, 0.5, -0.8);
uniform float haze = 1.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void sky() {
	vec3 d = EYEDIR;
	float up = clamp(d.y, -1.0, 1.0);
	vec3 sun = LIGHT0_DIRECTION;
	float sd = max(dot(d, sun), 0.0);

	vec3 zen_day = vec3(0.32, 0.4, 0.5);
	vec3 hor_day = vec3(0.78, 0.66, 0.5);
	vec3 zen_dusk = vec3(0.2, 0.17, 0.28);
	vec3 hor_dusk = vec3(0.95, 0.45, 0.2);
	vec3 zen_night = vec3(0.012, 0.016, 0.03);
	vec3 hor_night = vec3(0.04, 0.05, 0.06);

	float h = pow(1.0 - max(up, 0.0), 3.5);
	vec3 zen = mix(mix(zen_night, zen_day, day), zen_dusk, dusk);
	vec3 hor = mix(mix(hor_night, hor_day, day), hor_dusk, dusk);
	vec3 col = mix(zen, hor, h);
	// Below the horizon: the haze thickens to ground colour.
	col = mix(col, hor * 0.7, smoothstep(0.0, -0.15, up));

	// Sun: a disc dimmed by dust, a wide glow around it.
	float disc = smoothstep(0.9993, 0.9997, sd);
	col += vec3(1.0, 0.85, 0.6) * disc * (4.0 * day + 2.0 * dusk);
	col += vec3(1.0, 0.6, 0.3) * pow(sd, 8.0) * (0.35 * day + 0.6 * dusk) * haze;
	col += vec3(1.0, 0.75, 0.5) * pow(sd, 60.0) * 0.6 * (day + dusk);

	// Dust clouds: slow streaks.
	if (up > 0.0) {
		vec3 p = d / max(up, 0.06);
		float c = noise3(vec3(p.xz * 0.6 + TIME * 0.004, 1.0)) * 0.6 + noise3(vec3(p.xz * 1.7 - TIME * 0.006, 2.0)) * 0.4;
		c = smoothstep(0.45, 0.85, c) * smoothstep(0.0, 0.25, up);
		vec3 cc = mix(vec3(0.06, 0.06, 0.08), mix(vec3(0.7, 0.6, 0.5), vec3(1.0, 0.55, 0.3), dusk), max(day, dusk));
		col = mix(col, cc, c * 0.55);
	}

	// The Ring: a band of wreckage across the sky.
	vec3 ring_n = normalize(vec3(0.25, 0.35, 1.0));
	float rd = abs(dot(d, ring_n));
	float band = smoothstep(0.05, 0.0, rd) * smoothstep(-0.05, 0.1, up);
	float specks = step(0.985, hash(floor(d * 900.0))) * smoothstep(0.03, 0.0, rd);
	col += vec3(0.75, 0.7, 0.65) * band * (0.08 + 0.12 * (1.0 - day)) * (0.6 + 0.4 * noise3(d * 80.0));
	col += vec3(1.0, 0.95, 0.85) * specks * (0.6 + 1.4 * (1.0 - day));

	// Night: stars, the moon, the green light.
	float night = 1.0 - max(day, dusk * 0.7);
	if (night > 0.01 && up > 0.0) {
		float st = step(0.9975, hash(floor(d * 500.0)));
		float tw = 0.6 + 0.4 * sin(TIME * 3.0 + hash(floor(d * 500.0)) * 50.0);
		col += vec3(0.9, 0.92, 1.0) * st * tw * night * smoothstep(0.0, 0.2, up);
		float a = noise3(vec3(d.x * 3.0 + TIME * 0.02, d.z * 3.0, TIME * 0.03));
		float sheet = smoothstep(0.2, 0.6, up) * smoothstep(0.85, 0.5, up) * smoothstep(0.4, 0.9, a);
		col += vec3(0.15, 0.9, 0.55) * sheet * 0.25 * night;
		float md = dot(d, normalize(moon_dir));
		float moon = smoothstep(0.9990, 0.9993, md);
		float crater = noise3(d * 300.0) * 0.4 + 0.6;
		col += vec3(0.85, 0.85, 0.8) * moon * crater * night * 1.6;
		col += vec3(0.4, 0.45, 0.55) * pow(max(md, 0.0), 200.0) * 0.4 * night;
	}
	COLOR = col;
}
