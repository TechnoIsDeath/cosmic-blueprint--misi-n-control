class_name CampaignWorld
extends Node3D

## Mundo de la campaña Artemis dividido en 4 zonas independientes estilo Adopt Me:
## - ZONE_HOME (0): Interior de la casa (cinemática al despertar, arreglar cama, llegada de correo, credencial y puerta de salida)
## - ZONE_CITY (1): Ciudad larga con más de 24 edificios, avenida hacia la NASA, garita de seguridad y entrada al complejo
## - ZONE_LAUNCH_SITE (2): Complejo Espacial y Sitio de Lanzamiento importado de sitiolanzamiento (1).blend
## - ZONE_NASA_INTERIOR (3): Interior del edificio NASA (Control de Misión, Mesa Holográfica y Hangar)

const HOME_OFFSET: Vector3 = Vector3(0.0, 0.0, 500.0)
const CITY_OFFSET: Vector3 = Vector3(0.0, 0.0, 1200.0)
const SITE_OFFSET: Vector3 = Vector3(0.0, 0.0, -500.0)

var room: ControlRoom3D

var zone_home: Node3D
var zone_city: Node3D
var zone_launch_site: Node3D
var zone_nasa_addons: Node3D

# Nodos interactivos de Casa
var bed_interact: StaticBody3D
var messy_bed_node: Node3D
var neat_bed_node: Node3D
var pc_alert_label: Label3D
var badge_node: StaticBody3D

# Nodos de Ciudad / Garita
var barrier_body: StaticBody3D
var barrier_arm: Node3D

# Nodos del Sitio de Lanzamiento (sitiolanzamiento.glb)
var site_rocket_node: Node3D
var site_rocket_base_pos: Vector3 = Vector3.ZERO
var site_rocket_flame: MeshInstance3D

# Baliza 3D
var beacon: Node3D
var beacon_label: Label3D

func setup(control_room: ControlRoom3D) -> void:
	room = control_room

func _ready() -> void:
	name = "CampaignWorld"
	# Ocultar el antiguo complejo exterior de ControlRoom3D (reemplazado por sitio_lanzamiento.glb)
	if is_instance_valid(room):
		var old_ext := room.get_node_or_null("ExteriorComplex") as Node3D
		if old_ext != null:
			old_ext.visible = false
			old_ext.process_mode = Node.PROCESS_MODE_DISABLED

	_build_home_zone()
	_build_city_zone()
	_build_launch_site_zone()
	_build_nasa_interior_addons()
	_build_beacon()

	Campaign.event_fired.connect(_on_event_fired)
	Campaign.slot_loaded.connect(_on_slot_loaded)
	Campaign.zone_changed.connect(_on_zone_changed)
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.design_updated.connect(_sync_site_rocket)

	_on_slot_loaded()

# ================================================================== GESTIÓN DE ZONAS (ADOPT ME)
func _set_node_active(n: Node3D, active: bool) -> void:
	if not is_instance_valid(n):
		return
	n.visible = active
	n.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

func _apply_active_zone(z: int, spawn_tag: String = "default", use_saved_pos: bool = false) -> void:
	_set_node_active(zone_home, z == Campaign.Zone.HOME)
	_set_node_active(zone_city, z == Campaign.Zone.CITY)
	_set_node_active(zone_launch_site, z == Campaign.Zone.LAUNCH_SITE)
	_set_node_active(zone_nasa_addons, z == Campaign.Zone.NASA_INTERIOR)

	if is_instance_valid(room):
		var b_center := room.get_node_or_null("OpenSpaceCenter") as Node3D
		var h_table := room.get_node_or_null("HoloAssemblyTable") as Node3D
		var o_globe := room.get_node_or_null("OrbitalGlobe3D") as Node3D
		var hangar := room.get_node_or_null("SupplyHangar") as Node3D
		var pickups := room.get_node_or_null("PhysicalPickups") as Node3D
		var mirror := room.mirror_root
		var in_nasa_int: bool = (z == Campaign.Zone.NASA_INTERIOR) or OS.get_cmdline_user_args().has("--run-self-test")
		_set_node_active(b_center, in_nasa_int)
		_set_node_active(h_table, in_nasa_int)
		_set_node_active(o_globe, in_nasa_int)
		_set_node_active(hangar, in_nasa_int)
		_set_node_active(pickups, in_nasa_int)
		_set_node_active(mirror, in_nasa_int)

	if not is_instance_valid(room) or not is_instance_valid(room.player):
		return

	if use_saved_pos and Campaign.saved_player_pos is Vector3:
		room.player.global_position = Campaign.saved_player_pos
		return

	var target_pos: Vector3 = HOME_OFFSET + Vector3(0.0, 0.25, 2.0)
	var target_rot_y: float = 0.0
	match z:
		Campaign.Zone.HOME:
			if spawn_tag == "from_city":
				target_pos = HOME_OFFSET + Vector3(0.0, 0.25, -4.2)
				target_rot_y = 180.0
			else:
				target_pos = HOME_OFFSET + Vector3(-3.1, 0.25, 2.6)
				target_rot_y = -90.0
		Campaign.Zone.CITY:
			if spawn_tag == "from_nasa":
				target_pos = CITY_OFFSET + Vector3(0.0, 0.25, -100.0)
				target_rot_y = 180.0
			else:
				target_pos = CITY_OFFSET + Vector3(0.0, 0.25, 104.0)
				target_rot_y = 0.0
		Campaign.Zone.LAUNCH_SITE:
			if spawn_tag == "at_pad":
				target_pos = SITE_OFFSET + Vector3(0.0, 1.3, 18.0)
				target_rot_y = 0.0
			elif spawn_tag == "from_mcc":
				target_pos = SITE_OFFSET + Vector3(6.0, 1.3, 38.0)
				target_rot_y = 90.0
			else:
				target_pos = SITE_OFFSET + Vector3(0.0, 1.3, 46.0)
				target_rot_y = 0.0
		Campaign.Zone.NASA_INTERIOR:
			if spawn_tag == "from_pad":
				target_pos = Vector3(0.0, 0.25, -9.5)
				target_rot_y = 180.0
			else:
				target_pos = Vector3(11.2, 0.25, 0.0)
				target_rot_y = 90.0

	room.player.velocity = Vector3.ZERO
	room.player.global_position = target_pos
	room.player.rotation_degrees = Vector3(0.0, target_rot_y, 0.0)
	room.player.head.rotation_degrees = Vector3.ZERO

	# Cinemática al despertar en la cama al iniciar partida nueva
	if z == Campaign.Zone.HOME and not Campaign.has_event("woke_up") and not OS.get_cmdline_user_args().has("--run-self-test"):
		room.player.play_wakeup_cinematic(
			HOME_OFFSET + Vector3(-5.1, 0.82, 2.6),
			HOME_OFFSET + Vector3(-3.1, 0.25, 2.6)
		)

