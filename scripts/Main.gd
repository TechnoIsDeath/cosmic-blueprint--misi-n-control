extends Node3D

## Escena raíz de Cosmic Blueprint: Misión Control.
## Instancia el Centro Espacial Abierto 3D con Jugador en 1.ª Persona,
## objetos físicos recogibles (PickupItem3D) y el HUD de Terminales CRT/VHS.

func _ready() -> void:
	var room := ControlRoom3D.new()
	room.name = "ControlRoom3D"
	add_child(room)

	var hud := MissionControlHUD.new()
	hud.name = "MissionControlHUD"
	add_child(hud)
	hud.setup_with_room(room)

	if OS.get_cmdline_user_args().has("--run-self-test"):
		_run_automated_verification(room)

func _run_automated_verification(room: ControlRoom3D) -> void:
	print("[TEST] 1. Jugador 1.ª Persona instanciado en pos: %s | Mallas Traje Mark III: %d" % [
		str(room.player.global_position), room.player.suit_meshes.size()
	])
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
	get_tree().quit(0)
