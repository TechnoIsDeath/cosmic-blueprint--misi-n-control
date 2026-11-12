extends Node

## Singleton global que coordina los 4 roles asimétricos, las 4 fases, la física orbital y red cooperativa.

signal phase_changed(new_phase: int)
signal role_changed(new_role: int)
signal design_updated()
signal telemetry_updated()
signal crisis_triggered(crisis_data: Dictionary)
signal log_message_added(msg: String)
signal conflict_updated()

var current_phase: int = CatalogData.Phase.BRIEFING
var current_role: int = CatalogData.Role.DIRECTOR
var sandbox_mode: bool = false
var current_mission_idx: int = 0

# Estado del diseño de la nave
var placed_parts: Array[Dictionary] = []
var disabled_part_indices: Array[int] = []
var selected_rocket_id: String = "vektor_light"
var target_altitude_km: float = 550.0
var target_inclination_deg: float = 52.0
var antenna_freq_mhz: float = 2200.0
var optimal_freq_mhz: float = 2250.0

# Cola de peticiones y conflictos entre roles (Asimetría)
var requested_science_parts: Array[String] = []
var team_conflicts: Array[Dictionary] = []
var comms_log: Array[String] = []

# Telemetría en vivo (Fase 3 y Fase 4)
var launch_progress: float = 0.0
var launch_altitude_km: float = 0.0
var launch_velocity_ms: float = 0.0
var launch_failed: bool = false
var launch_fail_reason: String = ""

var battery_wh: float = 200.0
var max_battery_wh: float = 200.0
var rcs_fuel_left: float = 25.0
var attitude_error_deg: float = 0.0
var collected_data_gb: float = 0.0
var target_data_gb: float = 35.0
var orbit_time_sec: float = 0.0
var orbit_duration_sec: float = 45.0
var active_crisis: Dictionary = {}
var crisis_timer: float = 0.0
var next_crisis_cooldown: float = 9.0

# Informe final para recibo matricial
var last_receipt: Dictionary = {}

# Slots 3D alrededor del Bus Central en la Mesa Holográfica
const HOLO_SLOTS: Array[Vector3] = [
	Vector3(0.95, 0.0, 0.0),
	Vector3(-0.95, 0.0, 0.0),
	Vector3(0.0, 0.0, 0.95),
	Vector3(0.0, 0.0, -0.95),
	Vector3(0.0, 0.78, 0.0),
	Vector3(0.0, -0.78, 0.0),
	Vector3(0.75, 0.58, 0.75),
	Vector3(-0.75, 0.58, 0.75),
	Vector3(0.75, 0.58, -0.75),
	Vector3(-0.75, 0.58, -0.75)
]

func _ready() -> void:
	load_mission(0, false)

func load_mission(index: int, is_sandbox: bool = false) -> void:
	var missions: Array[Dictionary] = CatalogData.get_missions()
	current_mission_idx = clampi(index, 0, missions.size() - 1)
	sandbox_mode = is_sandbox
	placed_parts.clear()
	disabled_part_indices.clear()
	requested_science_parts.clear()
	team_conflicts.clear()
	comms_log.clear()
	
	var m: Dictionary = get_current_mission()
	selected_rocket_id = "vektor_light"
	target_altitude_km = clampf(float(m["target_alt_min"]) * 0.85, 220.0, 36000.0)
	target_inclination_deg = float(m["target_inc_min"]) + 5.0
	optimal_freq_mhz = 2150.0 + float(current_mission_idx) * 320.0
	antenna_freq_mhz = optimal_freq_mhz - 180.0
	orbit_duration_sec = float(m["duration_sec"])
	target_data_gb = float(m["min_science"]) * 0.55

	# Conflictos iniciales de ejemplo para el Director de Misión
	_seed_team_conflicts()
	
	add_log("[SISTEMA] Misión cargada: %s (%s)" % [m["title"], "MODO SANDBOX" if sandbox_mode else "CAMPAÑA"])
	set_phase(CatalogData.Phase.BRIEFING)
	design_updated.emit()

