extends Node3D

## Escena raíz de Cosmic Blueprint: Misión Control.
## Instancia el Centro Espacial Abierto 3D con Jugador en 1.ª Persona,
## objetos físicos recogibles (PickupItem3D) y el HUD de Terminales CRT/VHS.

func _ready() -> void:
	var room := ControlRoom3D.new()
	room.name = "ControlRoom3D"
	add_child(room)

	var campaign_world := CampaignWorld.new()
	campaign_world.setup(room)
	add_child(campaign_world)

	var hud := MissionControlHUD.new()
	hud.name = "MissionControlHUD"
	add_child(hud)
	hud.setup_with_room(room)

	var campaign_hud := CampaignHUD.new()
	campaign_hud.name = "CampaignHUD"
	campaign_hud.setup(room)
	add_child(campaign_hud)

	if OS.get_cmdline_user_args().has("--run-self-test"):
		_run_automated_verification(room, campaign_world)

func _run_automated_verification(room: ControlRoom3D, campaign_world: CampaignWorld) -> void:
	var mi: MeshInstance3D = room.player.suit_meshes[0] if not room.player.suit_meshes.is_empty() else null
	var suit_box: AABB = (room.player.suit_pivot.get_child(0).transform * mi.transform) * mi.get_aabb() if mi else AABB()
	print("[TEST] 1. Jugador en pos: %s | Traje Mark III AABB: %s" % [
		str(room.player.global_position), str(suit_box)
	])
	room.player.toggle_third_person()
	print("[TEST]    -> Cambio a 3.ª persona: %s | Pos cámara: %s" % [
		str(room.player.third_person), str(room.player.camera.position)
	])
	room.player.toggle_third_person()
	print("[TEST] 2. Objetos físicos 3D en el mundo (PickupItem3D): ", room.pickups_container.get_child_count())
	
	# Probar recoger un objeto físico con el jugador y acoplarlo a la nave
	var first_pickup := room.pickups_container.get_child(0) as PickupItem3D
	room.player._grab_item(first_pickup)
	print("[TEST] 3. Objeto recogido en las manos: ", room.player.held_item.display_name)
	room.player._drop_held_item()

	GameState.load_recommended_preset()
	var stats: Dictionary = GameState.evaluate_current_design()
	print("[TEST] 4. Ensamblaje 3D listo -> Piezas: %d | Masa: %.0f kg | TWR: %.2f | Ciencia: %d" % [
		GameState.placed_parts.size(), stats["total_mass"], stats["twr"], int(stats["total_science"])
	])

	GameState.set_phase(CatalogData.Phase.LAUNCH_SIM)
	for i in range(10):
		GameState.step_launch_simulation(0.8)
	print("[TEST] 5. Tras ascenso 3D -> Fase actual: ", CatalogData.PHASE_NAMES[GameState.current_phase])

	for i in range(16):
		GameState.step_orbit_operations(3.5)
		if not GameState.active_crisis.is_empty():
			GameState.fire_rcs_correction()
	print("[TEST] 6. Fin de operación orbital -> Calificación: ", GameState.last_receipt.get("grade", ""))

	# Verificar Campaña Artemis (Cinemática despertar, cama, correo, credencial, cambio de zonas Adopt Me y Sitio de Lanzamiento)
	for ev in ["woke_up", "make_bed", "read_email", "badge_taken"]:
		Campaign.notify_event(ev)
	Campaign.request_zone_change(Campaign.Zone.CITY, "from_home", "exit_home")
	for ev in ["reach:gate", "show_badge"]:
		Campaign.notify_event(ev)
	Campaign.request_zone_change(Campaign.Zone.LAUNCH_SITE, "from_city", "enter_nasa_complex")
	for ev in ["visit:vab", "visit:training", "visit:pad", "visit:mcc"]:
		Campaign.notify_event(ev)
	Campaign.request_zone_change(Campaign.Zone.NASA_INTERIOR, "from_launch_site", "briefing_artemis")
	print("[TEST] 7. Campaña Artemis -> Reto actual: %s | Zona: %d | Logros: %d/%d | Cohete sitio: %s" % [
		Campaign.get_current_objective().get("id", ""),
		Campaign.current_zone,
		Campaign.completed_count(),
		Campaign.achievements.size(),
		str(is_instance_valid(campaign_world.site_rocket_node))
	])
	get_tree().quit(0)
