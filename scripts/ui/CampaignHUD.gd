class_name CampaignHUD
extends CanvasLayer

## HUD de Campaña Artemis (Un solo rol):
## - Panel de Reto Activo + Pasos (✔ / ☐) + Brújula/Distancia hacia la baliza
## - Pestaña superior de Logros estilo Minecraft ([L]) con árbol por capítulos
## - Toast emergente estilo Minecraft ("¡Logro conseguido!") en la esquina superior derecha
## - Ventana de Explicación Científica ([H]) y lectura de correos/carteles

var room: ControlRoom3D

# Tracker de reto (arriba izquierda, debajo de la barra superior)
var tracker_panel: PanelContainer
var lbl_chapter: Label
var lbl_obj_title: Label
var lbl_steps: RichTextLabel
var lbl_compass: Label

# Barra rápida de Logros y Partidas (arriba derecha)
var btn_achievements: Button
var btn_saves: Button

# Modal Mini-Menú de Partidas [M]
var saves_modal: PanelContainer
var saves_list_box: VBoxContainer
var new_save_input: LineEdit
var lbl_active_save: Label

# Toast estilo Minecraft (arriba derecha)
var toast_panel: PanelContainer
var lbl_toast_header: Label
var lbl_toast_title: Label
var lbl_toast_desc: Label
var toast_queue: Array[Dictionary] = []
var toast_timer: float = 0.0

# Modal de Árbol de Logros [L]
var tree_backdrop: ColorRect
var tree_modal: PanelContainer
var tree_tabs: TabBar
var tree_list_box: VBoxContainer
var lbl_tree_summary: Label

# Modal de Explicación / Info [H]
var info_modal: PanelContainer
var lbl_info_title: Label
var lbl_info_body: RichTextLabel

# Overlay de Transición de Zona estilo Adopt Me
var fade_overlay: ColorRect
var lbl_fade_banner: Label

func setup(control_room: ControlRoom3D) -> void:
	room = control_room

func _ready() -> void:
	layer = 15
	_build_ui()
	Campaign.objective_changed.connect(_on_objective_changed)
	Campaign.step_completed.connect(_on_step_completed)
	Campaign.achievement_unlocked.connect(_on_achievement_unlocked)
	Campaign.info_requested.connect(_on_info_requested)
	Campaign.slot_loaded.connect(_on_slot_loaded)
	Campaign.zone_transition_requested.connect(_on_zone_transition_requested)
	_refresh_tracker()
	_refresh_achievement_count()
	if not OS.get_cmdline_user_args().has("--run-self-test"):
		_open_saves_modal()

