class_name MissionScript
extends RefCounted

## Guion de datos de la campaña "Misión Artemis" (un solo rol: Ingeniero de Misión).
## Incluye la rutina inicial en casa (cinemática al despertar, arreglar la cama, llegada del correo),
## salida por zonas estilo Adopt Me, recorrido largo por la ciudad y el nuevo Sitio de Lanzamiento.

const CHAPTER_NAMES: Array[String] = [
	"Capítulo 0 · Casa y Ciudad",
	"Capítulo 1 · Complejo Espacial NASA",
	"Capítulo 2 · Entrenamiento",
	"Capítulo 3 · VAB: Ensamblaje SLS",
	"Capítulo 4 · Hardware de Orion",
	"Capítulo 5 · Software de vuelo",
	"Capítulo 6 · Diseño de trayectoria",
	"Capítulo 7 · Lanzamiento",
	"Capítulo 8 · Órbita terrestre alta",
	"Capítulo 9 · Inyección translunar",
	"Capítulo 10 · Sobrevuelo lunar",
	"Capítulo 11 · Reentrada y amerizaje",
]

const TABS: Array[String] = [
	"Casa", "NASA", "Entreno", "VAB", "Hardware", "Software",
	"Trayectoria", "Lanzamiento", "Órbita", "Crucero", "Luna", "Regreso",
]

