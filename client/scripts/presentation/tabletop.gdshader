// Phase 5 environment: the board is a miniature diorama standing on a dark
// tabletop (replaces the saturated harbour water). Unshaded, one pass:
//  - night-blue felt with a fine woven grain,
//  - a warm pool of light centred on the board that falls off to a vignette,
//  - a soft contact shadow hugging the diorama's square plinth.
// Cheap on purpose: a few ALU ops per pixel, no textures.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 felt : source_color = vec3(0.075, 0.105, 0.17);
uniform vec3 felt_far : source_color = vec3(0.02, 0.028, 0.05);
uniform vec3 pool : source_color = vec3(0.20, 0.22, 0.27);
uniform float plinth_half = 4.48;
uniform float pool_radius = 9.5;
uniform float grain = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float r = length(p);
	// Light pool: bright near the board, falling off smoothly to the edges.
	float light = 1.0 - smoothstep(plinth_half * 0.6, pool_radius, r);
	vec3 col = mix(felt_far, felt, smoothstep(pool_radius * 2.2, plinth_half, r));
	col = mix(col, pool, light * 0.55);
	// Woven felt grain: two crossed fine sine terms + per-cell noise.
	float weave = sin(p.x * 140.0) * sin(p.y * 140.0) * 0.5 + 0.5;
	float n = hash(floor(p * 60.0));
	col *= 1.0 + grain * ((weave - 0.5) * 0.025 + (n - 0.5) * 0.03);
	// Contact shadow around the square plinth (distance outside the square).
	vec2 q = abs(p) - vec2(plinth_half);
	float outside = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
	float shadow = 1.0 - smoothstep(0.0, 0.9, outside);
	col *= 1.0 - shadow * 0.55 * step(-0.05, outside);
	// Screen-space dither: hides 8-bit banding in the wide gradients.
	col += (hash(FRAGCOORD.xy) - 0.5) / 255.0;
	ALBEDO = col;
}