func _style(bg: Color, border: Color, border_w: int = 2, radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(10)
	return sb

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 1. PANEL DE RETO ACTIVO Y SEÑALIZACIÓN (Arriba izquierda)
	tracker_panel = PanelContainer.new()
	tracker_panel.anchor_left = 0.01
	tracker_panel.anchor_right = 0.31
	tracker_panel.anchor_top = 0.02
	tracker_panel.anchor_bottom = 0.23
	tracker_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker_panel.add_theme_stylebox_override("panel", _style(Color(0.03, 0.06, 0.11, 0.84), Color(1.0, 0.82, 0.25)))
	root.add_child(tracker_panel)

	var tvbox := VBoxContainer.new()
	tvbox.add_theme_constant_override("separation", 4)
	tvbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker_panel.add_child(tvbox)

	lbl_chapter = Label.new()
	lbl_chapter.add_theme_font_size_override("font_size", 12)
	lbl_chapter.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	tvbox.add_child(lbl_chapter)

	lbl_obj_title = Label.new()
	lbl_obj_title.add_theme_font_size_override("font_size", 16)
	lbl_obj_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	lbl_obj_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tvbox.add_child(lbl_obj_title)

	lbl_steps = RichTextLabel.new()
	lbl_steps.bbcode_enabled = true
	lbl_steps.fit_content = true
	lbl_steps.scroll_active = false
	lbl_steps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_steps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tvbox.add_child(lbl_steps)

	lbl_compass = Label.new()
	lbl_compass.add_theme_font_size_override("font_size", 14)
	lbl_compass.add_theme_color_override("font_color", Color(0.45, 1.0, 0.65))
	tvbox.add_child(lbl_compass)

	# 2. BOTONES DE LOGROS Y PARTIDAS (Arriba derecha)
	var pill_box := HBoxContainer.new()
	pill_box.anchor_left = 0.72
	pill_box.anchor_right = 0.99
	pill_box.anchor_top = 0.02
	pill_box.anchor_bottom = 0.075
	pill_box.add_theme_constant_override("separation", 8)
	root.add_child(pill_box)

	btn_achievements = Button.new()
	btn_achievements.text = "[L] Logros (0/0)"
	btn_achievements.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_achievements.modulate = Color(1.0, 0.88, 0.38)
	btn_achievements.pressed.connect(_toggle_tree_modal)
	pill_box.add_child(btn_achievements)

	btn_saves = Button.new()
	btn_saves.text = "[M] Partidas"
	btn_saves.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_saves.modulate = Color(0.55, 1.0, 0.72)
	btn_saves.pressed.connect(_toggle_saves_modal)
	pill_box.add_child(btn_saves)

	# 3. TOAST ESTILO MINECRAFT (Arriba derecha, debajo de botones)
	toast_panel = PanelContainer.new()
	toast_panel.anchor_left = 0.68
	toast_panel.anchor_right = 0.99
	toast_panel.anchor_top = 0.09
	toast_panel.anchor_bottom = 0.20
	toast_panel.visible = false
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.08, 0.10, 0.95), Color(1.0, 0.82, 0.20), 3, 6))
	root.add_child(toast_panel)

	var toast_v := VBoxContainer.new()
	toast_v.add_theme_constant_override("separation", 2)
	toast_panel.add_child(toast_v)

	lbl_toast_header = Label.new()
	lbl_toast_header.text = "★ ¡LOGRO CONSEGUIDO!"
	lbl_toast_header.add_theme_font_size_override("font_size", 12)
	lbl_toast_header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.22))
	toast_v.add_child(lbl_toast_header)

	lbl_toast_title = Label.new()
	lbl_toast_title.add_theme_font_size_override("font_size", 16)
	lbl_toast_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	toast_v.add_child(lbl_toast_title)

	lbl_toast_desc = Label.new()
	lbl_toast_desc.add_theme_font_size_override("font_size", 12)
	lbl_toast_desc.add_theme_color_override("font_color", Color(0.75, 0.82, 0.90))
	lbl_toast_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_v.add_child(lbl_toast_desc)

	# 4. VENTANA EMERGENTE ÁRBOL DE LOGROS ESTILO MINECRAFT [L]
	tree_backdrop = ColorRect.new()
	tree_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	tree_backdrop.color = Color(0.0, 0.0, 0.0, 0.62)
	tree_backdrop.visible = false
	tree_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	tree_backdrop.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_modals()
	)
	root.add_child(tree_backdrop)

	tree_modal = PanelContainer.new()
	tree_modal.anchor_left = 0.14
	tree_modal.anchor_right = 0.86
	tree_modal.anchor_top = 0.12
	tree_modal.anchor_bottom = 0.88
	tree_modal.visible = false
	tree_modal.add_theme_stylebox_override("panel", _style(Color(0.05, 0.07, 0.11, 0.96), Color(1.0, 0.82, 0.25), 3, 8))
	root.add_child(tree_modal)

	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 8)
	tree_modal.add_child(mv)

	var top_r := HBoxContainer.new()
	mv.add_child(top_r)

	lbl_tree_summary = Label.new()
	lbl_tree_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_tree_summary.add_theme_font_size_override("font_size", 18)
	lbl_tree_summary.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	top_r.add_child(lbl_tree_summary)

	var btn_close_tree := Button.new()
	btn_close_tree.text = "Cerrar [L / ESC]"
	btn_close_tree.pressed.connect(_close_modals)
	top_r.add_child(btn_close_tree)

	tree_tabs = TabBar.new()
	for tab_name in MissionScript.TABS:
		tree_tabs.add_tab(tab_name)
	tree_tabs.tab_changed.connect(_on_tree_tab_changed)
	mv.add_child(tree_tabs)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mv.add_child(scroll)

	tree_list_box = VBoxContainer.new()
	tree_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(tree_list_box)

	# 5. MODAL DE EXPLICACIÓN CIENTÍFICA / INFO [H]
	info_modal = PanelContainer.new()
	info_modal.anchor_left = 0.18
	info_modal.anchor_right = 0.82
	info_modal.anchor_top = 0.20
	info_modal.anchor_bottom = 0.80
	info_modal.visible = false
	info_modal.add_theme_stylebox_override("panel", _style(Color(0.04, 0.08, 0.13, 0.96), Color(0.35, 0.90, 1.0), 3, 8))
	root.add_child(info_modal)

	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 10)
	info_modal.add_child(iv)

	var itop := HBoxContainer.new()
	iv.add_child(itop)

	lbl_info_title = Label.new()
	lbl_info_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_info_title.add_theme_font_size_override("font_size", 18)
	lbl_info_title.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0))
	itop.add_child(lbl_info_title)

	var btn_close_info := Button.new()
	btn_close_info.text = "Entendido [ESC]"
	btn_close_info.pressed.connect(_close_modals)
	itop.add_child(btn_close_info)

	lbl_info_body = RichTextLabel.new()
	lbl_info_body.bbcode_enabled = true
	lbl_info_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl_info_body.add_theme_font_size_override("normal_font_size", 15)
	iv.add_child(lbl_info_body)

	# 6. MINI-MENÚ DE PARTIDAS [M]
	saves_modal = PanelContainer.new()
	saves_modal.anchor_left = 0.22
	saves_modal.anchor_right = 0.78
	saves_modal.anchor_top = 0.16
	saves_modal.anchor_bottom = 0.84
	saves_modal.visible = false
	saves_modal.add_theme_stylebox_override("panel", _style(Color(0.04, 0.07, 0.12, 0.97), Color(0.45, 1.0, 0.68), 3, 8))
	root.add_child(saves_modal)

	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 10)
	saves_modal.add_child(sv)

	var stop_r := HBoxContainer.new()
	sv.add_child(stop_r)

	lbl_active_save = Label.new()
	lbl_active_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_active_save.add_theme_font_size_override("font_size", 18)
	lbl_active_save.add_theme_color_override("font_color", Color(0.55, 1.0, 0.72))
	stop_r.add_child(lbl_active_save)

	var btn_save_now := Button.new()
	btn_save_now.text = "Guardar aquí"
	btn_save_now.modulate = Color(0.45, 1.0, 0.65)
	btn_save_now.pressed.connect(func() -> void:
		var ppos: Variant = room.player.global_position if (is_instance_valid(room) and is_instance_valid(room.player)) else null
		Campaign.save_current_slot(ppos)
		_rebuild_saves_list()
	)
	stop_r.add_child(btn_save_now)

	var btn_close_saves := Button.new()
	btn_close_saves.text = "Jugar / Cerrar [M]"
	btn_close_saves.pressed.connect(_close_modals)
	stop_r.add_child(btn_close_saves)

	var new_row := HBoxContainer.new()
	new_row.add_theme_constant_override("separation", 8)
	sv.add_child(new_row)

	new_save_input = LineEdit.new()
	new_save_input.placeholder_text = "Nombre de nueva partida (ej. Misión Juan)..."
	new_save_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_row.add_child(new_save_input)

	var btn_create_save := Button.new()
	btn_create_save.text = "+ Crear nueva partida"
	btn_create_save.modulate = Color(1.0, 0.88, 0.35)
	btn_create_save.pressed.connect(func() -> void:
		Campaign.create_new_slot(new_save_input.text)
		new_save_input.text = ""
		_rebuild_saves_list()
		_close_modals()
	)
	new_row.add_child(btn_create_save)

	var s_scroll := ScrollContainer.new()
	s_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sv.add_child(s_scroll)

	saves_list_box = VBoxContainer.new()
	saves_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	saves_list_box.add_theme_constant_override("separation", 8)
	s_scroll.add_child(saves_list_box)

	# 7. OVERLAY DE TRANSICIÓN DE ZONAS ESTILO ADOPT ME (Fade Out / Fade In)
	fade_overlay = ColorRect.new()
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.color = Color(0.02, 0.03, 0.06, 1.0)
	fade_overlay.modulate.a = 0.0
	fade_overlay.visible = false
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_overlay)

	lbl_fade_banner = Label.new()
	lbl_fade_banner.set_anchors_preset(Control.PRESET_CENTER)
	lbl_fade_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_fade_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_fade_banner.add_theme_font_size_override("font_size", 28)
	lbl_fade_banner.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	fade_overlay.add_child(lbl_fade_banner)

