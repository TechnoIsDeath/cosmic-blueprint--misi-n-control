extends Node

## Autoload "Campaign": gestiona la campaña de un solo rol (Ingeniero de Misión).
## - Avanza retos secuenciales definidos en MissionScript cuando el mundo dispara eventos.
## - Desbloquea logros estilo Minecraft.
## - Mantiene los marcadores 3D (para la baliza y la flecha del HUD).
## - Guarda y carga el progreso en user://artemis_save.json.

signal objective_changed(objective: Dictionary)
signal step_completed(objective: Dictionary, step_idx: int)
signal objective_completed(objective: Dictionary)
signal achievement_unlocked(achievement: Dictionary)
signal info_requested(title: String, body: String, modal: bool)
signal event_fired(ev: String)
signal slot_loaded()
signal zone_transition_requested(target_zone: int, spawn_tag: String, banner_text: String)
signal zone_changed(new_zone: int, spawn_tag: String)

enum Zone {
	HOME = 0,
	CITY = 1,
	LAUNCH_SITE = 2,
	NASA_INTERIOR = 3,
}

const ZONE_NAMES: Dictionary = {
	Zone.HOME: "Interior de tu Casa",
	Zone.CITY: "Ciudad · Ruta hacia la NASA",
	Zone.LAUNCH_SITE: "Complejo Espacial NASA · Sitio de Lanzamiento",
	Zone.NASA_INTERIOR: "Interior NASA · Control de Misión",
}

const LEGACY_SAVE_PATH: String = "user://artemis_save.json"
const SAVES_PATH: String = "user://artemis_saves.json"

var objectives: Array = []
var achievements: Array = []
var current_index: int = 0
var current_zone: int = Zone.HOME
var step_done: Array[bool] = []
var unlocked: Dictionary = {}            # achievement_id -> true
var visited_events: Dictionary = {}      # eventos persistentes ya disparados (p. ej. badge_taken)
var collected_items: Array[String] = []  # objetos físicos y credencial recogidos en esta partida
var markers: Dictionary = {}             # marker_id -> Node3D
var save_enabled: bool = true

var active_slot_id: String = "slot_1"
var active_slot_name: String = "Partida 1"
var saved_player_pos: Variant = null     # Vector3 o null
var all_slots: Dictionary = {}           # slot_id -> Dictionary

func _ready() -> void:
	objectives = MissionScript.get_objectives()
	achievements = MissionScript.get_achievements()
	if OS.get_cmdline_user_args().has("--run-self-test") or OS.get_cmdline_user_args().has("--new-game"):
		save_enabled = false
	else:
		load_progress()
	_reset_steps()

# ------------------------------------------------------------------ CONSULTAS
func get_current_objective() -> Dictionary:
	if current_index < 0 or current_index >= objectives.size():
		return {}
	return objectives[current_index]

func get_current_step_index() -> int:
	for i in range(step_done.size()):
		if not step_done[i]:
			return i
	return -1

func get_current_marker_id() -> String:
	var obj: Dictionary = get_current_objective()
	var idx: int = get_current_step_index()
	if obj.is_empty() or idx < 0:
		return ""
	return String(obj["steps"][idx].get("marker", ""))

func get_current_target() -> Node3D:
	var m_id: String = get_current_marker_id()
	if m_id == "" or not markers.has(m_id):
		return null
	var n: Node3D = markers[m_id]
	return n if is_instance_valid(n) else null

func get_achievement(a_id: String) -> Dictionary:
	for a in achievements:
		if a["id"] == a_id:
			return a
	return {}

func is_unlocked(a_id: String) -> bool:
	return unlocked.has(a_id)

func has_event(ev: String) -> bool:
	return visited_events.has(ev)

func completed_count() -> int:
	return unlocked.size()

# ------------------------------------------------------------------ MUNDO
func register_marker(m_id: String, node: Node3D) -> void:
	markers[m_id] = node

func request_zone_change(target_zone: int, spawn_tag: String = "default", ev_to_fire: String = "") -> void:
	if ev_to_fire != "":
		notify_event(ev_to_fire)
	var banner: String = String(ZONE_NAMES.get(target_zone, "Cargando zona..."))
	if OS.get_cmdline_user_args().has("--run-self-test"):
		commit_zone_change(target_zone, spawn_tag)
	else:
		zone_transition_requested.emit(target_zone, spawn_tag, banner)

func commit_zone_change(target_zone: int, spawn_tag: String = "default") -> void:
	current_zone = target_zone
	saved_player_pos = null
	_save()
	zone_changed.emit(current_zone, spawn_tag)

func show_info(info_id: String, modal: bool = true) -> void:
	var info: Dictionary = MissionScript.get_info(info_id)
	if not info.is_empty():
		info_requested.emit(info["title"], info["body"], modal)

