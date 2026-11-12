class_name ControlRoom3D
extends Node3D

## Mundo Abierto 3D del Centro Aeroespacial:
## - Búnker Central de Misión Control con puertas abiertas al exterior
## - Mesa Holográfica 3D donde acoplas objetos físicos traídos en las manos
## - Hangar de Piezas e Ingeniería con estanterías llenas de módulos físicos (PickupItem3D) y dispensadores
## - Terreno Exterior Abierto con Antena de Espacio Profundo, Rampa de Lanzamiento y Palanca de Ignición

var player: FirstPersonPlayer
var pickups_container: Node3D
var holo_root: Node3D
var spacecraft_pivot: Node3D
var parts_container: Node3D
var globe_root: Node3D
var earth_sphere: MeshInstance3D
var orbit_ring_pivot: Node3D
var orbit_ring_mesh: MeshInstance3D
var orbit_sat_marker: MeshInstance3D
var rocket_root: Node3D
var rocket_body: Node3D
var rocket_flame: MeshInstance3D
var room_alarm_light: OmniLight3D
var exterior_dish_head: Node3D

const STATION_SPAWN_POS: Dictionary = {
	CatalogData.Role.DIRECTOR: Vector3(0.0, 0.25, 6.8),
	CatalogData.Role.ENGINEER: Vector3(-5.8, 0.25, 4.2),
	CatalogData.Role.SCIENTIST: Vector3(-5.8, 0.25, -4.2),
	CatalogData.Role.FLIGHT_SPEC: Vector3(5.8, 0.25, 3.2)
}

func _ready() -> void:
	_build_environment()
	_build_open_world_terrain_and_base()
	_build_holographic_table()
	_build_orbital_globe_3d()
	_build_hangar_and_dispensers()
	_build_exterior_dish_and_launchpad()
	_spawn_player()
	_spawn_initial_physical_items()

	GameState.design_updated.connect(_refresh_3d_visuals)
	GameState.phase_changed.connect(_on_phase_changed)
	_refresh_3d_visuals()

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.14, 0.22, 0.36)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.64, 0.78)
	env.ambient_light_energy = 1.65
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.12
	env.fog_enabled = true
	env.fog_light_color = Color(0.16, 0.24, 0.38)
	env.fog_density = 0.0018

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 2.1
	sun.shadow_enabled = true
	add_child(sun)

	room_alarm_light = OmniLight3D.new()
	room_alarm_light.position = Vector3(0.0, 5.8, 0.0)
	room_alarm_light.omni_range = 28.0
	room_alarm_light.light_color = Color(0.55, 0.90, 1.0)
	room_alarm_light.light_energy = 2.2
	add_child(room_alarm_light)