func _on_zone_transition_requested(target_zone: int, spawn_tag: String, banner_text: String) -> void:
	fade_overlay.visible = true
	fade_overlay.modulate.a = 0.0
	lbl_fade_banner.text = "✦  %s  ✦" % banner_text
	var tw := create_tween()
	tw.tween_property(fade_overlay, "modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		Campaign.commit_zone_change(target_zone, spawn_tag)
	)
	tw.tween_interval(0.22)
	tw.tween_property(fade_overlay, "modulate:a", 0.0, 0.42).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		fade_overlay.visible = false
	)

# ------------------------------------------------------------------ INPUT
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if new_save_input != null and new_save_input.has_focus():
			if event.keycode == KEY_ESCAPE:
				_close_modals()
			return
		match event.keycode:
			KEY_L:
				_toggle_tree_modal()
			KEY_M:
				_toggle_saves_modal()
			KEY_ESCAPE:
				if tree_modal.visible or info_modal.visible or saves_modal.visible:
					_close_modals()

func _sync_player_cursor() -> void:
	if is_instance_valid(room) and is_instance_valid(room.player):
		var any_open: bool = tree_modal.visible or info_modal.visible or saves_modal.visible
		room.player.set_ui_mode(any_open)

func _close_modals() -> void:
	tree_backdrop.visible = false
	tree_modal.visible = false
	info_modal.visible = false
	saves_modal.visible = false
	_sync_player_cursor()

