class_name CatalogData
extends RefCounted

## Base de datos central de misiones, piezas modulares 3D, cohetes y eventos de crisis.

enum Role {
	DIRECTOR = 0,
	ENGINEER = 1,
	SCIENTIST = 2,
	FLIGHT_SPEC = 3
}

enum Phase {
	BRIEFING = 0,
	ASSEMBLY = 1,
	LAUNCH_SIM = 2,
	ORBIT_OPS = 3,
	DEBRIEF = 4
}

const ROLE_NAMES: Dictionary = {
	Role.DIRECTOR: "DIRECTOR DE MISIÓN",
	Role.ENGINEER: "INGENIERO JEFE",
	Role.SCIENTIST: "CIENTÍFICO PRINCIPAL",
	Role.FLIGHT_SPEC: "ESPECIALISTA DE VUELO"
}

const ROLE_DESCRIPTIONS: Dictionary = {
	Role.DIRECTOR: "Gestiona el presupuesto total, selecciona misión/modo Sandbox, resuelve conflictos del equipo y autoriza cambios de fase.",
	Role.ENGINEER: "Control exclusivo de la Mesa Holográfica 3D. Ensambla módulos físicos vigilando Masa, Volumen 3D y Balance de Energía.",
	Role.SCIENTIST: "Selecciona instrumentos de carga útil para maximizar el Valor Científico y la Generación de Datos (piezas pesadas y costosas).",
	Role.FLIGHT_SPEC: "Elige el vehículo de lanzamiento, traza la órbita en el Globo Terráqueo 3D (Altitud/Inclinación) y calibra las antenas."
}

const PHASE_NAMES: Dictionary = {
	Phase.BRIEFING: "FASE 1: BRIEFING DE MISIÓN",
	Phase.ASSEMBLY: "FASE 2: ENSAMBLAJE MODULAR 3D",
	Phase.LAUNCH_SIM: "FASE 3: SIMULACIÓN Y LANZAMIENTO",
	Phase.ORBIT_OPS: "FASE 4: OPERACIÓN Y CRISIS ORBITAL",
	Phase.DEBRIEF: "INFORME MATRICIAL POST-MISIÓN"
}