func _seed_team_conflicts() -> void:
	team_conflicts = [
		{
			"id": "conflict_power_vs_sci",
			"title": "Dilema: Presupuesto de Carga Útil vs Reserva Solar",
			"desc": "Científico pide instalar Cámara Multiespectral ya; Ingeniero exige primero un Panel Solar Silicio-80.",
			"option_a_label": "Aprobar Cámara Científica (+Ciencia)",
			"option_a_part": "sci_cam",
			"option_b_label": "Aprobar Panel Solar (+180W Energía)",
			"option_b_part": "solar_std",
			"resolved": false
		},
		{
			"id": "conflict_comms_vs_rcs",
			"title": "Dilema: Estabilidad Orbital vs Antena de Datos",
			"desc": "Vuelo solicita Antena Dipolo UHF/S; Ingeniería advierte que sin Módulo RCS las tormentas desviarán la nave.",
			"option_a_label": "Priorizar Antena UHF/S (+32 Mbps)",
			"option_a_part": "ant_omni",
			"option_b_label": "Priorizar Módulo RCS (+Combustible/DV)",
			"option_b_part": "rcs_thruster",
			"resolved": false
		}
	]
	conflict_updated.emit()

func resolve_conflict(conflict_idx: int, choose_a: bool) -> void:
	if conflict_idx < 0 or conflict_idx >= team_conflicts.size():
		return
	var c: Dictionary = team_conflicts[conflict_idx]
	if c.get("resolved", false):
		return
	var part_id: String = c["option_a_part"] if choose_a else c["option_b_part"]
	var label: String = c["option_a_label"] if choose_a else c["option_b_label"]
	if add_part_to_assembly(part_id):
		c["resolved"] = true
		add_log("[DIRECTOR] Conflicto resuelto -> %s" % label)
		conflict_updated.emit()

func get_current_mission() -> Dictionary:
	var missions: Array[Dictionary] = CatalogData.get_missions()
	return missions[clampi(current_mission_idx, 0, missions.size() - 1)]

func get_budget_limit() -> float:
	if sandbox_mode:
		return 9999.0
	return float(get_current_mission()["budget"])

func evaluate_current_design() -> Dictionary:
	return AeroPhysics.evaluate_spacecraft(
		placed_parts,
		selected_rocket_id,
		target_altitude_km,
		target_inclination_deg,
		antenna_freq_mhz,
		optimal_freq_mhz,
		disabled_part_indices
	)

func set_role(new_role: int) -> void:
	current_role = clampi(new_role, 0, 3)
	role_changed.emit(current_role)

func set_phase(new_phase: int) -> void:
	current_phase = new_phase
	if current_phase == CatalogData.Phase.LAUNCH_SIM:
		_init_launch_simulation()
	elif current_phase == CatalogData.Phase.ORBIT_OPS:
		_init_orbit_operations()
	phase_changed.emit(current_phase)

func add_log(msg: String) -> void:
	comms_log.push_front(msg)
	if comms_log.size() > 30:
		comms_log.resize(30)
	log_message_added.emit(msg)

func request_science_part(part_id: String) -> void:
	var part: Dictionary = CatalogData.get_part_by_id(part_id)
	if part.is_empty():
		return
	requested_science_parts.append(part_id)
	add_log("[CIENTÍFICO] Solicita montar en mesa 3D: %s ($%dM, %d kg)" % [
		part["name"], int(part["cost"]), int(part["mass"])
	])
	design_updated.emit()

func add_part_to_assembly(part_id: String, custom_rot_y: float = 0.0) -> bool:
	if placed_parts.size() >= HOLO_SLOTS.size():
		add_log("[INGENIERÍA] ¡Mesa holográfica sin ranuras estructurales libres!")
		return false
	var part: Dictionary = CatalogData.get_part_by_id(part_id)
	if part.is_empty():
		return false
	var stats: Dictionary = evaluate_current_design()
	if not sandbox_mode and (float(stats["total_cost"]) + float(part["cost"]) > get_budget_limit()):
		add_log("[PRESUPUESTO] Rechazado %s: excede el límite de $%dM." % [part["name"], int(get_budget_limit())])
		return false
	
	var slot_idx: int = placed_parts.size()
	placed_parts.append({
		"part_id": part_id,
		"slot_pos": HOLO_SLOTS[slot_idx],
		"rot_y": custom_rot_y
	})
	# Si estaba en la lista de peticiones del científico, quitar una instancia
	var req_idx: int = requested_science_parts.find(part_id)
	if req_idx != -1:
		requested_science_parts.remove_at(req_idx)

	add_log("[INGENIERO] Pieza acoplada en ranura #%d: %s" % [slot_idx + 1, part["name"]])
	design_updated.emit()
	return true

