class_name WorldLook
extends RefCounted
## Shared warm lighting + tilted camera used by the menu and the match.


static func add_environment(host: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.06, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.46, 0.34, 0.24)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.ssao_enabled = false
	env.glow_enabled = false
	env.fog_enabled = true
	env.fog_light_color = Color(0.16, 0.10, 0.06)
	env.fog_density = 0.012
	var we := WorldEnvironment.new()
	we.environment = env
	host.add_child(we)


static func add_lights(host: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.directional_shadow_max_distance = 24.0
	sun.rotation_degrees = Vector3(-48, -36, 0)
	host.add_child(sun)

	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.82, 0.62)
	fill.light_energy = 0.55
	fill.omni_range = 12.0
	fill.position = Vector3(-3.2, 4.2, 3.8)
	host.add_child(fill)

	var rim := OmniLight3D.new()
	rim.light_color = Color(0.55, 0.70, 1.0)
	rim.light_energy = 0.22
	rim.omni_range = 10.0
	rim.position = Vector3(3.5, 3.0, -3.0)
	host.add_child(rim)


static func add_camera(host: Node3D, origin: Vector3 = Vector3(0.15, 7.1, 6.6), look: Vector3 = Vector3(0, 0.15, 0)) -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = 42.0
	cam.near = 0.08
	cam.far = 80.0
	cam.position = origin
	host.add_child(cam)
	cam.look_at(look)
	# Extra tilt so the board reads as 3D rather than a flat grid.
	cam.rotation_degrees.z = -4.5
	return cam
