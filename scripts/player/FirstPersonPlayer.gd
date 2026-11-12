class_name FirstPersonPlayer
extends CharacterBody3D

## Controlador de Jugador en 1.ª Persona en Mundo Abierto con físicas Jolt,
## recolección física de objetos (RigidBody3D), lanzamiento, linterna e interacción 3D.

signal hover_prompt_changed(prompt: String, held_info: String)
signal terminal_toggle_requested(role_id: int)
signal spawn_part_requested(part_id: String, pos: Vector3)

const WALK_SPEED: float = 6.2
const SPRINT_SPEED: float = 10.8
const JUMP_VELOCITY: float = 6.2
const GRAVITY: float = 15.5
const MOUSE_SENSITIVITY: float = 0.16

var head: Node3D
var camera: Camera3D
var raycast: RayCast3D
var hand_anchor: Node3D
var flashlight: SpotLight3D
var left_arm_mesh: MeshInstance3D
var right_arm_mesh: MeshInstance3D
var suit_pivot: Node3D
var suit_meshes: Array[MeshInstance3D] = []
var third_person: bool = false

var held_item: PickupItem3D = null
var held_rot_y: float = 0.0
var grab_local_offset: Vector3 = Vector3.ZERO
var hold_distance: float = 1.85
var ui_open: bool = false
var bob_time: float = 0.0
var current_prompt: String = ""

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.80
	col.shape = cap
	col.position = Vector3(0.0, 0.90, 0.0)
	add_child(col)

	head = Node3D.new()
	head.position = Vector3(0.0, 1.62, 0.0)
	add_child(head)

	camera = Camera3D.new()
	camera.fov = 72.0
	camera.current = true
	head.add_child(camera)

	raycast = RayCast3D.new()
	raycast.target_position = Vector3(0.0, 0.0, -4.5)
	raycast.collision_mask = 5
	raycast.enabled = true
	camera.add_child(raycast)

	hand_anchor = Node3D.new()
	hand_anchor.position = Vector3(0.0, -0.18, -hold_distance)
	camera.add_child(hand_anchor)

	flashlight = SpotLight3D.new()
	flashlight.light_color = Color(0.95, 0.96, 1.0)
	flashlight.light_energy = 2.6
	flashlight.spot_range = 28.0
	flashlight.spot_angle = 36.0
	flashlight.visible = false
	camera.add_child(flashlight)

	_build_first_person_arms()
	_build_spacesuit_model()
	_apply_camera_perspective()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_spacesuit_model() -> void:
	suit_pivot = Node3D.new()
	suit_pivot.name = "SpacesuitPivot"
	add_child(suit_pivot)

	var suit_scene_node: Node3D = null
	var glb_path: String = "res://assets/models/mark_iii_spacesuit.glb"
	if ResourceLoader.exists(glb_path):
		var packed := load(glb_path) as PackedScene
		if packed:
			suit_scene_node = packed.instantiate() as Node3D

	if suit_scene_node == null:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var abs_path: String = ProjectSettings.globalize_path(glb_path)
		if FileAccess.file_exists(abs_path) and doc.append_from_file(abs_path, state) == OK:
			suit_scene_node = doc.generate_scene(state) as Node3D

	if suit_scene_node == null:
		return

	# Orientación para modelos Z-up: levantar verticalmente y mirar al frente (-Z)
	suit_scene_node.rotation_degrees = Vector3(-90.0, 180.0, 0.0)
	suit_pivot.add_child(suit_scene_node)

	suit_meshes.clear()
	_collect_meshes(suit_scene_node)

	# Escalar automáticamente a 1.80 m de altura y apoyar pies en y = 0.0
	var combined_height: float = 1.98
	var min_y_local: float = -0.89
	if not suit_meshes.is_empty():
		var first_aabb: AABB = suit_meshes[0].get_aabb()
		# Tras rotar -90 en X, el eje Z del AABB original corresponde a la altura (Y)
		combined_height = max(first_aabb.size.z, 0.2)
		min_y_local = first_aabb.position.z

	var target_scale: float = 1.80 / combined_height
	suit_scene_node.scale = Vector3.ONE * target_scale
	suit_scene_node.position = Vector3(0.0, -min_y_local * target_scale, 0.0)

func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		suit_meshes.append(node as MeshInstance3D)
	for c in node.get_children():
		_collect_meshes(c)