func remove_part_at(index: int) -> void:
	if index < 0 or index >= placed_parts.size():
		return
	var p_id: String = placed_parts[index]["part_id"]
	var part: Dictionary = CatalogData.get_part_by_id(p_id)
	placed_parts.remove_at(index)
	# Reasignar posiciones de slots
	for i in range(placed_parts.size()):
		placed_parts[i]["slot_pos"] = HOLO_SLOTS[i]
	disabled_part_indices.clear()
	add_log("[INGENIERO] Pieza desmontada: %s" % part.get("name", p_id))
	design_updated.emit()

func rotate_last_part() -> void:
	if placed_parts.is_empty():
		return
	var last_idx: int = placed_parts.size() - 1
	placed_parts[last_idx]["rot_y"] = fmod(float(placed_parts[last_idx]["rot_y"]) + 45.0, 360.0)
	design_updated.emit()

func select_rocket(rocket_id: String) -> void:
	var rocket: Dictionary = CatalogData.get_rocket_by_id(rocket_id)
	var stats: Dictionary = evaluate_current_design()
	var new_cost: float = float(stats["parts_cost"]) + float(rocket["cost"])
	if not sandbox_mode and new_cost > get_budget_limit():
		add_log("[VUELO] Presupuesto insuficiente para el cohete %s ($%dM)." % [rocket["name"], int(rocket["cost"])])
		return
	selected_rocket_id = rocket_id
	add_log("[VUELO] Vehículo de lanzamiento seleccionado: %s" % rocket["name"])
	design_updated.emit()

func set_orbital_parameters(alt_km: float, inc_deg: float) -> void:
	target_altitude_km = clampf(alt_km, 160.0, 38000.0)
	target_inclination_deg = clampf(inc_deg, 0.0, 105.0)
	design_updated.emit()

func set_antenna_frequency(freq_mhz: float) -> void:
	antenna_freq_mhz = clampf(freq_mhz, 1500.0, 3500.0)
	design_updated.emit()

func load_recommended_preset() -> void:
	placed_parts.clear()
	disabled_part_indices.clear()
	var m: Dictionary = get_current_mission()
	if current_mission_idx == 0:
		selected_rocket_id = "vektor_light"
		target_altitude_km = 550.0
		target_inclination_deg = 60.0
		add_part_to_assembly("solar_std")
		add_part_to_assembly("battery_nih2")
		add_part_to_assembly("rcs_thruster")
		add_part_to_assembly("ant_omni")
		add_part_to_assembly("sci_cam")
		add_part_to_assembly("sci_ir")
	elif current_mission_idx == 1:
		selected_rocket_id = "atlas_medium"
		target_altitude_km = 4200.0
		target_inclination_deg = 42.0
		add_part_to_assembly("solar_xl")
		add_part_to_assembly("battery_nih2")
		add_part_to_assembly("rcs_thruster")
		add_part_to_assembly("ant_dish")
		add_part_to_assembly("sci_ir")
		add_part_to_assembly("sci_mag")
	else:
		selected_rocket_id = "sputnik_heavy"
		target_altitude_km = 35786.0
		target_inclination_deg = 4.0
		add_part_to_assembly("solar_xl")
		add_part_to_assembly("battery_nih2")
		add_part_to_assembly("apogee_motor")
		add_part_to_assembly("ant_dish")
		add_part_to_assembly("sci_sar")
		add_part_to_assembly("sci_mag")
	antenna_freq_mhz = optimal_freq_mhz
	target_altitude_km = clampf(target_altitude_km, float(m["target_alt_min"]), float(m["target_alt_max"]))
	add_log("[SISTEMA] Configuración de ingeniería de referencia cargada.")
	design_updated.emit()

# ==========================================================
# FASE 3: SIMULACIÓN DE LANZAMIENTO FÍSICO
# ==========================================================
func _init_launch_simulation() -> void:
	launch_progress = 0.0
	launch_altitude_km = 0.0
	launch_velocity_ms = 0.0
	launch_failed = false
	launch_fail_reason = ""
	add_log("[LANZAMIENTO] Ignición de motores principales. T-0.")