static func get_missions() -> Array[Dictionary]:
	return [
		{
			"id": "leo_weather",
			"title": "OPERACIÓN BOREAL-1 (Órbita Baja LEO)",
			"budget": 175.0,
			"target_alt_min": 400.0,
			"target_alt_max": 900.0,
			"target_inc_min": 45.0,
			"target_inc_max": 98.0,
			"min_science": 60,
			"min_bandwidth": 18.0,
			"duration_sec": 45.0,
			"briefing_dialogs": [
				{
					"speaker": "COMANDANTE VANCE [CENTRAL]",
					"role_hint": "TODOS",
					"text": "Bienvenidos a Misión Control, equipo. El Ministerio Meteorológico necesita el satélite BOREAL-1 en Órbita Terrestre Baja (LEO) antes del frente ciclónico."
				},
				{
					"speaker": "DRA. KOVACS [CIENCIA]",
					"role_hint": "CIENTÍFICO PRINCIPAL",
					"text": "Necesitamos al menos 60 pts de Valor Científico. Si montamos la Cámara Multiespectral y el Radiómetro Infrarrojo lo lograremos, pero pesan bastante y generan muchos datos."
				},
				{
					"speaker": "ING. SATO [ESTRUCTURAS]",
					"role_hint": "INGENIERO JEFE",
					"text": "Cada kilo extra de ciencia nos obliga a sumar baterías, paneles solares y combustible RCS. Si la masa supera el empuje del cohete, no saldremos ni de la rampa."
				},
				{
					"speaker": "CAP. REYES [DINÁMICA DE VUELO]",
					"role_hint": "ESPECIALISTA DE VUELO",
					"text": "Atención a la altitud: debajo de 300 km la fricción atmosférica frenará la nave y agotará el combustible RCS. Apunten entre 400 km y 900 km con inclinación de 45° a 98°."
				}
			]
		},
		{
			"id": "meo_iono",
			"title": "PROYECTO HELIOS-7 (Órbita Media MEO)",
			"budget": 265.0,
			"target_alt_min": 2000.0,
			"target_alt_max": 8000.0,
			"target_inc_min": 20.0,
			"target_inc_max": 65.0,
			"min_science": 120,
			"min_bandwidth": 45.0,
			"duration_sec": 55.0,
			"briefing_dialogs": [
				{
					"speaker": "COMANDANTE VANCE [CENTRAL]",
					"role_hint": "DIRECTOR DE MISIÓN",
					"text": "HELIOS-7 estudiará la magnetosfera en Órbita Media (MEO, 2.000 a 8.000 km). El presupuesto es de $265M, pero el cohete ligero no tendrá Delta-V suficiente para subir tan alto."
				},
				{
					"speaker": "DRA. KOVACS [CIENCIA]",
					"role_hint": "CIENTÍFICO PRINCIPAL",
					"text": "Para alcanzar 120 pts científicos necesitamos el Magnetómetro de Flujo y el Espectrómetro de Plasma, o arriesgarnos con el pesado Radar SAR."
				},
				{
					"speaker": "CAP. REYES [DINÁMICA DE VUELO]",
					"role_hint": "ESPECIALISTA DE VUELO",
					"text": "A mayor distancia de la Tierra, la señal cae con el cuadrado de la distancia. Necesitaremos una Antena Parabólica bien calibrada en MHz para sostener 45 Mbps."
				}
			]
		},
		{
			"id": "geo_radar",
			"title": "CENTINELA KRONOS (Órbita Geosíncrona GEO)",
			"budget": 375.0,
			"target_alt_min": 34000.0,
			"target_alt_max": 37000.0,
			"target_inc_min": 0.0,
			"target_inc_max": 12.0,
			"min_science": 185,
			"min_bandwidth": 65.0,
			"duration_sec": 60.0,
			"briefing_dialogs": [
				{
					"speaker": "COMANDANTE VANCE [CENTRAL]",
					"role_hint": "TODOS",
					"text": "Nuestra misión más exigente: insertar el observatorio radar KRONOS en el cinturón geosíncrono (~35.786 km) con inclinación ecuatorial (0° a 12°)."
				},
				{
					"speaker": "ING. SATO [ESTRUCTURAS]",
					"role_hint": "INGENIERO JEFE",
					"text": "El Radar de Apertura Sintética (SAR) consume 420W continuos. Sin paneles desplegables XL y baterías de respaldo, las tormentas solares apagarán la nave en segundos."
				},
				{
					"speaker": "CAP. REYES [DINÁMICA DE VUELO]",
					"role_hint": "ESPECIALISTA DE VUELO",
					"text": "Solo un lanzador pesado o una nave extremadamente optimizada con motor de apogeo extra puede llegar a 35.786 km. ¡Comuníquense antes de gastar cada millón!"
				}
			]
		}
	]