func record_collected_item(item_id: String) -> void:
	if item_id == "" or collected_items.has(item_id):
		return
	collected_items.append(item_id)
	_save()

## Punto de entrada único: el mundo/jugador notifica que algo ocurrió.
func notify_event(ev: String) -> void:
	var first_time: bool = not visited_events.has(ev)
	visited_events[ev] = true
	if ev == "badge_taken":
		record_collected_item("badge_nasa")
	if first_time:
		event_fired.emit(ev)
		_save()
	var obj: Dictionary = get_current_objective()
	if obj.is_empty():
		return
	var steps: Array = obj["steps"]
	var changed: bool = false
	for i in range(steps.size()):
		if not step_done[i] and String(steps[i]["event"]) == ev:
			step_done[i] = true
			changed = true
			step_completed.emit(obj, i)
	if changed:
		if not step_done.has(false):
			_complete_current()
		else:
			objective_changed.emit(obj)
			_save()

func _complete_current() -> void:
	var obj: Dictionary = get_current_objective()
	objective_completed.emit(obj)
	var a_id: String = String(obj.get("achievement", ""))
	if a_id != "":
		unlock_achievement(a_id)
	current_index += 1
	_reset_steps()
	# Pasos ya cumplidos antes de llegar al reto (p. ej. visitar un cartel con antelación)
	var nxt: Dictionary = get_current_objective()
	if not nxt.is_empty():
		var steps: Array = nxt["steps"]
		for i in range(steps.size()):
			var ev_name: String = String(steps[i]["event"])
			if ev_name not in ["moved", "looked", "jumped", "woke_up"] and visited_events.has(ev_name):
				step_done[i] = true
		if not step_done.has(false):
			_complete_current()
			return
	objective_changed.emit(nxt)
	_save()

func unlock_achievement(a_id: String) -> void:
	if unlocked.has(a_id):
		return
	var a: Dictionary = get_achievement(a_id)
	if a.is_empty():
		return
	unlocked[a_id] = true
	achievement_unlocked.emit(a)
	_save()

func _reset_steps() -> void:
	step_done.clear()
	var obj: Dictionary = get_current_objective()
	if obj.is_empty():
		return
	for _s in obj["steps"]:
		step_done.append(false)

# ------------------------------------------------------------------ GUARDADO MULTI-PARTIDA
func _build_slot_payload() -> Dictionary:
	var pos_arr: Array = []
	if saved_player_pos is Vector3:
		var p: Vector3 = saved_player_pos
		pos_arr = [p.x, p.y, p.z]
	var parts_arr: Array = []
	for entry in GameState.placed_parts:
		var sp: Vector3 = entry.get("slot_pos", Vector3.ZERO)
		parts_arr.append({
			"part_id": String(entry.get("part_id", "")),
			"slot_pos": [sp.x, sp.y, sp.z],
			"rot_y": float(entry.get("rot_y", 0.0)),
		})
	return {
		"name": active_slot_name,
		"current_index": current_index,
		"current_zone": current_zone,
		"unlocked": unlocked.keys(),
		"events": visited_events.keys(),
		"collected_items": collected_items.duplicate(),
		"placed_parts": parts_arr,
		"selected_rocket_id": GameState.selected_rocket_id,
		"player_pos": pos_arr,
		"updated_at": Time.get_datetime_string_from_system(false, true),
	}

func _write_all_saves() -> void:
	if not save_enabled:
		return
	var root_data := {
		"active_slot": active_slot_id,
		"slots": all_slots,
	}
	var f := FileAccess.open(SAVES_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(root_data))

func _save() -> void:
	if not save_enabled:
		return
	all_slots[active_slot_id] = _build_slot_payload()
	_write_all_saves()

func save_current_slot(player_pos: Variant = null) -> void:
	if player_pos is Vector3:
		saved_player_pos = player_pos
	_save()

