## Low / medium / high presets (shadows, MSAA, glow, render scale).
class_name QualitySettings
extends RefCounted

const ORDER := ["low", "medium", "high"]


static func apply(name: String, viewport: Viewport, sun: DirectionalLight3D, env: Environment) -> void:
	match name:
		"low":
			sun.shadow_enabled = false
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.scaling_3d_scale = 0.75
			env.glow_enabled = false
		"medium":
			sun.shadow_enabled = true
			sun.directional_shadow_max_distance = 30.0
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.scaling_3d_scale = 1.0
			env.glow_enabled = true
		_:
			sun.shadow_enabled = true
			sun.directional_shadow_max_distance = 40.0
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.scaling_3d_scale = 1.0
			env.glow_enabled = true


static func next(name: String) -> String:
	return ORDER[(ORDER.find(name) + 1) % ORDER.size()]
