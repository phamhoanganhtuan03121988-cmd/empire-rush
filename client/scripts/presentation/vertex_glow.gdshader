// Emissive surface coloured by vertex colour (merged windows / gold caps).
shader_type spatial;
render_mode specular_schlick_ggx;
uniform float energy = 1.6;
uniform float roughness_v = 0.3;
uniform float metallic_v = 0.0;

void fragment() {
	vec3 c = COLOR.rgb;
	ALBEDO = c;
	EMISSION = c * energy;
	ROUGHNESS = roughness_v;
	METALLIC = metallic_v;
}