func _open_saves_modal() -> void:
	tree_backdrop.visible = false
	tree_modal.visible = false
	info_modal.visible = false
	saves_modal.visible = true
	_rebuild_saves_list()
	_sync_player_cursor()

func _toggle_saves_modal() -> void:
	if saves_modal.visible:
		_close_modals()
	else:
		_open_saves_modal()

func _on_slot_loaded() -> void:
	_refresh_tracker()
	_refresh_achievement_count()
	if saves_modal.visible:
		_rebuild_saves_list()

func _rebuild_saves_list() -> void:
	for c in saves_list_box.get_children():
		c.queue_free()
	lbl_active_save.text = "PARTIDAS GUARDADAS · Activa: %s" % Campaign.active_slot_name
	for slot in Campaign.get_save_slots():
		var is_act: bool = bool(slot["is_active"])
		var card := PanelContainer.new()
		var b_col: Color = Color(0.45, 1.0, 0.65) if is_act else Color(0.32, 0.42, 0.55)
		var bg_col: Color = Color(0.08, 0.15, 0.12, 0.95) if is_act else Color(0.06, 0.08, 0.12, 0.90)
		card.add_theme_stylebox_override("panel", _style(bg_col, b_col, 2, 6))
		saves_list_box.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)

		var info_v := VBoxContainer.new()
		info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_v)

		var t_lbl := Label.new()
		t_lbl.text = "%s%s" % [String(slot["name"]), "  [ACTIVA]" if is_act else ""]
		t_lbl.add_theme_font_size_override("font_size", 16)
		t_lbl.add_theme_color_override("font_color", Color(1, 1, 1) if is_act else Color(0.85, 0.9, 0.95))
		info_v.add_child(t_lbl)

		var d_lbl := Label.new()
		d_lbl.text = "%s — %s  |  Logros: %d/%d  |  %s" % [
			String(slot["chapter_name"]),
			String(slot["objective_title"]),
			int(slot["unlocked_count"]),
			Campaign.achievements.size(),
			String(slot["updated_at"]),
		]
		d_lbl.add_theme_font_size_override("font_size", 12)
		d_lbl.add_theme_color_override("font_color", Color(0.7, 0.82, 0.92))
		info_v.add_child(d_lbl)

		var s_id: String = String(slot["id"])
		var btn_load := Button.new()
		btn_load.text = "Continuar" if is_act else "Cargar"
		btn_load.modulate = Color(0.55, 0.95, 1.0)
		btn_load.pressed.connect(func() -> void:
			if not is_act:
				Campaign.load_slot(s_id)
			_close_modals()
		)
		row.add_child(btn_load)

		var btn_del := Button.new()
		btn_del.text = "Borrar"
		btn_del.modulate = Color(1.0, 0.45, 0.45)
		btn_del.pressed.connect(func() -> void:
			Campaign.delete_slot(s_id)
			_rebuild_saves_list()
		)
		row.add_child(btn_del)