func step_launch_simulation(delta: float) -> void:
	if current_phase != CatalogData.Phase.LAUNCH_SIM:
		return
	var stats: Dictionary = evaluate_current_design()
	launch_progress += delta * 0.16

	# Comprobación 1: Exceso de masa / TWR < 1.0
	if float(stats["total_mass"]) > float(stats["max_payload"]) or float(stats["twr"]) < 1.0:
		launch_altitude_km = max(0.0, sin(launch_progress * PI) * 18.0)
		launch_velocity_ms = max(0.0, 220.0 * (0.5 - launch_progress))
		if launch_progress >= 0.48 and not launch_failed:
			launch_failed = true
			launch_fail_reason = "FALLO DE PROPULSIÓN EN ASCENSO: La masa total (%.0f kg) superó la capacidad estructural del cohete (%.0f kg), reduciendo la relación Empuje/Peso (TWR %.2f) por debajo del umbral de ascenso." % [
				stats["total_mass"], stats["max_payload"], stats["twr"]
			]
			add_log("[ALERTA ROJA] " + launch_fail_reason)
			finish_mission(false, launch_fail_reason)
		telemetry_updated.emit()
		return

	# Comprobación 2: Delta-V insuficiente para alcanzar la altitud objetivo
	if float(stats["available_dv"]) < float(stats["required_dv"]):
		launch_altitude_km = lerpf(0.0, target_altitude_km * 0.55, clampf(launch_progress, 0.0, 1.0))
		launch_velocity_ms = lerpf(0.0, float(stats["available_dv"]), clampf(launch_progress, 0.0, 1.0))
		if launch_progress >= 0.78 and not launch_failed:
			launch_failed = true
			launch_fail_reason = "AGOTAMIENTO DE DELTA-V EN TRANSFERENCIA: El diseño aportó %.0f m/s pero alcanzar %.0f km de altitud exigía %.0f m/s. La nave cayó en órbita suborbital inestable." % [
				stats["available_dv"], target_altitude_km, stats["required_dv"]
			]
			add_log("[ALERTA ROJA] " + launch_fail_reason)
			finish_mission(false, launch_fail_reason)
		telemetry_updated.emit()
		return

	# Ascenso nominal hacia inserción orbital
	launch_altitude_km = lerpf(0.0, target_altitude_km, clampf(launch_progress, 0.0, 1.0))
	launch_velocity_ms = lerpf(0.0, float(stats["required_dv"]), clampf(launch_progress, 0.0, 1.0))
	telemetry_updated.emit()

	if launch_progress >= 1.0:
		add_log("[ÓRBITA] Inserción orbital confirmada a %.0f km. Iniciando Fase 4." % target_altitude_km)
		set_phase(CatalogData.Phase.ORBIT_OPS)

# ==========================================================
# FASE 4: OPERACIÓN Y GESTIÓN DE CRISIS EN ÓRBITA
# ==========================================================
func _init_orbit_operations() -> void:
	var stats: Dictionary = evaluate_current_design()
	max_battery_wh = float(stats["battery_cap"])
	battery_wh = max_battery_wh * 0.85
	rcs_fuel_left = float(stats["rcs_fuel"])
	attitude_error_deg = 2.0
	collected_data_gb = 0.0
	orbit_time_sec = 0.0
	active_crisis.clear()
	next_crisis_cooldown = 7.0
	telemetry_updated.emit()