func _on_zone_changed(new_zone: int, spawn_tag: String) -> void:
	_apply_active_zone(new_zone, spawn_tag, false)

func _on_slot_loaded() -> void:
	_sync_bed()
	_sync_badge()
	_sync_site_rocket()
	if Campaign.has_event("show_badge"):
		_open_barrier(true)
	elif is_instance_valid(barrier_arm):
		barrier_arm.rotation_degrees = Vector3.ZERO
	_apply_active_zone(Campaign.current_zone, "default", true)

# ================================================================== HELPERS 3D
func _mat(col: Color, emission_energy: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.roughness = 0.78
	if alpha < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emission_energy
	return m

func _box(parent: Node3D, sz: Vector3, pos: Vector3, mat: Material, solid: bool = true) -> Node3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = mat
	if not solid:
		mi.position = pos
		parent.add_child(mi)
		return mi
	var sb := StaticBody3D.new()
	sb.position = pos
	parent.add_child(sb)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = sz
	col.shape = shape
	sb.add_child(col)
	sb.add_child(mi)
	return sb

func _cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _label(parent: Node3D, text: String, pos: Vector3, col: Color, size: int = 28, billboard: bool = true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 8
	l.modulate = col
	l.position = pos
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(l)
	return l

func _light(parent: Node3D, pos: Vector3, col: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	parent.add_child(l)
	return l

func _interactable(parent: Node3D, sz: Vector3, pos: Vector3, mat: Material, ev: String, prompt: String, extra: Dictionary = {}) -> StaticBody3D:
	var sb := _box(parent, sz, pos, mat) as StaticBody3D
	sb.set_meta("interact_type", "campaign")
	sb.set_meta("event", ev)
	sb.set_meta("prompt", prompt)
	for k in extra.keys():
		sb.set_meta(k, extra[k])
	return sb

func _portal_door(
	parent: Node3D,
	pos: Vector3,
	rot_y: float,
	target_zone: int,
	spawn_tag: String,
	title_txt: String,
	prompt_txt: String,
	glow_col: Color,
	ev: String = "",
	req: String = "",
	req_msg: String = ""
) -> StaticBody3D:
	var door := StaticBody3D.new()
	door.position = pos
	door.rotation_degrees = Vector3(0.0, rot_y, 0.0)
	door.set_meta("interact_type", "zone_portal")
	door.set_meta("target_zone", target_zone)
	door.set_meta("spawn_tag", spawn_tag)
	door.set_meta("prompt", prompt_txt)
	if ev != "":
		door.set_meta("event", ev)
	if req != "":
		door.set_meta("requires", req)
		door.set_meta("requires_msg", req_msg)
	parent.add_child(door)

	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.4, 3.0, 0.65)
	col.shape = sh
	col.position = Vector3(0.0, 1.5, 0.0)
	door.add_child(col)

	# Marco y portal brillante estilo Adopt Me
	_box(door, Vector3(2.5, 3.1, 0.22), Vector3(0.0, 1.55, 0.0), _mat(Color(0.18, 0.22, 0.28)), false)
	_box(door, Vector3(2.0, 2.7, 0.26), Vector3(0.0, 1.4, 0.0), _mat(glow_col, 2.0, 0.72), false)
	_label(door, title_txt, Vector3(0.0, 3.55, 0.0), glow_col, 26)
	_light(door, Vector3(0.0, 2.2, 0.8), glow_col, 1.8, 7.0)
	return door

func _trigger_zone(parent: Node3D, pos: Vector3, radius: float, ev: String, info_id: String = "") -> Area3D:
	var area := Area3D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = radius
	col.shape = sph
	area.add_child(col)
	parent.add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is FirstPersonPlayer:
			var first: bool = not Campaign.has_event(ev)
			Campaign.notify_event(ev)
			if first and info_id != "":
				Campaign.show_info(info_id, false)
	)
	return area

func _marker(m_id: String, parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "Marker_" + m_id
	n.position = pos
	parent.add_child(n)
	Campaign.register_marker(m_id, n)
	return n

# ================================================================== ZONA 0: INTERIOR DE TU CASA
func _build_home_zone() -> void:
	zone_home = Node3D.new()
	zone_home.name = "ZoneHomeInterior"
	zone_home.position = HOME_OFFSET
	add_child(zone_home)

	var wall := _mat(Color(0.90, 0.86, 0.79))
	var floor_m := _mat(Color(0.56, 0.39, 0.25))
	var ceiling_m := _mat(Color(0.92, 0.92, 0.94))
	var wood := _mat(Color(0.46, 0.30, 0.18))

	# Suelo amplio (18m x 14m), techo y paredes cerradas
	_box(zone_home, Vector3(24.0, 0.6, 24.0), Vector3(0.0, -0.3, 0.0), floor_m)
	_box(zone_home, Vector3(18.0, 0.12, 14.0), Vector3(0.0, 0.04, 0.0), floor_m)
	_box(zone_home, Vector3(18.4, 0.3, 14.4), Vector3(0.0, 3.85, 0.0), ceiling_m)
	_box(zone_home, Vector3(18.0, 3.8, 0.3), Vector3(0.0, 1.9, 7.0), wall)       # Sur
	_box(zone_home, Vector3(18.0, 3.8, 0.3), Vector3(0.0, 1.9, -7.0), wall)      # Norte
	_box(zone_home, Vector3(0.3, 3.8, 14.0), Vector3(9.0, 1.9, 0.0), wall)       # Este
	_box(zone_home, Vector3(0.3, 3.8, 14.0), Vector3(-9.0, 1.9, 0.0), wall)      # Oeste

	# Ventanas con luz matutina
	var glass := _mat(Color(0.75, 0.92, 1.0), 1.4)
	_box(zone_home, Vector3(0.06, 1.4, 2.8), Vector3(-8.82, 2.0, 1.5), glass, false)
	_box(zone_home, Vector3(0.06, 1.4, 2.8), Vector3(8.82, 2.0, -1.5), glass, false)

	# Cama interactiva (desordenada -> arreglada al pulsar E)
	bed_interact = _interactable(
		zone_home,
		Vector3(2.4, 0.65, 3.4),
		Vector3(-5.2, 0.32, 2.6),
		wood,
		"make_bed",
		"[E] Arreglar la cama"
	)
	_box(bed_interact, Vector3(2.4, 1.2, 0.22), Vector3(0.0, 0.45, 1.6), wood, false) # Cabecero

	messy_bed_node = Node3D.new()
	bed_interact.add_child(messy_bed_node)
	_box(messy_bed_node, Vector3(2.1, 0.22, 2.6), Vector3(0.15, 0.40, -0.2), _mat(Color(0.22, 0.42, 0.78)), false).rotation_degrees = Vector3(4.0, 14.0, -6.0)
	_box(messy_bed_node, Vector3(1.4, 0.25, 1.5), Vector3(-0.3, 0.52, -0.6), _mat(Color(0.30, 0.55, 0.90)), false).rotation_degrees = Vector3(-8.0, -22.0, 10.0)
	_box(messy_bed_node, Vector3(0.95, 0.20, 0.65), Vector3(-0.35, 0.48, 1.05), _mat(Color(0.96, 0.96, 0.98)), false).rotation_degrees = Vector3(0.0, 24.0, 6.0)
	_label(messy_bed_node, "CAMA DESORDENADA\n[Pulsa E para arreglarla]", Vector3(0.0, 1.25, 0.0), Color(1.0, 0.88, 0.35), 22)

	neat_bed_node = Node3D.new()
	bed_interact.add_child(neat_bed_node)
	_box(neat_bed_node, Vector3(2.2, 0.22, 3.0), Vector3(0.0, 0.38, -0.05), _mat(Color(0.20, 0.40, 0.76)), false)
	_box(neat_bed_node, Vector3(2.22, 0.24, 0.55), Vector3(0.0, 0.40, 0.85), _mat(Color(0.92, 0.94, 0.98)), false)
	_box(neat_bed_node, Vector3(1.6, 0.20, 0.65), Vector3(0.0, 0.52, 1.15), _mat(Color(0.98, 0.98, 1.0)), false)
	_label(neat_bed_node, "✔ Cama arreglada", Vector3(0.0, 1.15, 0.0), Color(0.45, 1.0, 0.65), 20)

	_marker("home_bed", zone_home, Vector3(-5.2, 1.1, 2.6))

	# Alfombra, sofá, mesa y cocina decorativa
	_box(zone_home, Vector3(3.6, 0.05, 2.6), Vector3(0.0, 0.07, 1.2), _mat(Color(0.68, 0.24, 0.22)), false)
	_box(zone_home, Vector3(3.2, 0.75, 1.1), Vector3(0.0, 0.4, 5.2), _mat(Color(0.28, 0.32, 0.40)))
	_box(zone_home, Vector3(3.8, 0.9, 0.9), Vector3(6.4, 0.45, -5.2), _mat(Color(0.82, 0.84, 0.88)))

	# Escritorio y Ordenador con correo de la NASA
	_box(zone_home, Vector3(2.6, 0.8, 1.1), Vector3(5.6, 0.4, 4.8), wood)
	_box(zone_home, Vector3(0.65, 0.9, 0.65), Vector3(5.6, 0.45, 3.6), _mat(Color(0.2, 0.22, 0.26)))
	var pc := _interactable(
		zone_home,
		Vector3(1.1, 0.75, 0.35),
		Vector3(5.6, 1.18, 5.0),
		_mat(Color(0.22, 0.78, 1.0), 1.6),
		"read_email",
		"[E] Leer correo urgente de la NASA",
		{"info": "email", "requires": "make_bed", "requires_msg": "Arregla primero tu cama antes de sentarte al ordenador."}
	)
	pc_alert_label = _label(pc, "Ordenador en espera...", Vector3(0.0, 0.68, 0.0), Color(0.7, 0.85, 1.0), 22)
	_marker("home_pc", zone_home, Vector3(5.6, 1.25, 4.8))

	# Estantería con la credencial NASA
	_box(zone_home, Vector3(0.55, 2.1, 2.2), Vector3(-8.4, 1.05, -2.6), wood)
	_box(zone_home, Vector3(0.65, 0.08, 2.2), Vector3(-8.05, 1.18, -2.6), wood, false)
	_sync_badge()
	_marker("home_badge", zone_home, Vector3(-7.75, 1.40, -2.6))

	# Puerta de salida estilo Adopt Me (Casa -> Ciudad)
	_portal_door(
		zone_home,
		Vector3(0.0, 0.0, -6.75),
		0.0,
		Campaign.Zone.CITY,
		"from_home",
		"PUERTA PRINCIPAL\n[Salir a la Ciudad]",
		"[E] Salir de casa hacia la Ciudad y Ruta NASA",
		Color(0.35, 1.0, 0.65),
		"exit_home",
		"badge_taken",
		"Antes de salir de casa: arregla tu cama, lee el correo del PC y recoge tu credencial NASA."
	)
	_marker("home_door", zone_home, Vector3(0.0, 1.4, -6.2))

	_light(zone_home, Vector3(0.0, 3.4, 0.0), Color(1.0, 0.90, 0.74), 2.8, 18.0)
	_light(zone_home, Vector3(-5.0, 3.3, 2.5), Color(1.0, 0.88, 0.70), 1.8, 12.0)
	_light(zone_home, Vector3(5.0, 3.3, 3.5), Color(0.88, 0.94, 1.0), 1.8, 12.0)

func _sync_bed() -> void:
	var done: bool = Campaign.has_event("make_bed")
	if is_instance_valid(messy_bed_node):
		messy_bed_node.visible = not done
	if is_instance_valid(neat_bed_node):
		neat_bed_node.visible = done
	if is_instance_valid(bed_interact):
		bed_interact.set_meta("prompt", "Cama ya arreglada ✔" if done else "[E] Arreglar la cama")
	if is_instance_valid(pc_alert_label):
		if Campaign.has_event("read_email"):
			pc_alert_label.text = "✔ Correo NASA leído"
			pc_alert_label.modulate = Color(0.45, 1.0, 0.65)
		elif done:
			pc_alert_label.text = "🔔 ¡NUEVO CORREO DE LA NASA!\n[Pulsa E para abrir]"
			pc_alert_label.modulate = Color(1.0, 0.88, 0.25)
		else:
			pc_alert_label.text = "Ordenador personal"
			pc_alert_label.modulate = Color(0.65, 0.82, 0.95)

func _sync_badge() -> void:
	if not is_instance_valid(zone_home):
		return
	if Campaign.has_event("badge_taken"):
		if is_instance_valid(badge_node):
			badge_node.queue_free()
			badge_node = null
		return
	if is_instance_valid(badge_node):
		return
	badge_node = StaticBody3D.new()
	badge_node.position = Vector3(-7.75, 1.40, -2.6)
	badge_node.set_meta("interact_type", "campaign")
	badge_node.set_meta("event", "badge_taken")
	badge_node.set_meta("prompt", "[E] Recoger credencial NASA")
	badge_node.set_meta("requires", "read_email")
	badge_node.set_meta("requires_msg", "Lee primero el correo que acaba de llegar a tu ordenador.")
	badge_node.set_meta("consume", true)
	zone_home.add_child(badge_node)

	var bcol := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(0.50, 0.55, 0.55)
	bcol.shape = bshape
	badge_node.add_child(bcol)

	var card := _box(badge_node, Vector3(0.06, 0.36, 0.26), Vector3.ZERO, _mat(Color(0.22, 0.55, 1.0), 1.8), false)
	card.rotation_degrees = Vector3(0.0, 0.0, -10.0)
	_label(badge_node, "CREDENCIAL NASA\n[Pulsa E]", Vector3(0.0, 0.46, 0.0), Color(0.65, 0.92, 1.0), 20)

# ================================================================== ZONA 1: CIUDAD Y RUTA LARGA HACIA LA NASA
func _build_city_zone() -> void:
	zone_city = Node3D.new()
	zone_city.name = "ZoneExteriorCity"
	zone_city.position = CITY_OFFSET
	add_child(zone_city)

	var grass := _mat(Color(0.22, 0.34, 0.22))
	var road := _mat(Color(0.18, 0.19, 0.22))
	var sidewalk := _mat(Color(0.58, 0.60, 0.64))
	var line_mat := _mat(Color(1.0, 0.85, 0.22), 0.5)

	# Terreno de 200m x 280m + Avenida de 230m de largo (z = +115 a z = -115)
	_box(zone_city, Vector3(200.0, 1.0, 280.0), Vector3(0.0, -0.5, 0.0), grass)
	_box(zone_city, Vector3(10.0, 0.08, 232.0), Vector3(0.0, 0.03, 0.0), road)
	_box(zone_city, Vector3(2.8, 0.14, 232.0), Vector3(-6.4, 0.07, 0.0), sidewalk)
	_box(zone_city, Vector3(2.8, 0.14, 232.0), Vector3(6.4, 0.07, 0.0), sidewalk)

	for dz in range(106, -106, -8):
		_box(zone_city, Vector3(0.22, 0.02, 3.6), Vector3(0.0, 0.09, float(dz)), line_mat, false)

	# Fachada exterior de tu Casa en el extremo Sur (z = +112) con puerta de regreso
	_box(zone_city, Vector3(14.0, 4.2, 8.0), Vector3(0.0, 2.1, 114.0), _mat(Color(0.88, 0.82, 0.72)))
	_box(zone_city, Vector3(14.8, 0.5, 8.8), Vector3(0.0, 4.4, 114.0), _mat(Color(0.45, 0.20, 0.16)), false)
	_portal_door(
		zone_city,
		Vector3(0.0, 0.0, 109.8),
		180.0,
		Campaign.Zone.HOME,
		"from_city",
		"TU CASA",
		"[E] Entrar a tu Casa",
		Color(1.0, 0.85, 0.35)
	)

	# 26 Edificios urbanos variados a ambos lados de la avenida (z = +96 hasta z = -76)
	var b_colors: Array[Color] = [
		Color(0.82, 0.76, 0.66), Color(0.66, 0.74, 0.84), Color(0.76, 0.82, 0.78),
		Color(0.86, 0.72, 0.68), Color(0.58, 0.64, 0.74), Color(0.88, 0.86, 0.82),
	]
	var b_names: Array[String] = [
		"RESIDENCIAL AURORA", "CAFÉ ORBITAL", "SUPERMERCADO HORIZONTE", "LIBRERÍA KEPLER",
		"EDIFICIO APOLO", "FARMACIA SOLAR", "TORRE GALILEO", "HOTEL ESTELAR",
		"CENTRO MÉDICO", "OFICINAS AERO-TECH", "BANCO ATLÁNTICO", "LABORATORIO ÓPTICO",
		"TORRE ARTEMIS PLAZA", "INSTITUTO FÍSICO",
	]
	var b_idx: int = 0
	for z_pos in range(96, -80, -14):
		for side in [-1.0, 1.0]:
			var h: float = 5.5 + float((b_idx * 3) % 5) * 3.2
			var w: float = 11.0 + float(b_idx % 3) * 2.0
			var d: float = 10.0
			var x_pos: float = side * (14.5 + w * 0.5)
			var col: Color = b_colors[b_idx % b_colors.size()]
			_box(zone_city, Vector3(w, h, d), Vector3(x_pos, h * 0.5, float(z_pos)), _mat(col))
			_box(zone_city, Vector3(w + 0.6, 0.4, d + 0.6), Vector3(x_pos, h + 0.2, float(z_pos)), _mat(col.darkened(0.35)), false)
			# Ventanas iluminadas en la fachada hacia la avenida
			var win_x: float = x_pos - side * (w * 0.5 + 0.06)
			_box(zone_city, Vector3(0.08, h * 0.65, d * 0.7), Vector3(win_x, h * 0.55, float(z_pos)), _mat(Color(0.75, 0.90, 1.0), 0.7), false)
			if b_idx < b_names.size():
				var sign_l := _label(zone_city, b_names[b_idx], Vector3(win_x - side * 0.2, 3.2, float(z_pos)), Color(1.0, 0.92, 0.55), 26)
				sign_l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			b_idx += 1

	# Árboles y farolas a lo largo del recorrido
	var trunk := _mat(Color(0.36, 0.24, 0.15))
	var leaves := _mat(Color(0.20, 0.52, 0.24))
	var pole := _mat(Color(0.30, 0.32, 0.36))
	for az in range(100, -88, -12):
		for side in [-1.0, 1.0]:
			_cyl(zone_city, 0.08, 0.10, 5.2, Vector3(side * 5.6, 2.6, float(az)), pole)
			_light(zone_city, Vector3(side * 5.2, 5.3, float(az)), Color(1.0, 0.92, 0.74), 1.8, 16.0)
			_cyl(zone_city, 0.18, 0.24, 2.4, Vector3(side * 8.4, 1.2, float(az - 6)), trunk)
			var cr := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 1.5
			sm.height = 2.8
			cr.mesh = sm
			cr.material_override = leaves
			cr.position = Vector3(side * 8.4, 3.3, float(az - 6))
			zone_city.add_child(cr)

	# Carteles viales de orientación hacia la NASA
	_label(zone_city, "↑ COMPLEJO ESPACIAL NASA · 180 m", Vector3(0.0, 4.8, 70.0), Color(0.45, 1.0, 0.65), 36)
	_label(zone_city, "↑ GARITA DE SEGURIDAD NASA · 80 m", Vector3(0.0, 4.8, -10.0), Color(0.45, 1.0, 0.65), 36)

	# Valla perimetral y Garita de Seguridad en z = -92
	var fence := _mat(Color(0.55, 0.58, 0.62))
	_box(zone_city, Vector3(88.0, 2.8, 0.2), Vector3(-50.0, 1.4, -92.0), fence)
	_box(zone_city, Vector3(88.0, 2.8, 0.2), Vector3(50.0, 1.4, -92.0), fence)

	var booth := Node3D.new()
	booth.position = Vector3(6.8, 0.0, -92.0)
	zone_city.add_child(booth)
	_box(booth, Vector3(4.2, 3.2, 3.4), Vector3(0.0, 1.6, 0.0), _mat(Color(0.86, 0.88, 0.92)))
	_box(booth, Vector3(4.6, 0.3, 3.8), Vector3(0.0, 3.3, 0.0), _mat(Color(0.12, 0.26, 0.58)), false)
	_interactable(
		booth,
		Vector3(1.1, 1.8, 2.4),
		Vector3(-2.35, 1.5, 0.8),
		_mat(Color(0.45, 0.85, 1.0), 1.2),
		"show_badge",
		"[E] Mostrar credencial al guardia",
		{"requires": "badge_taken", "requires_msg": "Guardia: \"Necesitas tu credencial de la NASA.\""}
	)
	_label(booth, "GARITA DE SEGURIDAD NASA\n[Muestra tu credencial]", Vector3(0.0, 4.2, 0.0), Color(0.55, 0.88, 1.0), 28)
	_marker("gate_booth", booth, Vector3(-2.3, 1.6, 0.8))
	_marker("gate", zone_city, Vector3(0.0, 1.2, -85.0))
	_trigger_zone(zone_city, Vector3(0.0, 1.0, -85.0), 14.0, "reach:gate")

	barrier_body = StaticBody3D.new()
	barrier_body.position = Vector3(0.0, 0.0, -92.0)
	zone_city.add_child(barrier_body)
	var bcol := CollisionShape3D.new()
	var bsh := BoxShape3D.new()
	bsh.size = Vector3(10.0, 3.2, 0.45)
	bcol.shape = bsh
	bcol.position = Vector3(0.0, 1.6, 0.0)
	barrier_body.add_child(bcol)

	barrier_arm = Node3D.new()
	barrier_arm.position = Vector3(4.6, 1.15, -92.0)
	zone_city.add_child(barrier_arm)
	_box(barrier_arm, Vector3(9.2, 0.20, 0.20), Vector3(-4.6, 0.0, 0.0), _mat(Color(0.95, 0.22, 0.16), 0.7), false)

	# Portal hacia el Sitio de Lanzamiento NASA (sitiolanzamiento.glb) en z = -108
	_portal_door(
		zone_city,
		Vector3(0.0, 0.0, -108.0),
		0.0,
		Campaign.Zone.LAUNCH_SITE,
		"from_city",
		"COMPLEJO ESPACIAL NASA\n[Entrar al Sitio de Lanzamiento]",
		"[E] Entrar al Complejo Espacial NASA",
		Color(0.35, 0.88, 1.0),
		"enter_nasa_complex",
		"show_badge",
		"Muestra primero tu credencial en la garita de seguridad."
	)
	_marker("city_to_nasa", zone_city, Vector3(0.0, 1.5, -107.0))

func _open_barrier(instant: bool = false) -> void:
	if is_instance_valid(barrier_body):
		barrier_body.queue_free()
		barrier_body = null
	if is_instance_valid(barrier_arm):
		if instant:
			barrier_arm.rotation_degrees = Vector3(0.0, 0.0, -80.0)
		else:
			var tw := create_tween()
			tw.tween_property(barrier_arm, "rotation_degrees", Vector3(0.0, 0.0, -80.0), 1.1).set_trans(Tween.TRANS_SINE)

# ================================================================== ZONA 2: SITIO DE LANZAMIENTO (sitiolanzamiento.glb)
func _build_launch_site_zone() -> void:
	zone_launch_site = Node3D.new()
	zone_launch_site.name = "ZoneLaunchSite"
	zone_launch_site.position = SITE_OFFSET
	add_child(zone_launch_site)

	# Suelo físico base de seguridad bajo el modelo
	_box(zone_launch_site, Vector3(280.0, 1.0, 280.0), Vector3(0.0, -0.55, 0.0), _mat(Color(0.24, 0.30, 0.24)))

	var glb_path: String = "res://assets/models/sitio_lanzamiento.glb"
	var site_model: Node3D = null
	if ResourceLoader.exists(glb_path):
		var packed := load(glb_path) as PackedScene
		if packed != null:
			site_model = packed.instantiate() as Node3D
	if site_model == null:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var abs_p: String = ProjectSettings.globalize_path(glb_path)
		if FileAccess.file_exists(abs_p) and doc.append_from_file(abs_p, state) == OK:
			site_model = doc.generate_scene(state) as Node3D

	if site_model != null:
		zone_launch_site.add_child(site_model)
		_prepare_launch_site_meshes(site_model)

	# Portal de regreso a la Ciudad (en el lateral de la plaza del VAB, sin estorbar al edificio)
	_portal_door(
		zone_launch_site,
		Vector3(14.0, 0.0, 46.0),
		-90.0,
		Campaign.Zone.CITY,
		"from_nasa",
		"SALIDA A LA CIUDAD",
		"[E] Volver a la Avenida de la Ciudad",
		Color(1.0, 0.82, 0.30)
	)

	# Portal para entrar al Interior de Control de Misión y Laboratorio (junto a los hangares, x = 8.5, z = 40)
	_portal_door(
		zone_launch_site,
		Vector3(8.5, 0.0, 40.0),
		-90.0,
		Campaign.Zone.NASA_INTERIOR,
		"from_launch_site",
		"INTERIOR · CONTROL DE MISIÓN\n[Entrar al Edificio NASA]",
		"[E] Entrar al Centro de Control de Misión y Laboratorio",
		Color(0.35, 1.0, 0.65)
	)

	# Carteles de orientación sobre las instalaciones reales de sitiolanzamiento.glb
	var sign_mat := _mat(Color(0.08, 0.14, 0.32))
	_build_sign(zone_launch_site, "sign_vab", "visit:vab", Vector3(0.0, 0.0, 50.5), "VAB · ENSAMBLAJE", Color(1.0, 0.82, 0.30), sign_mat)
	_build_sign(zone_launch_site, "sign_training", "visit:training", Vector3(-8.5, 0.0, 40.0), "HANGARES Y ENTRENO", Color(0.45, 0.82, 1.0), sign_mat)
	_build_sign(zone_launch_site, "sign_mcc", "visit:mcc", Vector3(6.5, 0.0, 36.0), "CONTROL DE MISIÓN", Color(0.45, 1.0, 0.65), sign_mat)
	_build_sign(zone_launch_site, "sign_pad", "visit:pad", Vector3(-5.5, 0.0, 12.0), "RAMPA DE LANZAMIENTO", Color(1.0, 0.48, 0.35), sign_mat)

	# Palanca Física de Ignición frente a la rampa de sitiolanzamiento.glb
	var lever_ped := StaticBody3D.new()
	lever_ped.position = Vector3(4.5, 0.0, 14.0)
	lever_ped.set_meta("interact_type", "launch_lever")
	zone_launch_site.add_child(lever_ped)
	var lcol := CollisionShape3D.new()
	var lbox := BoxShape3D.new()
	lbox.size = Vector3(1.3, 1.6, 1.1)
	lcol.shape = lbox
	lcol.position = Vector3(0.0, 0.8, 0.0)
	lever_ped.add_child(lcol)
	_box(lever_ped, Vector3(1.2, 1.3, 0.9), Vector3(0.0, 0.65, 0.0), _mat(Color(0.90, 0.22, 0.18)), false)
	_label(lever_ped, "PALANCA DE IGNICIÓN\n[Pulsa E para despegar]", Vector3(0.0, 2.2, 0.0), Color(1.0, 0.45, 0.35), 24)

func _prepare_launch_site_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var nm: String = mi.name.to_lower()
		if "athena_rocket" in nm:
			site_rocket_node = mi
			site_rocket_base_pos = mi.position
			site_rocket_flame = _cyl(mi, 0.65, 1.35, 3.4, Vector3(0.0, -2.0, 0.0), _mat(Color(1.0, 0.55, 0.12), 4.0))
			site_rocket_flame.visible = false
		else:
			mi.create_trimesh_collision()
	for c in node.get_children():
		_prepare_launch_site_meshes(c)

func _sync_site_rocket() -> void:
	if not is_instance_valid(site_rocket_node):
		return
	var obj: Dictionary = Campaign.get_current_objective()
	var ch: int = int(obj.get("chapter", 0))
	var show_r: bool = GameState.current_phase >= CatalogData.Phase.LAUNCH_SIM or not GameState.placed_parts.is_empty() or ch >= 2
	site_rocket_node.visible = show_r

func _on_phase_changed(new_phase: int) -> void:
	_sync_site_rocket()
	if is_instance_valid(site_rocket_node):
		site_rocket_node.position = site_rocket_base_pos
		if is_instance_valid(site_rocket_flame):
			site_rocket_flame.visible = (new_phase == CatalogData.Phase.LAUNCH_SIM)

# ================================================================== ZONA 3: INTERIOR NASA (PUERTAS Y BRIEFING)
func _build_nasa_interior_addons() -> void:
	zone_nasa_addons = Node3D.new()
	zone_nasa_addons.name = "ZoneNasaInteriorAddons"
	add_child(zone_nasa_addons)

	# Terminal de Briefing Artemis II dentro de Control de Misión
	var term := _interactable(
		zone_nasa_addons,
		Vector3(1.6, 1.3, 0.9),
		Vector3(11.0, 0.65, 9.2),
		_mat(Color(0.22, 0.26, 0.32)),
		"briefing_artemis",
		"[E] Terminal de briefing: perfil de Artemis II",
		{"info": "artemis"}
	)
	term.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	_box(term, Vector3(1.2, 0.7, 0.06), Vector3(0.0, 0.55, 0.47), _mat(Color(0.2, 1.0, 0.55), 1.6), false)
	_label(term, "BRIEFING ARTEMIS II", Vector3(0.0, 1.5, 0.0), Color(0.4, 1.0, 0.6), 24)
	_marker("briefing_terminal", zone_nasa_addons, Vector3(11.0, 1.2, 9.2))

	# Puerta Norte -> Salir directo a la Rampa del Sitio de Lanzamiento
	_portal_door(
		zone_nasa_addons,
		Vector3(0.0, 0.0, -11.6),
		0.0,
		Campaign.Zone.LAUNCH_SITE,
		"at_pad",
		"SALIR A LA RAMPA DE LANZAMIENTO",
		"[E] Salir al Sitio de Lanzamiento (Rampa)",
		Color(1.0, 0.55, 0.30)
	)

	# Puerta Este -> Salir a la avenida del Sitio de Lanzamiento (VAB y Hangares)
	_portal_door(
		zone_nasa_addons,
		Vector3(13.6, 0.0, 0.0),
		-90.0,
		Campaign.Zone.LAUNCH_SITE,
		"from_mcc",
		"SALIR AL COMPLEJO EXTERIOR NASA",
		"[E] Salir al Sitio de Lanzamiento (VAB y Hangares)",
		Color(0.35, 0.90, 1.0)
	)

func _build_sign(parent: Node3D, m_id: String, ev: String, pos: Vector3, title: String, col: Color, board_mat: Material) -> void:
	var s := Node3D.new()
	s.position = pos
	parent.add_child(s)
	_cyl(s, 0.08, 0.08, 2.6, Vector3(-1.3, 1.3, 0.0), _mat(Color(0.4, 0.42, 0.45)))
	_cyl(s, 0.08, 0.08, 2.6, Vector3(1.3, 1.3, 0.0), _mat(Color(0.4, 0.42, 0.45)))
	_box(s, Vector3(3.2, 1.2, 0.12), Vector3(0.0, 2.4, 0.0), board_mat)
	_label(s, title, Vector3(0.0, 2.4, 0.08), col, 34, false)
	var back := _label(s, title, Vector3(0.0, 2.4, -0.08), col, 34, false)
	back.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	_light(s, Vector3(0.0, 3.6, 1.0), col, 1.4, 7.0)
	_marker(m_id, s, Vector3(0.0, 1.5, 0.0))
	_trigger_zone(s, Vector3(0.0, 1.0, 0.0), 8.5, ev, m_id)

# ================================================================== BALIZA Y LOOP
func _build_beacon() -> void:
	beacon = Node3D.new()
	beacon.name = "ObjectiveBeacon"
	add_child(beacon)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.25, 0.28)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var col := _cyl(beacon, 0.35, 0.35, 60.0, Vector3(0.0, 30.0, 0.0), m)
	col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_m := _mat(Color(1.0, 0.85, 0.25), 2.5)
	var ring := _cyl(beacon, 0.9, 0.9, 0.05, Vector3(0.0, 0.08, 0.0), ring_m)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon_label = _label(beacon, "▼", Vector3(0.0, 2.6, 0.0), Color(1.0, 0.88, 0.3), 64)
	beacon_label.no_depth_test = true
	_light(beacon, Vector3(0.0, 1.5, 0.0), Color(1.0, 0.85, 0.3), 1.2, 5.0)

func _process(_delta: float) -> void:
	if is_instance_valid(site_rocket_node) and GameState.current_phase == CatalogData.Phase.LAUNCH_SIM:
		site_rocket_node.position.y = site_rocket_base_pos.y + GameState.launch_altitude_km * 0.22

	if not is_instance_valid(beacon):
		return
	var target: Node3D = Campaign.get_current_target()
	if target == null:
		beacon.visible = false
		return
	var tpos: Vector3 = target.global_position
	beacon.global_position = Vector3(tpos.x, tpos.y - 1.0, tpos.z)
	beacon_label.position.y = 2.4 + sin(Time.get_ticks_msec() * 0.004) * 0.15
	var near: bool = false
	if is_instance_valid(room) and is_instance_valid(room.player):
		var d: Vector3 = room.player.global_position - beacon.global_position
		near = Vector2(d.x, d.z).length() < 2.2
	beacon.visible = not near

func _on_event_fired(ev: String) -> void:
	if ev == "make_bed":
		_sync_bed()
		Campaign.info_requested.emit("🔔 ¡Nuevo correo!", "Ha sonado tu ordenador: acaba de llegar un correo urgente de la NASA.", false)
	elif ev == "read_email":
		_sync_bed()
	elif ev == "show_badge":
		_open_barrier(false)