func _toggle_tree_modal() -> void:
	var will_open: bool = not tree_modal.visible
	info_modal.visible = false
	saves_modal.visible = false
	tree_backdrop.visible = will_open
	tree_modal.visible = will_open
	if will_open:
		var obj: Dictionary = Campaign.get_current_objective()
		if not obj.is_empty():
			tree_tabs.current_tab = clampi(int(obj.get("chapter", 0)), 0, MissionScript.TABS.size() - 1)
		_rebuild_tree_tab(tree_tabs.current_tab)
	_sync_player_cursor()

func _show_info_popup(title: String, body: String, modal: bool) -> void:
	lbl_info_title.text = title
	lbl_info_body.text = body
	if modal:
		tree_backdrop.visible = false
		tree_modal.visible = false
		saves_modal.visible = false
		info_modal.visible = true
		_sync_player_cursor()
	else:
		# Aviso breve no bloqueante en el tracker o toast
		toast_queue.append({
			"type": "info",
			"title": title,
			"desc": body,
		})

func _on_info_requested(title: String, body: String, modal: bool) -> void:
	_show_info_popup(title, body, modal)

# ------------------------------------------------------------------ TRACKER & TOASTS
func _on_objective_changed(_obj: Dictionary) -> void:
	_refresh_tracker()

func _on_step_completed(_obj: Dictionary, _idx: int) -> void:
	_refresh_tracker()

func _refresh_tracker() -> void:
	var obj: Dictionary = Campaign.get_current_objective()
	if obj.is_empty():
		lbl_chapter.text = "CAMPAÑA ARTEMIS"
		lbl_obj_title.text = "¡Todos los retos disponibles completados!"
		lbl_steps.text = ""
		return
	var ch: int = int(obj.get("chapter", 0))
	lbl_chapter.text = MissionScript.CHAPTER_NAMES[clampi(ch, 0, MissionScript.CHAPTER_NAMES.size() - 1)]
	lbl_obj_title.text = String(obj.get("title", ""))
	var lines: PackedStringArray = []
	var steps: Array = obj.get("steps", [])
	for i in range(steps.size()):
		var done: bool = i < Campaign.step_done.size() and Campaign.step_done[i]
		var mark: String = "[color=#55ff88]✔[/color]" if done else "[color=#ffd966]☐[/color]"
		lines.append("%s %s" % [mark, String(steps[i].get("label", ""))])
	lbl_steps.text = "\n".join(lines)

func _on_achievement_unlocked(ach: Dictionary) -> void:
	_refresh_achievement_count()
	toast_queue.append(ach)
	if tree_modal.visible:
		_rebuild_tree_tab(tree_tabs.current_tab)

func _refresh_achievement_count() -> void:
	var total: int = Campaign.achievements.size()
	var got: int = Campaign.completed_count()
	if is_instance_valid(btn_achievements):
		btn_achievements.text = "[L] Logros (%d/%d)" % [got, total]
	if is_instance_valid(lbl_tree_summary):
		lbl_tree_summary.text = "ÁRBOL DE LOGROS — PROGRAMA ARTEMIS (%d / %d completados)" % [got, total]

func _on_tree_tab_changed(tab_idx: int) -> void:
	_rebuild_tree_tab(tab_idx)