func step_orbit_operations(delta: float) -> void:
	if current_phase != CatalogData.Phase.ORBIT_OPS:
		return
	orbit_time_sec += delta
	var stats: Dictionary = evaluate_current_design()

	# Gestionar temporizador de crisis aleatorias
	if active_crisis.is_empty():
		next_crisis_cooldown -= delta
		if next_crisis_cooldown <= 0.0:
			_trigger_random_crisis()
	else:
		crisis_timer -= delta
		if crisis_timer <= 0.0:
			add_log("[TELEMETRÍA] Evento '%s' superado." % active_crisis.get("title", "Crisis"))
			active_crisis.clear()
			next_crisis_cooldown = 8.5

	# Efecto de crisis activas sobre energía y actitud
	var solar_multiplier: float = 1.0
	var extra_attitude_drift: float = 0.8
	if not active_crisis.is_empty():
		solar_multiplier = float(active_crisis.get("solar_mult", 1.0))
		extra_attitude_drift = float(active_crisis.get("drift_rate", 3.2))

	# Fricción atmosférica si la órbita es muy baja (< 340 km)
	var drag_factor: float = float(stats["atmo_drag"])
	if drag_factor > 0.0:
		rcs_fuel_left = max(0.0, rcs_fuel_left - drag_factor * 4.2 * delta)
		extra_attitude_drift += drag_factor * 4.5

	# Balance energético en tiempo real
	var effective_gen: float = float(stats["power_gen"]) * solar_multiplier
	var net_power: float = effective_gen - float(stats["power_use"])
	battery_wh = clampf(battery_wh + (net_power * delta * 0.22), 0.0, max_battery_wh)

	# Deriva de actitud (orientación de la nave)
	attitude_error_deg = clampf(attitude_error_deg + extra_attitude_drift * delta, 0.0, 90.0)

	# Recolección y transmisión de datos científicos
	var attitude_penalty: float = clampf(1.0 - (attitude_error_deg / 45.0), 0.1, 1.0)
	var effective_bw: float = float(stats["effective_bandwidth"]) * attitude_penalty
	var actual_throughput_mbps: float = min(float(stats["data_rate_mbps"]), effective_bw)
	collected_data_gb += (actual_throughput_mbps * 0.035) * delta

	telemetry_updated.emit()

	# Condiciones de fallo en órbita (Causa y Efecto)
	if battery_wh <= 0.0:
		finish_mission(
			false,
			"APAGÓN ENERGÉTICO TOTAL (BLACKOUT): El consumo de los instrumentos (%.0f W) superó la generación solar (%.0f W) y agotó las baterías de %.0f Wh durante la operación orbital." % [
				stats["power_use"], stats["power_gen"], max_battery_wh
			]
		)
		return

	if attitude_error_deg >= 65.0:
		finish_mission(
			false,
			"PÉRDIDA DE CONTROL DE ACTITUD (TUMBLING): La deriva orbital alcanzó %.1f° sin corrección de propulsores RCS, perdiendo el enlace con Misión Control." % attitude_error_deg
		)
		return

	if rcs_fuel_left <= 0.0 and drag_factor > 0.2:
		finish_mission(
			false,
			"REENTRADA ATMOSFÉRICA PREMATURA: La altitud seleccionada (%.0f km) era demasiado baja, aumentando la fricción atmosférica y agotando todo el combustible RCS de corrección." % target_altitude_km
		)
		return

	# Fin del ciclo orbital: evaluar objetivos de la misión
	if orbit_time_sec >= orbit_duration_sec:
		_evaluate_final_orbital_success(stats)

func _trigger_random_crisis() -> void:
	var crises: Array[Dictionary] = [
		{
			"id": "solar_storm",
			"title": "TORMENTA GEOMAGNÉTICA SOLAR",
			"desc": "¡Flujo de protones reduce los paneles solares al 30%! Apaguen instrumentos pesados o vigilen la batería.",
			"solar_mult": 0.30,
			"drift_rate": 2.2,
			"duration": 10.0
		},
		{
			"id": "micrometeoroid",
			"title": "IMPACTO DE MICROMETEORITO",
			"desc": "¡Impacto en el bus secundario! Desestabilización de giroscopios (+5.5°/s). Disparen vectores RCS.",
			"solar_mult": 0.85,
			"drift_rate": 5.5,
			"duration": 9.0
		},
		{
			"id": "ion_interference",
			"title": "INTERFERENCIA IONOSFÉRICA",
			"desc": "Corrimiento de frecuencia de +160 MHz. El Especialista de Vuelo debe recalibrar la antena.",
			"solar_mult": 0.90,
			"drift_rate": 1.8,
			"duration": 10.0
		}
	]
	active_crisis = crises[randi() % crises.size()].duplicate()
	crisis_timer = float(active_crisis["duration"])
	if active_crisis["id"] == "ion_interference":
		optimal_freq_mhz = clampf(optimal_freq_mhz + 140.0, 1600.0, 3400.0)
	add_log("[CRISIS ORBITAL] " + active_crisis["title"] + " - " + active_crisis["desc"])
	crisis_triggered.emit(active_crisis)

func fire_rcs_correction() -> void:
	if rcs_fuel_left < 6.0:
		add_log("[RCS] ¡Combustible de hidracina insuficiente para maniobra!")
		return
	rcs_fuel_left = max(0.0, rcs_fuel_left - 8.0)
	attitude_error_deg = max(0.0, attitude_error_deg - 18.0)
	add_log("[RCS] Impulso corrector ejecutado (-18° deriva, -8 kg RCS).")
	telemetry_updated.emit()