func _apply_camera_perspective() -> void:
	if third_person:
		camera.position = Vector3(0.42, 0.45, 2.75)
		raycast.target_position = Vector3(0.0, 0.0, -7.2)
		hand_anchor.position = Vector3(0.0, -0.10, -(hold_distance + 2.55))
		left_arm_mesh.visible = false
		right_arm_mesh.visible = false
		for mi in suit_meshes:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	else:
		camera.position = Vector3.ZERO
		raycast.target_position = Vector3(0.0, 0.0, -4.5)
		hand_anchor.position = Vector3(0.0, -0.18, -hold_distance)
		left_arm_mesh.visible = true
		right_arm_mesh.visible = true
		for mi in suit_meshes:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

func _build_first_person_arms() -> void:
	var arm_mat := StandardMaterial3D.new()
	arm_mat.albedo_color = Color(0.22, 0.36, 0.48)
	arm_mat.roughness = 0.55
	arm_mat.metallic = 0.3

	var bm := BoxMesh.new()
	bm.size = Vector3(0.11, 0.11, 0.55)

	left_arm_mesh = MeshInstance3D.new()
	left_arm_mesh.mesh = bm
	left_arm_mesh.material_override = arm_mat
	left_arm_mesh.position = Vector3(-0.32, -0.32, -0.45)
	left_arm_mesh.rotation_degrees = Vector3(10.0, -8.0, 0.0)
	camera.add_child(left_arm_mesh)

	right_arm_mesh = MeshInstance3D.new()
	right_arm_mesh.mesh = bm
	right_arm_mesh.material_override = arm_mat
	right_arm_mesh.position = Vector3(0.32, -0.32, -0.45)
	right_arm_mesh.rotation_degrees = Vector3(10.0, 8.0, 0.0)
	camera.add_child(right_arm_mesh)