func load_progress() -> void:
	all_slots.clear()
	if FileAccess.file_exists(SAVES_PATH):
		var f := FileAccess.open(SAVES_PATH, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				var raw_slots: Variant = parsed.get("slots", {})
				if typeof(raw_slots) == TYPE_DICTIONARY:
					all_slots = raw_slots
				active_slot_id = String(parsed.get("active_slot", "slot_1"))
	elif FileAccess.file_exists(LEGACY_SAVE_PATH):
		var lf := FileAccess.open(LEGACY_SAVE_PATH, FileAccess.READ)
		if lf:
			var lparsed: Variant = JSON.parse_string(lf.get_as_text())
			if typeof(lparsed) == TYPE_DICTIONARY:
				all_slots["slot_1"] = {
					"name": "Partida 1",
					"current_index": int(lparsed.get("current_index", 0)),
					"unlocked": lparsed.get("unlocked", []),
					"events": lparsed.get("events", []),
					"player_pos": [],
					"updated_at": Time.get_datetime_string_from_system(false, true),
				}
				active_slot_id = "slot_1"
				_write_all_saves()

	if all_slots.is_empty():
		all_slots["slot_1"] = _build_slot_payload()
		active_slot_id = "slot_1"

	if not all_slots.has(active_slot_id):
		active_slot_id = String(all_slots.keys()[0])

	_apply_slot_data(active_slot_id, all_slots[active_slot_id])

func _apply_slot_data(slot_id: String, data: Dictionary) -> void:
	active_slot_id = slot_id
	active_slot_name = String(data.get("name", slot_id))
	current_index = clampi(int(data.get("current_index", 0)), 0, objectives.size() - 1)
	var default_z: int = Zone.LAUNCH_SITE if current_index >= 5 else (Zone.CITY if current_index >= 4 else Zone.HOME)
	current_zone = int(data.get("current_zone", default_z))
	unlocked.clear()
	for a_id in data.get("unlocked", []):
		unlocked[String(a_id)] = true
	visited_events.clear()
	for ev in data.get("events", []):
		visited_events[String(ev)] = true
	collected_items.clear()
	for it in data.get("collected_items", []):
		collected_items.append(String(it))
	GameState.placed_parts.clear()
	for entry in data.get("placed_parts", []):
		if typeof(entry) == TYPE_DICTIONARY:
			var sp_arr: Array = entry.get("slot_pos", [0.0, 0.0, 0.0])
			var sp_vec := Vector3(float(sp_arr[0]), float(sp_arr[1]), float(sp_arr[2])) if sp_arr.size() == 3 else Vector3.ZERO
			GameState.placed_parts.append({
				"part_id": String(entry.get("part_id", "")),
				"slot_pos": sp_vec,
				"rot_y": float(entry.get("rot_y", 0.0)),
			})
	if data.has("selected_rocket_id"):
		GameState.selected_rocket_id = String(data.get("selected_rocket_id", "vektor_light"))
	var p_arr: Variant = data.get("player_pos", [])
	if typeof(p_arr) == TYPE_ARRAY and p_arr.size() == 3:
		saved_player_pos = Vector3(float(p_arr[0]), float(p_arr[1]), float(p_arr[2]))
	else:
		saved_player_pos = null
	_reset_steps()
	GameState.design_updated.emit()

func get_save_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s_id in all_slots.keys():
		var d: Dictionary = all_slots[s_id]
		var idx: int = clampi(int(d.get("current_index", 0)), 0, objectives.size() - 1)
		var obj: Dictionary = objectives[idx] if idx < objectives.size() else {}
		var ch_idx: int = clampi(int(obj.get("chapter", 0)), 0, MissionScript.CHAPTER_NAMES.size() - 1)
		out.append({
			"id": String(s_id),
			"name": String(d.get("name", s_id)),
			"current_index": idx,
			"chapter_name": MissionScript.CHAPTER_NAMES[ch_idx],
			"objective_title": String(obj.get("title", "")),
			"unlocked_count": (d.get("unlocked", []) as Array).size(),
			"updated_at": String(d.get("updated_at", "")),
			"is_active": String(s_id) == active_slot_id,
		})
	return out

func create_new_slot(slot_name: String) -> String:
	var clean_name: String = slot_name.strip_edges()
	var n: int = all_slots.size() + 1
	var new_id: String = "slot_%d_%d" % [Time.get_unix_time_from_system(), n]
	if clean_name == "":
		clean_name = "Partida %d" % n
	active_slot_id = new_id
	active_slot_name = clean_name
	current_index = 0
	current_zone = Zone.HOME
	unlocked.clear()
	visited_events.clear()
	collected_items.clear()
	GameState.placed_parts.clear()
	GameState.design_updated.emit()
	saved_player_pos = null
	_reset_steps()
	all_slots[new_id] = _build_slot_payload()
	_write_all_saves()
	objective_changed.emit(get_current_objective())
	slot_loaded.emit()
	return new_id

func load_slot(slot_id: String) -> void:
	if not all_slots.has(slot_id):
		return
	_apply_slot_data(slot_id, all_slots[slot_id])
	_write_all_saves()
	objective_changed.emit(get_current_objective())
	slot_loaded.emit()

func delete_slot(slot_id: String) -> void:
	if not all_slots.has(slot_id):
		return
	all_slots.erase(slot_id)
	if all_slots.is_empty():
		create_new_slot("Partida 1")
		return
	if slot_id == active_slot_id:
		var next_id: String = String(all_slots.keys()[0])
		load_slot(next_id)
	else:
		_write_all_saves()

func reset_progress() -> void:
	current_index = 0
	current_zone = Zone.HOME
	unlocked.clear()
	visited_events.clear()
	collected_items.clear()
	GameState.placed_parts.clear()
	GameState.design_updated.emit()
	saved_player_pos = null
	_reset_steps()
	_save()
	objective_changed.emit(get_current_objective())
	slot_loaded.emit()
