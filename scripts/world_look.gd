class_name WorldLook
extends RefCounted
## Warm lighting + a camera that frames the full board inside the 3D view.


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


static func add_lights(host: Node3D, board_half: float = 3.0) -> void:
	var reach := maxf(12.0, board_half * 4.0)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.directional_shadow_max_distance = reach * 2.0
	sun.rotation_degrees = Vector3(-55, -28, 0)
	host.add_child(sun)

	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.82, 0.62)
	fill.light_energy = 0.55
	fill.omni_range = reach
	fill.position = Vector3(-board_half * 0.9, board_half * 1.2, board_half * 0.9)
	host.add_child(fill)

	var rim := OmniLight3D.new()
	rim.light_color = Color(0.55, 0.70, 1.0)
	rim.light_energy = 0.22
	rim.omni_range = reach
	rim.position = Vector3(board_half, board_half * 0.9, -board_half)
	host.add_child(rim)


static func add_camera(host: Node3D) -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.08
	cam.far = 200.0
	cam.current = true
	host.add_child(cam)
	return cam


static func frame_board(cam: Camera3D, board_half: float, piece_height: float, aspect: float = 0.56) -> void:
	## Fit the board AABB (frame + piece crowns) inside the view with air around
	## every edge. More overhead, no dutch roll — corners were clipping on phones.
	var margin := maxf(1.05, piece_height * 0.55)
	var half := board_half + margin
	var top := maxf(piece_height, 0.55)
	cam.fov = 40.0
	aspect = clampf(aspect, 0.40, 1.85)

	# Bounding sphere around the board so corners stay inside both FOV axes.
	var radius := sqrt(half * half * 2.0 + top * top)
	var vfov := deg_to_rad(cam.fov)
	var hfov := 2.0 * atan(tan(vfov * 0.5) * aspect)
	var dist := (radius / tan(minf(vfov, hfov) * 0.5)) * 1.16

	# ~76° from horizontal: still 3D, far rank fully visible.
	var elev := deg_to_rad(76.0)
	cam.position = Vector3(0.0, dist * sin(elev), dist * cos(elev))
	cam.look_at(Vector3(0.0, top * 0.10, 0.0), Vector3.UP)
	cam.rotation_degrees.z = 0.0