func _rebuild_tree_tab(tab_idx: int) -> void:
	for c in tree_list_box.get_children():
		c.queue_free()
	_refresh_achievement_count()
	for a in Campaign.achievements:
		if int(a.get("tab", 0)) != tab_idx:
			continue
		var unlocked: bool = Campaign.is_unlocked(String(a["id"]))
		var a_type: String = String(a.get("type", "task"))
		var border_col: Color = Color(0.35, 0.4, 0.48)
		var tag: String = "TAREA"
		if a_type == "goal":
			tag = "META DE CAPÍTULO"
			border_col = Color(1.0, 0.82, 0.22) if unlocked else Color(0.45, 0.38, 0.20)
		elif a_type == "challenge":
			tag = "DESAFÍO"
			border_col = Color(0.75, 0.45, 1.0) if unlocked else Color(0.38, 0.28, 0.48)
		elif unlocked:
			border_col = Color(0.35, 1.0, 0.55)

		var bg_col: Color = Color(0.08, 0.14, 0.11, 0.95) if unlocked else Color(0.06, 0.08, 0.11, 0.85)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(bg_col, border_col, 2, 6))
		tree_list_box.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		var indent: String = "  └─ " if String(a.get("parent", "")) != "" else "● "
		var icon := Label.new()
		icon.text = "%s[%s]" % [indent, "✔" if unlocked else "🔒"]
		icon.add_theme_font_size_override("font_size", 16)
		icon.add_theme_color_override("font_color", border_col)
		row.add_child(icon)

		var col_v := VBoxContainer.new()
		col_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col_v)

		var title_l := Label.new()
		title_l.text = "%s  (%s)" % [String(a["title"]), tag]
		title_l.add_theme_font_size_override("font_size", 15)
		title_l.add_theme_color_override("font_color", Color(1, 1, 1) if unlocked else Color(0.65, 0.70, 0.78))
		col_v.add_child(title_l)

		var desc_l := Label.new()
		desc_l.text = String(a["desc"])
		desc_l.add_theme_font_size_override("font_size", 13)
		desc_l.add_theme_color_override("font_color", Color(0.75, 0.85, 0.92) if unlocked else Color(0.48, 0.52, 0.58))
		col_v.add_child(desc_l)

# ------------------------------------------------------------------ PROCESS (Brújula + Toasts)
func _process(delta: float) -> void:
	_update_compass()
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			toast_panel.visible = false
	elif not toast_queue.is_empty():
		var item: Dictionary = toast_queue.pop_front()
		_show_toast(item)

func _show_toast(item: Dictionary) -> void:
	var t: String = String(item.get("type", "task"))
	var border_col: Color = Color(0.35, 1.0, 0.55)
	if t == "goal":
		border_col = Color(1.0, 0.82, 0.22)
		lbl_toast_header.text = "★ ¡META COMPLETADA!"
	elif t == "challenge":
		border_col = Color(0.75, 0.45, 1.0)
		lbl_toast_header.text = "◆ ¡DESAFÍO COMPLETADO!"
	elif t == "info":
		border_col = Color(0.35, 0.88, 1.0)
		lbl_toast_header.text = "ℹ INFORMACIÓN DE ZONA"
	else:
		lbl_toast_header.text = "★ ¡LOGRO CONSEGUIDO!"
	lbl_toast_header.add_theme_color_override("font_color", border_col)
	toast_panel.add_theme_stylebox_override("panel", _style(Color(0.06, 0.07, 0.10, 0.96), border_col, 3, 6))
	lbl_toast_title.text = String(item.get("title", ""))
	lbl_toast_desc.text = String(item.get("desc", ""))
	toast_panel.visible = true
	toast_timer = 4.2

func _update_compass() -> void:
	var target: Node3D = Campaign.get_current_target()
	if target == null or not is_instance_valid(room) or not is_instance_valid(room.player):
		lbl_compass.text = ""
		return
	var ppos: Vector3 = room.player.global_position
	var tpos: Vector3 = target.global_position
	var to_target := Vector2(tpos.x - ppos.x, tpos.z - ppos.z)
	var dist: float = to_target.length()
	var fwd := Vector2(-room.player.global_transform.basis.z.x, -room.player.global_transform.basis.z.z).normalized()
	var angle_diff: float = fwd.angle_to(to_target.normalized())
	var arrows: Array[String] = ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"]
	var idx: int = int(round(angle_diff / (TAU / 8.0))) % 8
	if idx < 0:
		idx += 8
	lbl_compass.text = "Destino: %s  %.0f m" % [arrows[idx], dist]
