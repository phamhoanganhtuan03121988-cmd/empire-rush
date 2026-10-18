// Stylised harbour water: depth-tinted colour, soft animated ripples and a
// gentle specular. Cheap enough for the Mobile renderer.
shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec3 shallow : source_color = vec3(0.16, 0.50, 0.60);
uniform vec3 deep : source_color = vec3(0.04, 0.17, 0.32);
uniform float ripple_scale = 1.4;

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float d = clamp(length(p) / 22.0, 0.0, 1.0);
	float w = sin(p.x * ripple_scale + TIME * 1.1) * cos(p.y * ripple_scale * 0.8 - TIME * 0.9);
	w += 0.5 * sin((p.x + p.y) * ripple_scale * 2.3 + TIME * 1.7);
	ALBEDO = mix(shallow, deep, smoothstep(0.2, 0.75, d)) + w * 0.012;
	NORMAL_MAP = normalize(vec3(w * 0.15, w * 0.1, 1.0)) * 0.5 + 0.5;
	ROUGHNESS = 0.32;
	SPECULAR = 0.35;
}
