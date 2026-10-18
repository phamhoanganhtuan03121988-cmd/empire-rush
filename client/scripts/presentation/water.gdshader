// Stylised harbour water (M2.3): depth-tinted colour, layered animated
// ripples, foam along the quay walls and a fresnel sky tint. Cheap enough
// for the Mobile renderer (no screen textures).
shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec3 shallow : source_color = vec3(0.12, 0.43, 0.52);
uniform vec3 deep : source_color = vec3(0.04, 0.17, 0.31);
uniform vec3 foam_color : source_color = vec3(0.92, 0.97, 1.0);
uniform float ripple_scale = 1.6;
uniform float quay_half = 4.38;

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float d = clamp(length(p) / 20.0, 0.0, 1.0);
	// Fine ripples fade with distance so far water does not alias (moire).
	float near = 1.0 - smoothstep(6.0, 14.0, length(p));
	float w = sin(p.x * ripple_scale + TIME * 1.1) * cos(p.y * ripple_scale * 0.8 - TIME * 0.9);
	w += near * 0.5 * sin((p.x + p.y) * ripple_scale * 2.3 + TIME * 1.7);
	w += near * 0.25 * sin((p.x - p.y) * ripple_scale * 4.1 - TIME * 2.3);
	w *= mix(0.35, 1.0, near);
	// Foam: a soft band hugging the square quay, broken up by the ripples.
	float edge = max(abs(p.x), abs(p.y)) - quay_half;
	float foam = (1.0 - smoothstep(0.0, 0.22, edge)) * step(0.0, edge);
	foam *= smoothstep(-0.2, 0.6, w + 0.4);
	vec3 water = mix(shallow, deep, smoothstep(0.25, 0.8, d)) + w * 0.015;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	water = mix(water, vec3(0.55, 0.72, 0.86), fres * 0.25);
	ALBEDO = mix(water, foam_color, foam * 0.5);
	NORMAL_MAP = normalize(vec3(w * 0.18, w * 0.12, 1.0)) * 0.5 + 0.5;
	ROUGHNESS = mix(0.18, 0.7, foam);
	SPECULAR = 0.45;
}