static func get_objectives() -> Array:
	return [
		# ------------------------------------------------------------ CAPÍTULO 0
		{
			"id": "c0_wake",
			"chapter": 0,
			"title": "Buenos días: arregla tu cama",
			"briefing": "Acabas de despertar en tu habitación. Antes de empezar el día como Ingeniero de Misión, tiende y arregla tu cama.",
			"science": "En la Tierra dormimos en camas horizontales gracias a la gravedad (g = 9.81 m/s²). En microgravedad los astronautas duermen sujetos dentro de sacos verticales para no flotar.",
			"fact": "En la misión Artemis II los 4 astronautas duermen en sacos de dormir anclados bajo el piso de la cápsula Orion.",
			"steps": [
				{"event": "woke_up", "label": "Levántate de la cama"},
				{"event": "make_bed", "label": "Arregla la cama [E]", "marker": "home_bed"},
			],
			"achievement": "buenos_dias",
		},
		{
			"id": "c0_email",
			"chapter": 0,
			"title": "¡Te ha llegado un correo!",
			"briefing": "Al terminar de arreglar la cama ha sonado tu ordenador: acaba de entrar un correo urgente de la NASA.",
			"science": "El correo viaja como paquetes de datos a ~2/3 de la velocidad de la luz por fibra óptica. Una señal de radio a la Luna tarda ≈ 1.3 s en llegar.",
			"fact": "Durante Artemis II la comunicación con Orion se hace a través de la Red de Espacio Profundo (DSN): Goldstone, Madrid y Canberra.",
			"steps": [
				{"event": "read_email", "label": "Lee el correo recién llegado en el PC [E]", "marker": "home_pc"},
			],
			"achievement": "correo",
		},
		{
			"id": "c0_badge",
			"chapter": 0,
			"title": "Recoge tu credencial",
			"briefing": "Antes de salir de casa, recoge tu credencial de la NASA en la estantería.",
			"science": "Las credenciales usan chips RFID: el lector induce corriente electromagnética en la tarjeta (ley de Faraday) y el chip responde con tu código.",
			"fact": "El Centro Espacial Kennedy ocupa unos 570 km², casi el tamaño de una ciudad entera.",
			"steps": [
				{"event": "badge_taken", "label": "Recoge tu credencial NASA [E]", "marker": "home_badge"},
			],
			"achievement": "credencial",
		},
		{
			"id": "c0_leave",
			"chapter": 0,
			"title": "Sal de casa y ve a la NASA",
			"briefing": "Abre la puerta de tu casa para salir a la ciudad y recorre la avenida principal hasta la garita de seguridad de la NASA.",
			"science": "Velocidad media = distancia / tiempo. Mientras caminas por la avenida, recuerda que el cohete SLS supera los 100 m/s en pocos segundos tras el despegue.",
			"fact": "El SLS genera 39 MN de empuje en el despegue: un 15 % más que el Saturno V del Apolo.",
			"steps": [
				{"event": "exit_home", "label": "Sal por la puerta de tu casa [E]", "marker": "home_door"},
				{"event": "reach:gate", "label": "Recorre la ciudad hasta la garita NASA", "marker": "gate"},
			],
			"achievement": "en_camino",
		},
		# ------------------------------------------------------------ CAPÍTULO 1
		{
			"id": "c1_security",
			"chapter": 1,
			"title": "Control de seguridad NASA",
			"briefing": "Muestra tu credencial al guardia para levantar la barrera y cruza el portal de entrada al Complejo Espacial NASA.",
			"science": "La barrera gira sobre un eje con contrapeso: aplicando la ley de la palanca (F₁·d₁ = F₂·d₂) un motor pequeño levanta un brazo largo.",
			"fact": "El acceso al complejo de lanzamiento está estrictamente controlado antes de cada misión tripulada.",
			"steps": [
				{"event": "show_badge", "label": "Muestra la credencial en la garita [E]", "marker": "gate_booth"},
				{"event": "enter_nasa_complex", "label": "Entra al Complejo Espacial NASA [E]", "marker": "city_to_nasa"},
			],
			"achievement": "acceso",
		},
		{
			"id": "c1_tour",
			"chapter": 1,
			"title": "Recorrido por el Sitio de Lanzamiento",
			"briefing": "Explora el nuevo complejo espacial: visita el VAB, los Hangares de Entrenamiento/Cohetes, la Rampa de Lanzamiento y la entrada a Control de Misión.",
			"science": "Cada instalación cumple una fase crítica de ingeniería de sistemas: ensamblar en el VAB, preparar en los hangares, lanzar en la rampa y supervisar desde Control de Misión.",
			"fact": "El Edificio de Ensamblaje Vertical (VAB) y la rampa están conectados por la vía del Crawler-Transporter.",
			"steps": [
				{"event": "visit:vab", "label": "Edificio de Ensamblaje Vertical (VAB)", "marker": "sign_vab"},
				{"event": "visit:training", "label": "Hangares de Preparación y Entrenamiento", "marker": "sign_training"},
				{"event": "visit:pad", "label": "Rampa y Torre de Lanzamiento", "marker": "sign_pad"},
				{"event": "visit:mcc", "label": "Entrada a Control de Misión", "marker": "sign_mcc"},
			],
			"achievement": "orientado",
		},
		{
			"id": "c1_briefing",
			"chapter": 1,
			"title": "Dentro de Control de Misión: Briefing Artemis II",
			"briefing": "Entra por la puerta del edificio de Control de Misión y usa la terminal de briefing para revisar el plan de vuelo de Artemis II.",
			"science": "Artemis II usa una trayectoria de RETORNO LIBRE: la gravedad de la Luna curva la órbita de Orion y la devuelve a la Tierra sin encender motores grandes.",
			"fact": "Artemis II es la primera misión tripulada más allá de la órbita baja terrestre desde el Apolo 17 en 1972.",
			"steps": [
				{"event": "briefing_artemis", "label": "Entra a Control de Misión y usa la terminal de briefing [E]", "marker": "briefing_terminal"},
			],
			"achievement": "artemis",
		},
		# ------------------------------------------------------------ PRÓXIMAMENTE
		{
			"id": "c2_coming",
			"chapter": 2,
			"title": "Continuará: Entrenamiento y Ensamblaje",
			"briefing": "¡Has completado la introducción y el recorrido del complejo! Puedes ensamblar la nave en la mesa holográfica o salir al Sitio de Lanzamiento para despegar.",
			"science": "Usa las puertas con transición para moverte entre el Interior de Control de Misión, el Sitio de Lanzamiento, la Ciudad y tu Casa.",
			"fact": "Los astronautas de Artemis entrenan durante años en simuladores conectados con las consolas reales de Houston.",
			"steps": [
				{"event": "__never__", "label": "Explora libremente o ensambla y lanza el cohete", "marker": "sign_pad"},
			],
			"achievement": "",
		},
	]