func _make_mat(col: Color, emission: Color = Color.BLACK, energy: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.roughness = 0.72
	if alpha < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m

func _add_static_box(
	parent: Node3D,
	sz: Vector3,
	pos: Vector3,
	mat: Material,
	rot_deg: Vector3 = Vector3.ZERO,
	meta_dict: Dictionary = {}
) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.position = pos
	sb.rotation_degrees = rot_deg
	for k in meta_dict.keys():
		sb.set_meta(k, meta_dict[k])
	parent.add_child(sb)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = sz
	col.shape = shape
	sb.add_child(col)

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = mat
	sb.add_child(mi)
	return sb

func _add_visual_box(parent: Node3D, sz: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

func _add_visual_cylinder(parent: Node3D, top_r: float, bot_r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	cm.radial_segments = 16
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _add_ceiling_lamp(parent: Node3D, pos: Vector3, energy: float = 2.6, range_m: float = 22.0, col: Color = Color(0.96, 0.98, 1.0)) -> void:
	var lamp_mat := _make_mat(col, col, 2.2)
	_add_visual_box(parent, Vector3(2.2, 0.14, 0.7), pos, lamp_mat)
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0.0, -0.45, 0.0)
	light.light_color = col
	light.light_energy = energy
	light.omni_range = range_m
	light.omni_attenuation = 1.2
	parent.add_child(light)

func _build_open_world_terrain_and_base() -> void:
	var world := Node3D.new()
	world.name = "OpenSpaceCenter"
	add_child(world)

	var ground_mat := _make_mat(Color(0.22, 0.27, 0.23))
	var road_mat := _make_mat(Color(0.30, 0.32, 0.36))
	var bunker_floor_mat := _make_mat(Color(0.26, 0.30, 0.36))
	var wall_mat := _make_mat(Color(0.34, 0.38, 0.44))
	var neon_cyan := _make_mat(Color(0.15, 0.9, 1.0), Color(0.15, 0.9, 1.0), 2.2)
	var neon_amber := _make_mat(Color(1.0, 0.72, 0.2), Color(1.0, 0.72, 0.2), 2.2)

	# Terreno físico abierto de 300m x 300m
	_add_static_box(world, Vector3(300.0, 1.0, 300.0), Vector3(0.0, -0.5, 0.0), ground_mat)

	# Piso amplio del Búnker Central (28m x 24m) + Hangar Oeste (24m x 24m) + Calzadas anchas (9m)
	_add_static_box(world, Vector3(28.0, 0.1, 24.0), Vector3(0.0, 0.02, 0.0), bunker_floor_mat)
	_add_static_box(world, Vector3(24.0, 0.08, 24.0), Vector3(-26.0, 0.02, 0.0), bunker_floor_mat)
	_add_static_box(world, Vector3(9.0, 0.08, 46.0), Vector3(0.0, 0.02, -31.0), road_mat) # Calzada Norte hacia el Cohete
	_add_static_box(world, Vector3(30.0, 0.08, 9.0), Vector3(24.0, 0.02, 0.0), road_mat) # Calzada Este hacia la Antena

	# Techo alto (6.8m) del Búnker y Hangar
	_add_static_box(world, Vector3(52.0, 0.4, 24.0), Vector3(-12.0, 6.8, 0.0), wall_mat)

	# Pared Trasera Sur (en z = +12)
	_add_static_box(world, Vector3(52.0, 6.8, 0.4), Vector3(-12.0, 3.4, 12.0), wall_mat)

	# Pared Norte (en z = -12) con Gran Portón Abierto de 12m de ancho
	_add_static_box(world, Vector3(32.0, 6.8, 0.4), Vector3(-22.0, 3.4, -12.0), wall_mat)
	_add_static_box(world, Vector3(8.0, 6.8, 0.4), Vector3(10.0, 3.4, -12.0), wall_mat)
	_add_static_box(world, Vector3(12.0, 1.6, 0.4), Vector3(0.0, 6.0, -12.0), wall_mat)

	# Pared Este (en x = +14) con Gran Puerta Abierta de 10m hacia la Antena Exterior
	_add_static_box(world, Vector3(0.4, 6.8, 7.0), Vector3(14.0, 3.4, -8.5), wall_mat)
	_add_static_box(world, Vector3(0.4, 6.8, 7.0), Vector3(14.0, 3.4, 8.5), wall_mat)

	# Pared Oeste del Hangar (en x = -38) con Portón Abierto en el centro
	_add_static_box(world, Vector3(0.4, 6.8, 7.5), Vector3(-38.0, 3.4, -8.25), wall_mat)
	_add_static_box(world, Vector3(0.4, 6.8, 7.5), Vector3(-38.0, 3.4, 8.25), wall_mat)

	# Lámparas industriales de techo para iluminación total en Búnker y Hangar
	for lx in [-6.5, 6.5]:
		for lz in [-5.5, 5.5]:
			_add_ceiling_lamp(world, Vector3(lx, 6.52, lz), 2.8, 24.0)
	for hx in [-19.5, -31.5]:
		for hz in [-5.5, 5.5]:
			_add_ceiling_lamp(world, Vector3(hx, 6.52, hz), 2.8, 24.0)

	# Líneas luminosas guía en el suelo
	_add_visual_box(world, Vector3(32.0, 0.04, 0.18), Vector3(-16.0, 0.08, 0.0), neon_cyan)
	_add_visual_box(world, Vector3(0.18, 0.04, 38.0), Vector3(0.0, 0.08, -22.0), neon_amber)

	# Montañas low-poly decorativas en el horizonte lejano
	var mount_mat := _make_mat(Color(0.16, 0.21, 0.28))
	for i in range(14):
		var ang: float = float(i) * (TAU / 14.0)
		var m_pos := Vector3(cos(ang) * 115.0, 10.0, sin(ang) * 115.0)
		_add_visual_cylinder(world, 2.5, 26.0, 22.0 + float(i % 3) * 7.0, m_pos, mount_mat)

	# Las 4 Terminales CRT Físicas Interactivas bien espaciadas alrededor del centro
	var console_mat := _make_mat(Color(0.32, 0.36, 0.42))
	_build_interactive_station(world, Vector3(0.0, 0.0, 8.8), 0.0, CatalogData.Role.DIRECTOR, Color(1.0, 0.80, 0.28), console_mat)
	_build_interactive_station(world, Vector3(-7.6, 0.0, 5.5), 140.0, CatalogData.Role.ENGINEER, Color(0.25, 0.92, 1.0), console_mat)
	_build_interactive_station(world, Vector3(-7.6, 0.0, -5.5), 40.0, CatalogData.Role.SCIENTIST, Color(0.38, 1.0, 0.52), console_mat)
	_build_interactive_station(world, Vector3(7.6, 0.0, 4.5), -140.0, CatalogData.Role.FLIGHT_SPEC, Color(1.0, 0.48, 0.82), console_mat)

	# Conducto de Energía y RCS Auxiliar
	var socket_mat := _make_mat(Color(0.95, 0.60, 0.18), Color(0.95, 0.55, 0.12), 1.6)
	var sock := _add_static_box(
		world,
		Vector3(1.4, 2.0, 0.9),
		Vector3(10.2, 1.0, -8.2),
		socket_mat,
		Vector3.ZERO,
		{"interact_type": "power_socket"}
	)
	var sock_lbl := Label3D.new()
	sock_lbl.text = "CONDUCTO AUXILIAR ORBITAL\n[Inserta Celdas de Batería o Tanques RCS aquí]"
	sock_lbl.font_size = 22
	sock_lbl.modulate = Color(1.0, 0.82, 0.35)
	sock_lbl.position = Vector3(0.0, 1.35, 0.0)
	sock_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sock.add_child(sock_lbl)

func _build_interactive_station(
	parent: Node3D,
	pos: Vector3,
	rot_y: float,
	role_id: int,
	glow_col: Color,
	console_mat: Material
) -> void:
	var st := _add_static_box(
		parent,
		Vector3(1.9, 1.35, 0.95),
		pos + Vector3(0.0, 0.675, 0.0),
		console_mat,
		Vector3(0.0, rot_y, 0.0),
		{"interact_type": "station_terminal", "role_id": role_id}
	)
	var screen_mat := _make_mat(glow_col * 0.35, glow_col, 1.8)
	_add_visual_box(st, Vector3(0.85, 0.55, 0.12), Vector3(0.0, 0.45, -0.15), screen_mat)

	var lbl := Label3D.new()
	lbl.text = "TERMINAL [%d]: %s\n(Pulsa E para abrir consola CRT)" % [role_id + 1, CatalogData.ROLE_NAMES[role_id]]
	lbl.font_size = 24
	lbl.modulate = glow_col
	lbl.position = Vector3(0.0, 1.15, 0.0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	st.add_child(lbl)

func _build_holographic_table() -> void:
	holo_root = Node3D.new()
	holo_root.name = "HoloAssemblyTable"
	holo_root.position = Vector3(0.0, 0.0, 0.0)
	add_child(holo_root)

	var base_mat := _make_mat(Color(0.16, 0.20, 0.26))
	var holo_surface_mat := _make_mat(Color(0.08, 0.65, 0.88), Color(0.1, 0.8, 1.0), 2.1, 0.65)

	# Pedestal físico interactivo (cuando traes una pieza en la mano y pulsas E, se acopla aquí)
	_add_static_box(
		holo_root,
		Vector3(2.6, 0.95, 2.6),
		Vector3(0.0, 0.475, 0.0),
		base_mat,
		Vector3.ZERO,
		{"interact_type": "holo_table"}
	)
	_add_visual_cylinder(holo_root, 1.38, 1.38, 0.08, Vector3(0.0, 0.98, 0.0), holo_surface_mat)

	var lbl := Label3D.new()
	lbl.text = "MESA HOLOGRÁFICA DE ENSAMBLAJE 3D\n[Trae piezas físicas del Hangar y pulsa E para acoplar | X para desacoplar]"
	lbl.font_size = 25
	lbl.modulate = Color(0.35, 0.95, 1.0)
	lbl.position = Vector3(0.0, 2.85, 0.0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	holo_root.add_child(lbl)

	spacecraft_pivot = Node3D.new()
	spacecraft_pivot.position = Vector3(0.0, 1.75, 0.0)
	holo_root.add_child(spacecraft_pivot)

	var bus_mat := _make_mat(Color(0.90, 0.70, 0.18), Color(0.35, 0.25, 0.05), 0.5)
	_add_visual_cylinder(spacecraft_pivot, 0.42, 0.42, 0.95, Vector3.ZERO, bus_mat)

	parts_container = Node3D.new()
	spacecraft_pivot.add_child(parts_container)

func _build_orbital_globe_3d() -> void:
	globe_root = Node3D.new()
	globe_root.name = "OrbitalGlobe3D"
	globe_root.position = Vector3(8.5, 1.55, -3.5)
	add_child(globe_root)

	var ped_mat := _make_mat(Color(0.18, 0.20, 0.25))
	_add_static_box(
		globe_root,
		Vector3(1.1, 1.1, 1.1),
		Vector3(0.0, -1.0, 0.0),
		ped_mat,
		Vector3.ZERO,
		{"interact_type": "station_terminal", "role_id": CatalogData.Role.FLIGHT_SPEC}
	)

	earth_sphere = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.62
	sm.height = 1.24
	earth_sphere.mesh = sm
	earth_sphere.material_override = _make_mat(Color(0.12, 0.45, 0.82), Color(0.08, 0.35, 0.68), 0.9)
	globe_root.add_child(earth_sphere)

	orbit_ring_pivot = Node3D.new()
	globe_root.add_child(orbit_ring_pivot)

	orbit_ring_mesh = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.92
	tm.outer_radius = 0.96
	orbit_ring_mesh.mesh = tm
	orbit_ring_mesh.material_override = _make_mat(Color(0.25, 1.0, 0.55), Color(0.25, 1.0, 0.55), 2.2)
	orbit_ring_pivot.add_child(orbit_ring_mesh)

	orbit_sat_marker = MeshInstance3D.new()
	var sat_box := BoxMesh.new()
	sat_box.size = Vector3(0.15, 0.15, 0.15)
	orbit_sat_marker.mesh = sat_box
	orbit_sat_marker.material_override = _make_mat(Color(1.0, 0.85, 0.2), Color(1.0, 0.85, 0.2), 2.5)
	orbit_sat_marker.position = Vector3(0.94, 0.0, 0.0)
	orbit_ring_pivot.add_child(orbit_sat_marker)

	var lbl := Label3D.new()
	lbl.text = "GLOBO ORBITAL 3D INTERACTIVO"
	lbl.font_size = 24
	lbl.modulate = Color(0.4, 1.0, 0.65)
	lbl.position = Vector3(0.0, 1.3, 0.0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	globe_root.add_child(lbl)

func _build_hangar_and_dispensers() -> void:
	var hangar := Node3D.new()
	hangar.name = "PhysicalHangar"
	add_child(hangar)

	var shelf_mat := _make_mat(Color(0.32, 0.36, 0.42))
	var disp_mat := _make_mat(Color(0.22, 0.46, 0.62), Color(0.15, 0.55, 0.78), 0.9)

	# Mesas de trabajo amplias en el Hangar Oeste (pasillo central de 17m de ancho)
	_add_static_box(hangar, Vector3(16.0, 0.75, 2.0), Vector3(-24.0, 0.375, -8.5), shelf_mat)
	_add_static_box(hangar, Vector3(16.0, 0.75, 2.0), Vector3(-24.0, 0.375, 8.5), shelf_mat)

	var h_lbl := Label3D.new()
	h_lbl.text = "HANGAR DE MÓDULOS FÍSICOS 3D Y FABRICACIÓN\n[Recoge cualquier pieza con E / Clic Izq y llévala en tus manos a la Mesa Holográfica]"
	h_lbl.font_size = 30
	h_lbl.modulate = Color(1.0, 0.88, 0.35)
	h_lbl.position = Vector3(-25.0, 4.2, 0.0)
	h_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hangar.add_child(h_lbl)

	# Terminales Dispensadoras Físicas espaciadas en el fondo del Hangar
	var all_parts: Array[Dictionary] = CatalogData.get_parts()
	for i in range(all_parts.size()):
		var p: Dictionary = all_parts[i]
		var z_pos: float = -9.5 + float(i) * 1.9
		var kiosk := _add_static_box(
			hangar,
			Vector3(0.9, 1.35, 1.0),
			Vector3(-35.8, 0.675, z_pos),
			disp_mat,
			Vector3.ZERO,
			{"interact_type": "part_dispenser", "part_id": p["id"]}
		)
		var klbl := Label3D.new()
		klbl.text = "DISPENSAR:\n%s\n($%.0fM)" % [p["name"], p["cost"]]
		klbl.font_size = 19
		klbl.modulate = p["color"].lightened(0.4)
		klbl.position = Vector3(0.55, 1.0, 0.0)
		klbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		kiosk.add_child(klbl)

func _build_exterior_dish_and_launchpad() -> void:
	var ext := Node3D.new()
	ext.name = "ExteriorComplex"
	add_child(ext)

	# 1. Antena Parabólica Gigante Exterior (Al Este del Búnker)
	var dish_base := _add_static_box(
		ext,
		Vector3(3.2, 2.4, 3.2),
		Vector3(32.0, 1.2, 0.0),
		_make_mat(Color(0.32, 0.36, 0.40)),
		Vector3.ZERO,
		{"interact_type": "dish_calibrator"}
	)
	var dish_light := OmniLight3D.new()
	dish_light.position = Vector3(0.0, 6.5, 0.0)
	dish_light.omni_range = 24.0
	dish_light.light_energy = 2.6
	dish_light.light_color = Color(0.85, 0.95, 1.0)
	dish_base.add_child(dish_light)
	exterior_dish_head = Node3D.new()
	exterior_dish_head.position = Vector3(0.0, 2.6, 0.0)
	dish_base.add_child(exterior_dish_head)
	_add_visual_cylinder(exterior_dish_head, 3.4, 0.6, 1.2, Vector3.ZERO, _make_mat(Color(0.88, 0.90, 0.95), Color(0.2, 0.5, 0.8), 0.5))

	var dlbl := Label3D.new()
	dlbl.text = "ESTACIÓN EXTERIOR DE TELEMETRÍA BANDA-X\n[Pulsa E aquí para Calibrar Frecuencia al 100%]"
	dlbl.font_size = 26
	dlbl.modulate = Color(0.4, 0.95, 1.0)
	dlbl.position = Vector3(0.0, 5.2, 0.0)
	dlbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dish_base.add_child(dlbl)

	# 2. Rampa de Lanzamiento Exterior y Palanca Física de Despegue (Al Norte del Búnker)
	var pad := Node3D.new()
	pad.position = Vector3(0.0, 0.0, -46.0)
	ext.add_child(pad)

	var pad_light := OmniLight3D.new()
	pad_light.position = Vector3(4.0, 11.0, 8.0)
	pad_light.omni_range = 36.0
	pad_light.light_energy = 3.2
	pad_light.light_color = Color(1.0, 0.94, 0.85)
	pad.add_child(pad_light)

	var concrete_mat := _make_mat(Color(0.32, 0.34, 0.36))
	var tower_mat := _make_mat(Color(0.75, 0.25, 0.16))
	_add_static_box(pad, Vector3(18.0, 0.8, 18.0), Vector3(0.0, 0.4, 0.0), concrete_mat)
	_add_static_box(pad, Vector3(1.8, 15.0, 1.8), Vector3(-4.2, 7.8, 0.0), tower_mat)
	_add_visual_box(pad, Vector3(3.4, 0.45, 0.6), Vector3(-2.0, 10.6, 0.0), tower_mat)

	# Pedestal con Palanca Física de Ignición frente a la rampa
	var lever_ped := _add_static_box(
		ext,
		Vector3(1.5, 1.35, 1.1),
		Vector3(4.5, 0.675, -24.5),
		_make_mat(Color(0.90, 0.22, 0.18), Color(0.95, 0.25, 0.15), 1.8),
		Vector3.ZERO,
		{"interact_type": "launch_lever"}
	)
	var llbl := Label3D.new()
	llbl.text = "PALANCA FÍSICA DE IGNICIÓN Y LANZAMIENTO\n[Pulsa E para despegar el cohete en vivo]"
	llbl.font_size = 24
	llbl.modulate = Color(1.0, 0.45, 0.35)
	llbl.position = Vector3(0.0, 1.25, 0.0)
	llbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lever_ped.add_child(llbl)

	rocket_root = Node3D.new()
	rocket_root.position = Vector3(0.0, 0.8, 0.0)
	pad.add_child(rocket_root)

	rocket_body = Node3D.new()
	rocket_root.add_child(rocket_body)

	var white_mat := _make_mat(Color(0.92, 0.93, 0.96), Color(0.2, 0.2, 0.25), 0.3)
	var nose_mat := _make_mat(Color(0.88, 0.22, 0.15))
	_add_visual_cylinder(rocket_body, 0.85, 1.05, 8.5, Vector3(0.0, 4.25, 0.0), white_mat)
	_add_visual_cylinder(rocket_body, 0.08, 0.85, 2.8, Vector3(0.0, 9.9, 0.0), nose_mat)

	rocket_flame = _add_visual_cylinder(
		rocket_body,
		0.75,
		1.45,
		3.6,
		Vector3(0.0, -1.6, 0.0),
		_make_mat(Color(1.0, 0.55, 0.1), Color(1.0, 0.45, 0.08), 4.2)
	)
	rocket_flame.visible = false

func _spawn_player() -> void:
	pickups_container = Node3D.new()
	pickups_container.name = "PhysicalPickups"
	add_child(pickups_container)

	player = FirstPersonPlayer.new()
	player.name = "FirstPersonPlayer"
	player.position = Vector3(0.0, 0.25, 5.6)
	player.spawn_part_requested.connect(spawn_physical_part)
	add_child(player)

func _spawn_initial_physical_items() -> void:
	# Colocar piezas físicas listas para recoger en las mesas del Hangar Oeste y cerca de la mesa
	var starter_parts: Array[String] = [
		"solar_std", "solar_xl", "battery_nih2", "rcs_thruster",
		"ant_omni", "ant_dish", "sci_cam", "sci_ir", "sci_mag", "sci_sar"
	]
	for i in range(starter_parts.size()):
		var row_z: float = -8.5 if i < 5 else 8.5
		var col_x: float = -18.0 - float(i % 5) * 2.7
		spawn_physical_part(starter_parts[i], Vector3(col_x, 1.35, row_z))

	# También dejamos 2 módulos físicos justo al lado de la Mesa Holográfica para probar al instante
	spawn_physical_part("solar_std", Vector3(-2.8, 1.1, 0.0))
	spawn_physical_part("sci_cam", Vector3(2.8, 1.1, 0.0))

	# Suministros físicos de emergencia (Celdas de Batería y Tanques RCS)
	_spawn_utility_pickup(
		PickupItem3D.ItemType.BATTERY_CELL,
		"Celda de Emergencia +380 Wh",
		"Conéctala al Conducto Auxiliar",
		Color(1.0, 0.80, 0.15),
		Vector3(0.45, 0.45, 0.45),
		Vector3(8.8, 1.0, -7.8)
	)
	_spawn_utility_pickup(
		PickupItem3D.ItemType.RCS_TANK,
		"Tanque de Hidracina +45 kg RCS",
		"Conéctalo al Conducto Auxiliar",
		Color(0.95, 0.35, 0.15),
		Vector3(0.42, 0.62, 0.42),
		Vector3(7.6, 1.0, -7.8)
	)
	_spawn_utility_pickup(
		PickupItem3D.ItemType.VHS_BRIEFING,
		"Cinta VHS: Directrices BOREAL-1",
		"Archivo Clasificado de Misión",
		Color(0.20, 0.85, 0.95),
		Vector3(0.38, 0.12, 0.25),
		Vector3(0.6, 1.5, 8.4)
	)

func spawn_physical_part(part_id: String, world_pos: Vector3) -> PickupItem3D:
	var item := PickupItem3D.new()
	item.position = world_pos
	pickups_container.add_child(item)
	item.setup_part(part_id)
	return item

func _spawn_utility_pickup(u_type: int, title: String, sub: String, col: Color, sz: Vector3, pos: Vector3) -> void:
	var item := PickupItem3D.new()
	item.position = pos
	pickups_container.add_child(item)
	item.setup_utility_item(u_type, title, sub, col, sz)

func teleport_player_to_role_station(role_id: int) -> void:
	if not is_instance_valid(player):
		return
	var target: Vector3 = STATION_SPAWN_POS.get(role_id, Vector3(0.0, 0.25, 3.6))
	player.global_position = target

func _on_phase_changed(new_phase: int) -> void:
	if new_phase == CatalogData.Phase.LAUNCH_SIM:
		rocket_root.position = Vector3(0.0, 0.8, 0.0)
		rocket_root.rotation_degrees = Vector3.ZERO
		rocket_flame.visible = true
	else:
		rocket_root.position = Vector3(0.0, 0.8, 0.0)
		rocket_root.rotation_degrees = Vector3.ZERO
		rocket_flame.visible = false

func _refresh_3d_visuals() -> void:
	if not is_instance_valid(parts_container):
		return
	for child in parts_container.get_children():
		child.queue_free()

	for i in range(GameState.placed_parts.size()):
		var entry: Dictionary = GameState.placed_parts[i]
		var part: Dictionary = CatalogData.get_part_by_id(entry.get("part_id", ""))
		if part.is_empty():
			continue
		var slot_pos: Vector3 = entry.get("slot_pos", Vector3.ZERO)
		var rot_y: float = float(entry.get("rot_y", 0.0))
		var is_off: bool = GameState.disabled_part_indices.has(i)

		var col: Color = part["color"]
		if is_off:
			col = col.darkened(0.65)
		var mat := _make_mat(col, col, 0.35 if is_off else 1.2)

		var strut_pos: Vector3 = slot_pos * 0.5
		_add_visual_box(parts_container, Vector3(0.12, 0.12, slot_pos.length()), strut_pos, _make_mat(Color(0.4, 0.5, 0.6)))

		var part_sz: Vector3 = part["size"] * 0.48
		_add_visual_box(parts_container, part_sz, slot_pos, mat, Vector3(0.0, rot_y, 0.0))

	if is_instance_valid(orbit_ring_pivot):
		orbit_ring_pivot.rotation_degrees.z = GameState.target_inclination_deg
		var ring_scale: float = lerpf(0.85, 1.55, clampf(GameState.target_altitude_km / 36000.0, 0.0, 1.0))
		orbit_ring_pivot.scale = Vector3.ONE * ring_scale

func _process(delta: float) -> void:
	if is_instance_valid(spacecraft_pivot):
		var spin_speed: float = 22.0
		if GameState.current_phase == CatalogData.Phase.ORBIT_OPS:
			spin_speed += GameState.attitude_error_deg * 2.5
			spacecraft_pivot.rotation_degrees.z = sin(Time.get_ticks_msec() * 0.004) * GameState.attitude_error_deg * 0.6
		else:
			spacecraft_pivot.rotation_degrees.z = lerpf(spacecraft_pivot.rotation_degrees.z, 0.0, delta * 5.0)
		spacecraft_pivot.rotation_degrees.y = fmod(spacecraft_pivot.rotation_degrees.y + spin_speed * delta, 360.0)

	if is_instance_valid(earth_sphere):
		earth_sphere.rotation_degrees.y = fmod(earth_sphere.rotation_degrees.y + 18.0 * delta, 360.0)
	if is_instance_valid(orbit_ring_pivot):
		orbit_ring_pivot.rotation_degrees.y = fmod(orbit_ring_pivot.rotation_degrees.y + 55.0 * delta, 360.0)
	if is_instance_valid(exterior_dish_head):
		exterior_dish_head.rotation_degrees.y = fmod(exterior_dish_head.rotation_degrees.y + 14.0 * delta, 360.0)
		exterior_dish_head.rotation_degrees.x = -25.0

	if GameState.current_phase == CatalogData.Phase.LAUNCH_SIM:
		GameState.step_launch_simulation(delta)
		var h: float = clampf(GameState.launch_progress * 32.0, 0.0, 42.0)
		var stats: Dictionary = GameState.evaluate_current_design()
		if float(stats["total_mass"]) > float(stats["max_payload"]) or float(stats["twr"]) < 1.0:
			rocket_root.position.y = 0.8 + sin(GameState.launch_progress * PI) * 3.0
			rocket_root.rotation_degrees.z = GameState.launch_progress * 72.0
		else:
			rocket_root.position.y = 0.8 + h

	if GameState.current_phase == CatalogData.Phase.ORBIT_OPS:
		GameState.step_orbit_operations(delta)

	if is_instance_valid(room_alarm_light):
		if not GameState.active_crisis.is_empty() or GameState.launch_failed:
			var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
			room_alarm_light.light_color = Color(1.0, 0.25, 0.18)
			room_alarm_light.light_energy = 1.8 + pulse * 2.2
		else:
			room_alarm_light.light_color = Color(0.55, 0.90, 1.0)
			room_alarm_light.light_energy = 2.2