func set_ui_mode(open: bool) -> void:
	ui_open = open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if ui_open else Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not ui_open and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * MOUSE_SENSITIVITY))
		head.rotate_x(deg_to_rad(-event.relative.y * MOUSE_SENSITIVITY))
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-82.0), deg_to_rad(82.0))

	if event is InputEventMouseButton and event.pressed and not ui_open:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_primary_interact()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if is_instance_valid(held_item):
				_throw_held_item(11.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			hold_distance = clampf(hold_distance - 0.20, 1.05, 3.2)
			hand_anchor.position.z = -(hold_distance + (2.55 if third_person else 0.0))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			hold_distance = clampf(hold_distance + 0.20, 1.05, 3.2)
			hand_anchor.position.z = -(hold_distance + (2.55 if third_person else 0.0))

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				if not ui_open:
					_handle_primary_interact()
			KEY_Q:
				if is_instance_valid(held_item):
					_drop_held_item()
			KEY_G:
				if is_instance_valid(held_item):
					_throw_held_item(12.5)
			KEY_R:
				if is_instance_valid(held_item):
					held_rot_y = fmod(held_rot_y + 45.0, 360.0)
					held_item.apply_torque_impulse(Vector3(0.0, 2.4 * held_item.mass, 0.0))
					GameState.rotate_last_part()
			KEY_X:
				if not ui_open:
					_try_detach_part_from_table()
			KEY_F:
				flashlight.visible = not flashlight.visible
			KEY_V:
				third_person = not third_person
				_apply_camera_perspective()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if not ui_open:
		if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
			velocity.y = JUMP_VELOCITY

		var input_dir := Vector2.ZERO
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			input_dir.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			input_dir.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			input_dir.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			input_dir.y += 1.0
		input_dir = input_dir.normalized()

		var spd: float = SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
		var move_dir: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
		if move_dir.length_squared() > 0.001:
			velocity.x = move_dir.x * spd
			velocity.z = move_dir.z * spd
			bob_time += delta * (11.0 if spd > WALK_SPEED else 7.5)
		else:
			velocity.x = move_toward(velocity.x, 0.0, spd * 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, spd * 8.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)

	move_and_slide()

	# Efecto sutil de paso (headbob) y balanceo del traje Mark III al caminar
	var base_cam_y: float = 0.45 if third_person else 0.0
	var horiz_vel: float = Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horiz_vel > 0.5:
		camera.position.y = base_cam_y + sin(bob_time) * 0.035
		if is_instance_valid(suit_pivot):
			suit_pivot.position.y = abs(sin(bob_time)) * 0.045
			suit_pivot.rotation_degrees.z = sin(bob_time) * 2.2
	else:
		camera.position.y = lerpf(camera.position.y, base_cam_y, delta * 8.0)
		if is_instance_valid(suit_pivot):
			suit_pivot.position.y = lerpf(suit_pivot.position.y, 0.0, delta * 8.0)
			suit_pivot.rotation_degrees.z = lerpf(suit_pivot.rotation_degrees.z, 0.0, delta * 8.0)

	# Física tipo Ragdoll (Spring-Damper en el punto exacto de agarre con colisiones reales)
	if is_instance_valid(held_item):
		var grab_world_pos: Vector3 = held_item.to_global(grab_local_offset)
		var target_pos: Vector3 = hand_anchor.global_position
		var diff: Vector3 = target_pos - grab_world_pos
		if diff.length() > 4.8:
			_drop_held_item()
		else:
			var offset_from_center: Vector3 = grab_world_pos - held_item.global_position
			var point_vel: Vector3 = held_item.linear_velocity + held_item.angular_velocity.cross(offset_from_center)
			var stiffness: float = 140.0 * held_item.mass
			var damping: float = 16.5 * held_item.mass
			var pull_force: Vector3 = diff * stiffness - point_vel * damping
			held_item.apply_force(pull_force, offset_from_center)

			# Brazos siguen dinámicamente el balanceo del objeto
			var local_grab: Vector3 = camera.to_local(grab_world_pos)
			var sway_x: float = clampf(local_grab.x * 0.25, -0.18, 0.18)
			var sway_y: float = clampf(local_grab.y * 0.25, -0.18, 0.18)
			left_arm_mesh.position = left_arm_mesh.position.lerp(Vector3(-0.24 + sway_x, -0.22 + sway_y, -0.62), delta * 12.0)
			right_arm_mesh.position = right_arm_mesh.position.lerp(Vector3(0.24 + sway_x, -0.22 + sway_y, -0.62), delta * 12.0)
	else:
		left_arm_mesh.position = left_arm_mesh.position.lerp(Vector3(-0.32, -0.32, -0.45), delta * 10.0)
		right_arm_mesh.position = right_arm_mesh.position.lerp(Vector3(0.32, -0.32, -0.45), delta * 10.0)

	_update_interaction_ray()

func _update_interaction_ray() -> void:
	var prompt: String = ""
	var held_txt: String = ""
	if is_instance_valid(held_item):
		held_txt = "EN MANOS: %s  |  [Q] Soltar  [Clic Der / G] Lanzar  [R] Rotar" % held_item.display_name

	if raycast.is_colliding():
		var col := raycast.get_collider()
		if col is PickupItem3D and not is_instance_valid(held_item):
			prompt = (col as PickupItem3D).get_prompt_text()
		elif col is Node and col.has_meta("interact_type"):
			var itype: String = String(col.get_meta("interact_type"))
			match itype:
				"holo_table":
					if is_instance_valid(held_item) and held_item.item_type == PickupItem3D.ItemType.SPACECRAFT_PART:
						prompt = "[E / Clic Izq] ACOPLAR '%s' EN LA NAVE 3D" % held_item.display_name
					else:
						prompt = "[E] Consola de Ingeniero  |  [X] Desacoplar pieza de la nave a tus manos"
				"station_terminal":
					var r_id: int = int(col.get_meta("role_id", 0))
					prompt = "[E / Clic Izq] Usar Terminal CRT: %s" % CatalogData.ROLE_NAMES.get(r_id, "TERMINAL")
				"part_dispenser":
					var p_id: String = String(col.get_meta("part_id", "solar_std"))
					var p_data: Dictionary = CatalogData.get_part_by_id(p_id)
					prompt = "[E / Clic Izq] Fabricar Caja Física: %s ($%.0fM | %.0f kg)" % [
						p_data.get("name", p_id), p_data.get("cost", 0.0), p_data.get("mass", 0.0)
					]
				"launch_lever":
					prompt = "[E / Clic Izq] ¡ACCIONAR PALANCA FÍSICA DE DESPEGUE!"
				"power_socket":
					if is_instance_valid(held_item) and held_item.item_type in [PickupItem3D.ItemType.BATTERY_CELL, PickupItem3D.ItemType.RCS_TANK]:
						prompt = "[E / Clic Izq] CONECTAR '%s' AL CONDUCTO DE TELEMETRÍA" % held_item.display_name
					else:
						prompt = "Conducto Auxiliar Orbital (Trae una Celda de Batería o Tanque RCS en tus manos)"
				"dish_calibrator":
					prompt = "[E / Clic Izq] Calibrar Antena Parabólica Exterior al 100% de Ganancia"

	if prompt != current_prompt or is_instance_valid(held_item):
		current_prompt = prompt
		hover_prompt_changed.emit(prompt, held_txt)

func _handle_primary_interact() -> void:
	if not raycast.is_colliding():
		if is_instance_valid(held_item):
			_drop_held_item()
		return

	var col := raycast.get_collider()

	# 1. Si miramos un objeto físico recogible y tenemos las manos libres
	if col is PickupItem3D and not is_instance_valid(held_item):
		_grab_item(col as PickupItem3D, raycast.get_collision_point())
		return

	# 2. Si miramos un objeto interactivo del mundo
	if col is Node and col.has_meta("interact_type"):
		var itype: String = String(col.get_meta("interact_type"))
		match itype:
			"holo_table":
				if is_instance_valid(held_item) and held_item.item_type == PickupItem3D.ItemType.SPACECRAFT_PART:
					if GameState.add_part_to_assembly(held_item.part_id, held_rot_y):
						held_item.queue_free()
						held_item = null
						hover_prompt_changed.emit("", "")
				else:
					GameState.set_role(CatalogData.Role.ENGINEER)
					terminal_toggle_requested.emit(CatalogData.Role.ENGINEER)
				return
			"station_terminal":
				var r_id: int = int(col.get_meta("role_id", 0))
				GameState.set_role(r_id)
				terminal_toggle_requested.emit(r_id)
				return
			"part_dispenser":
				var p_id: String = String(col.get_meta("part_id", "solar_std"))
				var spawn_pos: Vector3 = (col as Node3D).global_position + Vector3(0.0, 1.35, 0.85)
				spawn_part_requested.emit(p_id, spawn_pos)
				return
			"launch_lever":
				GameState.add_log("[CAMPO] ¡Palanca física de ignición accionada manualmente!")
				GameState.set_phase(CatalogData.Phase.LAUNCH_SIM)
				return
			"power_socket":
				if is_instance_valid(held_item):
					if held_item.item_type == PickupItem3D.ItemType.BATTERY_CELL:
						GameState.battery_wh = min(GameState.max_battery_wh, GameState.battery_wh + 380.0)
						GameState.add_log("[INGENIERÍA DE CAMPO] ¡Celda física conectada! +380 Wh inyectados.")
						GameState.telemetry_updated.emit()
						held_item.queue_free()
						held_item = null
					elif held_item.item_type == PickupItem3D.ItemType.RCS_TANK:
						GameState.rcs_fuel_left += 45.0
						GameState.add_log("[INGENIERÍA DE CAMPO] ¡Tanque físico de hidracina acoplado! +45 kg RCS.")
						GameState.telemetry_updated.emit()
						held_item.queue_free()
						held_item = null
				return
			"dish_calibrator":
				GameState.set_antenna_frequency(GameState.optimal_freq_mhz)
				GameState.add_log("[ANTENA EXTERIOR] Plato parabólico sintonizado manualmente a %.0f MHz (100%%)." % GameState.optimal_freq_mhz)
				return

	# Si tenemos algo en la mano y hacemos clic en otra parte, lo soltamos
	if is_instance_valid(held_item):
		_drop_held_item()

func _grab_item(item: PickupItem3D, hit_point: Vector3 = Vector3.INF) -> void:
	held_item = item
	held_item.is_held = true
	held_item.freeze = false
	held_item.can_sleep = false
	held_item.sleeping = false
	held_item.collision_layer = 4
	held_item.collision_mask = 1 | 4
	held_item.linear_damp = 4.2
	held_item.angular_damp = 2.0

	if hit_point != Vector3.INF:
		grab_local_offset = held_item.to_local(hit_point)
	else:
		grab_local_offset = Vector3.ZERO

	if held_item.item_type == PickupItem3D.ItemType.VHS_BRIEFING:
		GameState.add_log("[JUGADOR] Cinta VHS de Briefing agarrada: " + held_item.display_name)
	else:
		GameState.add_log("[JUGADOR] Agarrado: %s (Llévalo a la Mesa Holográfica 3D y pulsa E para acoplar)" % held_item.display_name)
	_update_interaction_ray()

func _drop_held_item() -> void:
	if not is_instance_valid(held_item):
		return
	held_item.is_held = false
	held_item.freeze = false
	held_item.can_sleep = true
	held_item.collision_layer = 4
	held_item.collision_mask = 1 | 4
	held_item.linear_damp = 0.2
	held_item.angular_damp = 0.2
	held_item = null
	_update_interaction_ray()

func _throw_held_item(force: float) -> void:
	if not is_instance_valid(held_item):
		return
	var item := held_item
	_drop_held_item()
	var dir: Vector3 = -camera.global_transform.basis.z.normalized()
	item.apply_central_impulse(dir * force * item.mass + Vector3(0.0, 2.2, 0.0))

func _try_detach_part_from_table() -> void:
	if is_instance_valid(held_item) or GameState.placed_parts.is_empty():
		return
	var last_idx: int = GameState.placed_parts.size() - 1
	var p_id: String = GameState.placed_parts[last_idx]["part_id"]
	GameState.remove_part_at(last_idx)
	spawn_part_requested.emit(p_id, hand_anchor.global_position)