func toggle_instrument_power(part_idx: int) -> void:
	if part_idx < 0 or part_idx >= placed_parts.size():
		return
	if disabled_part_indices.has(part_idx):
		disabled_part_indices.erase(part_idx)
		add_log("[ENERGÍA] Módulo #%d reactivado." % [part_idx + 1])
	else:
		disabled_part_indices.append(part_idx)
		add_log("[ENERGÍA] Módulo #%d puesto en modo invernación (ahorro energético)." % [part_idx + 1])
	design_updated.emit()
	telemetry_updated.emit()

func _evaluate_final_orbital_success(stats: Dictionary) -> void:
	var m: Dictionary = get_current_mission()
	var reasons: Array[String] = []

	if target_altitude_km < float(m["target_alt_min"]) or target_altitude_km > float(m["target_alt_max"]):
		reasons.append("La altitud orbital (%.0f km) quedó fuera de la ventana requerida (%.0f - %.0f km)." % [
			target_altitude_km, m["target_alt_min"], m["target_alt_max"]
		])
	if int(stats["total_science"]) < int(m["min_science"]):
		reasons.append("Valor Científico insuficiente (%d pts instalados vs %d pts requeridos)." % [
			int(stats["total_science"]), int(m["min_science"])
		])
	if float(stats["effective_bandwidth"]) < float(m["min_bandwidth"]) * 0.75:
		reasons.append("Ancho de banda efectivo insuficiente (%.1f Mbps vs %.1f Mbps requeridos) por antena débil o descalibrada." % [
			stats["effective_bandwidth"], m["min_bandwidth"]
		])

	if reasons.is_empty():
		finish_mission(
			true,
			"MISIÓN COMPLETADA CON ÉXITO: Todos los parámetros orbitales, energéticos y de transmisión de datos operaron dentro de las tolerancias nominales."
		)
	else:
		finish_mission(false, "OBJETIVOS PARCIALMENTE INCUMPLIDOS: " + " ".join(reasons))

func finish_mission(success: bool, cause_explanation: String) -> void:
	var stats: Dictionary = evaluate_current_design()
	var m: Dictionary = get_current_mission()
	var budget_limit: float = float(m["budget"])
	var cost_ratio: float = float(stats["total_cost"]) / max(budget_limit, 1.0)
	
	var grade: String = "FALLO (F)"
	if success:
		if cost_ratio <= 0.78 and battery_wh > max_battery_wh * 0.5:
			grade = "EXCELENCIA AEROESPACIAL (S)"
		elif cost_ratio <= 0.92:
			grade = "INGENIERÍA ÓPTIMA (A)"
		else:
			grade = "MISIÓN OPERATIVA (B)"

	last_receipt = {
		"mission_title": m["title"],
		"sandbox": sandbox_mode,
		"success": success,
		"grade": grade,
		"cause_explanation": cause_explanation,
		"total_cost": stats["total_cost"],
		"budget_limit": budget_limit,
		"total_mass": stats["total_mass"],
		"max_payload": stats["max_payload"],
		"twr": stats["twr"],
		"available_dv": stats["available_dv"],
		"required_dv": stats["required_dv"],
		"power_gen": stats["power_gen"],
		"power_use": stats["power_use"],
		"effective_bandwidth": stats["effective_bandwidth"],
		"total_science": stats["total_science"],
		"min_science": m["min_science"],
		"altitude_km": target_altitude_km,
		"inclination_deg": target_inclination_deg,
		"collected_data_gb": collected_data_gb
	}
	set_phase(CatalogData.Phase.DEBRIEF)

# ==========================================================
# RED COOPERATIVA LAN (ENetMultiplayerPeer)
# ==========================================================
func host_lan_game(port: int = 7777) -> String:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 4)
	if err != OK:
		return "Error al abrir puerto %d (Código %d)" % [port, err]
	multiplayer.multiplayer_peer = peer
	add_log("[RED LAN] Servidor cooperativo activo en puerto %d (Hasta 4 jugadores)." % port)
	return "Servidor activo en puerto %d" % port

func join_lan_game(ip: String = "127.0.0.1", port: int = 7777) -> String:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return "No se pudo conectar a %s:%d" % [ip, port]
	multiplayer.multiplayer_peer = peer
	add_log("[RED LAN] Conectando a sala de control %s:%d..." % [ip, port])
	return "Conectado a %s:%d" % [ip, port]