static func get_achievements() -> Array:
	return [
		# Casa
		{"id": "buenos_dias", "tab": 0, "title": "Cama hecha", "desc": "Levántate con la cinemática y arregla tu cama.", "type": "task", "parent": ""},
		{"id": "correo", "tab": 0, "title": "Tienes un correo", "desc": "Lee el correo urgente de asignación a Artemis II.", "type": "task", "parent": "buenos_dias"},
		{"id": "credencial", "tab": 0, "title": "Identificado", "desc": "Recoge tu credencial de la NASA.", "type": "task", "parent": "correo"},
		{"id": "en_camino", "tab": 0, "title": "Rumbo a las estrellas", "desc": "Sal de casa y recorre la ciudad hasta la garita de la NASA.", "type": "goal", "parent": "credencial"},
		# NASA
		{"id": "acceso", "tab": 1, "title": "Acceso autorizado", "desc": "Supera el control de seguridad y entra al complejo.", "type": "task", "parent": ""},
		{"id": "orientado", "tab": 1, "title": "Conozco el complejo", "desc": "Recorre el VAB, hangares, rampa y Control de Misión.", "type": "task", "parent": "acceso"},
		{"id": "artemis", "tab": 1, "title": "Bienvenido a Artemis", "desc": "Completa el briefing dentro de Control de Misión.", "type": "goal", "parent": "orientado"},
		# Entrenamiento
		{"id": "centrifuga", "tab": 2, "title": "Aguanta los 5 g", "desc": "Supera la centrífuga sin perder la consciencia.", "type": "task", "parent": ""},
		{"id": "traje", "tab": 2, "title": "Hermético", "desc": "Comprueba el traje en la cámara de vacío.", "type": "task", "parent": "centrifuga"},
		{"id": "newton", "tab": 2, "title": "Acción y reacción", "desc": "Demuestra las tres leyes de Newton.", "type": "goal", "parent": "traje"},
		# VAB
		{"id": "srb", "tab": 3, "title": "Cimientos de fuego", "desc": "Apila los dos propulsores sólidos.", "type": "task", "parent": ""},
		{"id": "etapa_central", "tab": 3, "title": "Cuatro RS-25", "desc": "Instala la etapa central.", "type": "task", "parent": "srb"},
		{"id": "torre_completa", "tab": 3, "title": "Torre completa", "desc": "Apila el SLS completo con Orion y la torre de escape.", "type": "goal", "parent": "etapa_central"},
		# Hardware
		{"id": "energia", "tab": 4, "title": "Watts en orden", "desc": "Conecta los buses de energía sin sobrecarga.", "type": "task", "parent": ""},
		{"id": "eclss", "tab": 4, "title": "Respira hondo", "desc": "Instala el soporte vital.", "type": "task", "parent": "energia"},
		{"id": "escudo", "tab": 4, "title": "Escudo térmico", "desc": "Encuentra los bloques de Avcoat defectuosos.", "type": "goal", "parent": "eclss"},
		# Software
		{"id": "cuenta", "tab": 5, "title": "Secuencia perfecta", "desc": "Ordena la cuenta atrás.", "type": "task", "parent": ""},
		{"id": "bug", "tab": 5, "title": "Cazador de bugs", "desc": "Encuentra el error de unidades en el guiado.", "type": "task", "parent": "cuenta"},
		{"id": "redundancia", "tab": 5, "title": "Tres cerebros", "desc": "Configura la votación de computadoras redundantes.", "type": "goal", "parent": "bug"},
		# Trayectoria
		{"id": "ventana", "tab": 6, "title": "Ventana abierta", "desc": "Elige la ventana de lanzamiento correcta.", "type": "task", "parent": ""},
		{"id": "tsiolkovsky", "tab": 6, "title": "Ecuación del cohete", "desc": "Calcula el Δv disponible.", "type": "task", "parent": "ventana"},
		{"id": "retorno_libre", "tab": 6, "title": "Retorno libre", "desc": "Diseña una trayectoria que vuelva sola a la Tierra.", "type": "goal", "parent": "tsiolkovsky"},
		# Lanzamiento
		{"id": "go", "tab": 7, "title": "¡GO para lanzamiento!", "desc": "Completa el poll GO/NO-GO.", "type": "task", "parent": ""},
		{"id": "maxq", "tab": 7, "title": "Max-Q superado", "desc": "Supera la máxima presión dinámica.", "type": "task", "parent": "go"},
		{"id": "meco", "tab": 7, "title": "En órbita", "desc": "Llega al corte de motores principales.", "type": "goal", "parent": "maxq"},
		# Órbita
		{"id": "perigeo", "tab": 8, "title": "Más alto", "desc": "Eleva el perigeo en el punto correcto.", "type": "task", "parent": ""},
		{"id": "proximidad", "tab": 8, "title": "Piloto fino", "desc": "Demostración de proximidad sin tocar la ICPS.", "type": "challenge", "parent": "perigeo"},
		# Crucero
		{"id": "tli", "tab": 9, "title": "Rumbo a la Luna", "desc": "Ejecuta la inyección translunar.", "type": "goal", "parent": ""},
		{"id": "dsn", "tab": 9, "title": "Tres antenas", "desc": "Transfiere el enlace entre las estaciones de la DSN.", "type": "task", "parent": "tli"},
		{"id": "tormenta", "tab": 9, "title": "Tormenta solar", "desc": "Protege a la tripulación de una tormenta solar.", "type": "task", "parent": "dsn"},
		# Luna
		{"id": "silencio", "tab": 10, "title": "Cara oculta", "desc": "Sobrevive a la pérdida de señal tras la Luna.", "type": "task", "parent": ""},
		{"id": "foto", "tab": 10, "title": "Postal lunar", "desc": "Fotografía las regiones objetivo.", "type": "task", "parent": "silencio"},
		{"id": "sobrevuelo", "tab": 10, "title": "Más lejos que nadie", "desc": "Completa el sobrevuelo lunar.", "type": "goal", "parent": "foto"},
		# Regreso
		{"id": "corredor", "tab": 11, "title": "Reentrada perfecta", "desc": "Mantén el ángulo de entrada a ±0.2° del ideal.", "type": "challenge", "parent": ""},
		{"id": "paracaidas", "tab": 11, "title": "Suave como una pluma", "desc": "Despliega los paracaídas a tiempo.", "type": "task", "parent": "corredor"},
		{"id": "amerizaje", "tab": 11, "title": "Bienvenidos a casa", "desc": "Amerizaje y recuperación en el Pacífico.", "type": "goal", "parent": "paracaidas"},
	]