static func get_parts() -> Array[Dictionary]:
	return [
		# ESTRUCTURA Y ENERGÍA (INGENIERÍA)
		{
			"id": "solar_std",
			"name": "Panel Solar Silicio-80",
			"category": "power",
			"cost": 12.0,
			"mass": 65.0,
			"power_gen": 180.0,
			"power_use": 0.0,
			"battery_cap": 150.0,
			"science": 0,
			"data_rate": 0.0,
			"bandwidth": 0.0,
			"rcs_fuel": 0.0,
			"delta_v_bonus": 0.0,
			"size": Vector3(1.5, 0.08, 0.55),
			"color": Color(0.15, 0.35, 0.85),
			"desc": "Panel fotovoltaico plegable estándar (+180W)."
		},
		{
			"id": "solar_xl",
			"name": "Ala Solar Desplegable XL",
			"category": "power",
			"cost": 28.0,
			"mass": 145.0,
			"power_gen": 440.0,
			"power_use": 0.0,
			"battery_cap": 300.0,
			"science": 0,
			"data_rate": 0.0,
			"bandwidth": 0.0,
			"rcs_fuel": 0.0,
			"delta_v_bonus": 0.0,
			"size": Vector3(2.3, 0.10, 0.75),
			"color": Color(0.10, 0.50, 0.95),
			"desc": "Matriz solar doble para cargas científicas de alto consumo (+440W)."
		},
		{
			"id": "battery_nih2",
			"name": "Celda Níquel-Hidrógeno",
			"category": "power",
			"cost": 15.0,
			"mass": 90.0,
			"power_gen": 40.0,
			"power_use": 0.0,
			"battery_cap": 950.0,
			"science": 0,
			"data_rate": 0.0,
			"bandwidth": 0.0,
			"rcs_fuel": 0.0,
			"delta_v_bonus": 0.0,
			"size": Vector3(0.55, 0.45, 0.55),
			"color": Color(0.85, 0.65, 0.15),
			"desc": "Reserva energética crítica para eclipses y tormentas solares (+950 Wh)."
		},
		{
			"id": "rcs_thruster",
			"name": "Módulo RCS Hidracina",
			"category": "propulsion",
			"cost": 18.0,
			"mass": 110.0,
			"power_gen": 0.0,
			"power_use": 20.0,
			"battery_cap": 0.0,
			"science": 0,
			"data_rate": 0.0,
			"bandwidth": 0.0,
			"rcs_fuel": 120.0,
			"delta_v_bonus": 650.0,
			"size": Vector3(0.65, 0.55, 0.65),
			"color": Color(0.90, 0.35, 0.15),
			"desc": "Vectores de empuje para control de actitud y +650 m/s de Delta-V orbital."
		},
		{
			"id": "apogee_motor",
			"name": "Motor de Apogeo Star-48",
			"category": "propulsion",
			"cost": 36.0,
			"mass": 230.0,
			"power_gen": 0.0,
			"power_use": 35.0,
			"battery_cap": 0.0,
			"science": 0,
			"data_rate": 0.0,
			"bandwidth": 0.0,
			"rcs_fuel": 180.0,
			"delta_v_bonus": 1850.0,
			"size": Vector3(0.85, 0.90, 0.85),
			"color": Color(0.80, 0.22, 0.22),
			"desc": "Etapa superior sólida para alcanzar órbitas MEO y GEO (+1850 m/s Delta-V)."
		},
		# COMUNICACIONES (VUELO / INGENIERÍA)
		{
			"id": "ant_omni",
			"name": "Antena Dipolo UHF/S",
			"category": "comms",
			"cost": 10.0,
			"mass": 35.0,
			"power_gen": 0.0,
			"power_use": 35.0,
			"battery_cap": 0.0,
			"science": 0,
			"data_rate": 0.0,
			"bandwidth": 32.0,
			"rcs_fuel": 0.0,
			"delta_v_bonus": 0.0,
			"size": Vector3(0.35, 0.95, 0.35),
			"color": Color(0.75, 0.82, 0.88),
			"desc": "Antena omnidireccional ligera para LEO (hasta 32 Mbps)."
		},
		{
			"id": "ant_dish",
			"name": "Parabólica Banda-X Alta Ganancia",
			"category": "comms",
			"cost": 26.0,
			"mass": 95.0,
			"power_gen": 0.0,
			"power_use": 85.0,
			"battery_cap": 0.0,
			"science": 0,
			"data_rate": 0.0,
			"bandwidth": 115.0,
			"rcs_fuel": 0.0,
			"delta_v_bonus": 0.0,
			"size": Vector3(1.10, 0.55, 1.10),
			"color": Color(0.92, 0.92, 0.96),
			"desc": "Plato de alta ganancia indispensable para MEO/GEO (hasta 115 Mbps)."
		},
		# CARGA ÚTIL CIENTÍFICA (CIENTÍFICO PRINCIPAL)
		{
			"id": "sci_cam",
			"name": "Cámara Multiespectral VHS-Optic",
			"category": "science",
			"cost": 22.0,
			"mass": 85.0,
			"power_gen": 0.0,
			"power_use": 75.0,
			"battery_cap": 0.0,
			"science": 45,
			"data_rate": 16.0,
			"bandwidth": 0.0,
			"rcs_fuel": 0.0,
			"delta_v_bonus": 0.0,
			"size": Vector3(0.55, 0.50, 0.70),
			"color": Color(0.20, 0.85, 0.45),
			"desc": "Sensor óptico orbital (+45 Ciencia, consume 75W, genera 16 Mbps)."
		},
		{
			"id": "sci_ir",
			"name": "Radiómetro Atmosférico IR",
			"category": "science",
			"cost": 28.0,
			"mass": 115.0,
			"power_gen": 0.0,
			"power_use": 110.0,
			"battery_cap": 0.0,
			"science": 60,
			"data_rate": 22.0,
			"bandwidth": 0.0,
			"rcs_fuel": 0.0,
			"delta_v_bonus": 0.0,
			"size": Vector3(0.65, 0.60, 0.65),
			"color": Color(0.25, 0.90, 0.70),
			"desc": "Sonda térmica de nubes y océanos (+60 Ciencia, consume 110W, 22 Mbps)."
		},
		{
			"id": "sci_mag",
			"name": "Espectrómetro de Plasma y Flujo",
			"category": "science",
			"cost": 38.0,
			"mass": 160.0,
			"power_gen": 0.0,
			"power_use": 155.0,
			"battery_cap": 0.0,
			"science": 80,
			"data_rate": 30.0,
			"bandwidth": 0.0,
			"rcs_fuel": 0.0,
			"delta_v_bonus": 0.0,
			"size": Vector3(0.75, 0.75, 0.75),
			"color": Color(0.55, 0.30, 0.95),
			"desc": "Analizador de partículas ionosféricas (+80 Ciencia, consume 155W, 30 Mbps)."
		},
		{
			"id": "sci_sar",
			"name": "Radar de Apertura Sintética (SAR)",
			"category": "science",
			"cost": 58.0,
			"mass": 310.0,
			"power_gen": 0.0,
			"power_use": 290.0,
			"battery_cap": 0.0,
			"science": 125,
			"data_rate": 52.0,
			"bandwidth": 0.0,
			"rcs_fuel": 0.0,
			"delta_v_bonus": 0.0,
			"size": Vector3(1.65, 0.45, 0.95),
			"color": Color(0.95, 0.25, 0.65),
			"desc": "Radar pesado de penetración total (+125 Ciencia, 310 kg, 290W, 52 Mbps)."
		}
	]

