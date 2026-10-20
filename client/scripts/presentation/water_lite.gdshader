// Low-preset harbour water (Phase 2): the same colours as water.gdshader
// with one ripple term and the quay foam band, but no fresnel / normal map and
// no lighting, so the full-screen water costs a fraction of the per-pixel work
// on weak GPUs.
shader_type spatial;
render_mode unshaded;

uniform vec3 shallow : source_color = vec3(0.12, 0.43, 0.52);
uniform vec3 deep : source_color = vec3(0.04, 0.17, 0.31);
uniform vec3 foam_color : source_color = vec3(0.92, 0.97, 1.0);
uniform float quay_half = 4.38;

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float d = clamp(length(p) / 20.0, 0.0, 1.0);
	float w = sin(p.x * 1.6 + TIME * 1.1) * cos(p.y * 1.3 - TIME * 0.9);
	float edge = max(abs(p.x), abs(p.y)) - quay_half;
	float foam = (1.0 - smoothstep(0.0, 0.22, edge)) * step(0.0, edge) * smoothstep(-0.2, 0.6, w + 0.4);
	// Unshaded: the sun term is folded into the colours (no per-pixel lighting).
	vec3 water = (mix(shallow, deep, smoothstep(0.25, 0.8, d)) + w * 0.012) * 1.25;
	ALBEDO = mix(water, foam_color, foam * 0.5);
}