static func get_info(info_id: String) -> Dictionary:
	match info_id:
		"email":
			return {
				"title": "CORREO ENTRANTE · Dirección de Vuelo NASA",
				"body": "Asunto: [URGENTE] Asignación oficial a ARTEMIS II\n\nBuenos días, Ingeniero. Has sido seleccionado para integrar el equipo principal de la misión Artemis II alrededor de la Luna.\n\nRecoge tu credencial de la estantería, sal de casa y recorre la avenida de la ciudad hasta la garita de seguridad del Complejo Espacial NASA.\n\n— Dirección de Vuelo",
			}
		"artemis":
			return {
				"title": "BRIEFING · Perfil de misión Artemis II",
				"body": "• Vehículo: cohete SLS Block 1 + nave Orion con su Módulo de Servicio Europeo (ESM).\n• Tripulación: 4 astronautas.  Duración: ≈ 10 días.\n\nFASES:\n1. Lanzamiento desde el Sitio de Lanzamiento y puesta en órbita.\n2. Órbita terrestre alta (≈ 24 h): pruebas de sistemas y maniobra de proximidad.\n3. Inyección translunar (TLI): aceleración de ≈ 3.1 km/s hacia la Luna.\n4. Sobrevuelo por la cara oculta en trayectoria de RETORNO LIBRE.\n5. Reentrada a ≈ 11 km/s (≈ 2 760 °C) y amerizaje en el Pacífico.",
			}
		"sign_training":
			return {"title": "HANGARES DE PREPARACIÓN Y ENTRENAMIENTO", "body": "Aquí se revisan los subsistemas de vuelo y se entrena la tripulación antes de trasladar el cohete a la rampa."}
		"sign_vab":
			return {"title": "VAB · EDIFICIO DE ENSAMBLAJE VERTICAL", "body": "En este edificio de gran altura se integran las etapas del vehículo de lanzamiento antes de salir hacia la plataforma."}
		"sign_mcc":
			return {"title": "ENTRADA · CENTRO DE CONTROL DE MISIÓN", "body": "Cruza la puerta para entrar al edificio de Control de Misión y Laboratorio de Ensamblaje."}
		"sign_pad":
			return {"title": "SITIO DE LANZAMIENTO", "body": "Complejo de lanzamiento con torre umbilical, mástil de servicio y cohete listo para las pruebas de ignición."}
	return {}
