shader_type canvas_item;
// GRIDLOCK backdrop: a neon energy field with two slow-drifting glows, a
// soft wireframe grid that rises like a loading lattice, floating dust and a
// vignette. Values stay subtle so the foreground UI remains readable.

uniform vec3 top_color : source_color = vec3(0.039, 0.024, 0.094);
uniform vec3 bottom_color : source_color = vec3(0.106, 0.059, 0.200);
uniform vec3 glow_a : source_color = vec3(0.560, 0.310, 0.950);
uniform vec3 glow_b : source_color = vec3(0.129, 0.878, 0.878);
uniform float glow_strength : hint_range(0.0, 1.0) = 0.30;
uniform float grid_strength : hint_range(0.0, 1.0) = 0.10;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	vec3 color = mix(top_color, bottom_color, uv.y);

	// Two slow-drifting orbs of light.
	vec2 drift_a = vec2(0.30, 0.26) + vec2(0.08, 0.05) * sin(TIME * vec2(0.21, 0.17));
	vec2 drift_b = vec2(0.72, 0.68) + vec2(0.06, 0.09) * sin(TIME * vec2(0.13, 0.19) + 2.0);
	color += glow_a * smoothstep(0.75, 0.0, distance(uv, drift_a)) * glow_strength;
	color += glow_b * smoothstep(0.70, 0.0, distance(uv, drift_b)) * glow_strength * 0.7;

	// A rising wireframe lattice, like the board's grid coming online.
	float rise = mod(TIME * 0.045, 1.0);
	float line_v = smoothstep(0.96, 1.0, fract(uv.x * 12.0));
	float line_h = smoothstep(0.96, 1.0, fract(uv.y * 12.0 + rise));
	color += vec3(0.45, 0.32, 0.85) * (line_v + line_h) * grid_strength;

	// Twinkling dust drifting upward.
	vec2 cell = floor(uv * vec2(40.0, 70.0));
	float twinkle = hash(cell);
	if (twinkle > 0.985) {
		float phase = fract(TIME * 0.4 + twinkle * 20.0);
		color += vec3(0.8, 0.75, 1.0) * smoothstep(0.0, 0.35, phase) * (1.0 - smoothstep(0.35, 1.0, phase)) * 0.5;
	}

	// Vignette so the board and HUD pop at the centre of the screen.
	float vig = smoothstep(1.25, 0.35, distance(uv, vec2(0.5, 0.5)));
	color *= mix(0.55, 1.0, vig);

	COLOR = vec4(color, 1.0);
}