static func get_rockets() -> Array[Dictionary]:
	return [
		{
			"id": "vektor_light",
			"name": "VEKTOR-I (Lanzador Ligero)",
			"cost": 35.0,
			"max_payload_kg": 720.0,
			"thrust_kn": 9.5,
			"base_delta_v": 7900.0,
			"desc": "Económico para satélites pequeños en LEO. Falla si la nave supera 720 kg o intenta ir a MEO/GEO sin motor extra."
		},
		{
			"id": "atlas_medium",
			"name": "ATLAS-NOVA (Lanzador Medio)",
			"cost": 72.0,
			"max_payload_kg": 1150.0,
			"thrust_kn": 18.0,
			"base_delta_v": 9400.0,
			"desc": "Caballo de batalla versátil para cargas pesadas en LEO o misiones MEO."
		},
		{
			"id": "sputnik_heavy",
			"name": "TITAN-VULKAN (Lanzador Pesado)",
			"cost": 125.0,
			"max_payload_kg": 2200.0,
			"thrust_kn": 34.0,
			"base_delta_v": 11200.0,
			"desc": "Cohete de alta capacidad para observatorios pesados y órbitas geosíncronas (GEO)."
		}
	]

static func get_part_by_id(part_id: String) -> Dictionary:
	for p in get_parts():
		if p["id"] == part_id:
			return p
	return {}

static func get_rocket_by_id(rocket_id: String) -> Dictionary:
	for r in get_rockets():
		if r["id"] == rocket_id:
			return r
	return get_rockets()[0]
