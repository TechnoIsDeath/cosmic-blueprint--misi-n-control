class_name MissionControlHUD
extends CanvasLayer

## HUD en 1.ª Persona + Terminales CRT Contextuales + Impresora Matricial.
## Por defecto el jugador camina libremente en 1.ª persona (con mira central, avisos de agarre
## de objetos físicos y mini-telemetría) y abre/cierra las consolas CRT con E o TAB.

var control_room: ControlRoom3D
var crt_overlay: ColorRect
var crt_enabled: bool = true
var terminal_open: bool = false

# Elementos de 1.ª Persona (siempre visibles al explorar)
var crosshair_label: Label
var hover_prompt_label: Label
var held_item_banner: Label
var mini_hud_box: PanelContainer
var lbl_mini_telemetry: RichTextLabel
var terminal_modal_root: Control

# Cabecera superior
var lbl_header_mission: Label
var lbl_header_phase: Label
var lbl_header_budget: Label
var role_buttons: Array[Button] = []

var panel_briefing: Control
var panel_assembly: Control
var panel_launch: Control
var panel_orbit: Control
var panel_receipt: Control
var panel_lan_modal: PanelContainer

# Nodos de Fase 1 (Briefing RPG)
var lbl_rpg_speaker: Label
var lbl_rpg_role_hint: Label
var lbl_rpg_text: RichTextLabel
var lbl_mission_specs: RichTextLabel
var current_dialog_idx: int = 0

# Nodos de Fase 2 (Ensamblaje Asimétrico)
var lbl_role_banner: Label
var lbl_role_desc: Label
var role_content_box: VBoxContainer
var lbl_quick_telemetry: RichTextLabel
var lbl_comms_log: RichTextLabel

# Nodos de Fase 3 (Lanzamiento)
var lbl_launch_telemetry: RichTextLabel
var bar_launch_progress: ProgressBar

# Nodos de Fase 4 (Operación Orbital y Crisis)
var lbl_crisis_banner: Label
var lbl_orbit_telemetry: RichTextLabel
var orbit_instruments_box: VBoxContainer
var slider_live_freq: HSlider
var lbl_live_freq_val: Label

# Nodos de Recibo Matricial
var lbl_receipt_printer: RichTextLabel
var receipt_full_text: String = ""
var receipt_char_progress: float = 0.0

func setup_with_room(room: ControlRoom3D) -> void:
	control_room = room
	if is_instance_valid(control_room) and is_instance_valid(control_room.player):
		control_room.player.hover_prompt_changed.connect(_on_player_hover_changed)
		control_room.player.terminal_toggle_requested.connect(_on_terminal_requested)

func _ready() -> void:
	_build_ui()
	_build_crt_post_overlay()

	GameState.phase_changed.connect(_on_phase_changed)
	GameState.role_changed.connect(_on_role_changed)
	GameState.design_updated.connect(_refresh_all_panels)
	GameState.telemetry_updated.connect(_refresh_telemetry_views)
	GameState.log_message_added.connect(_on_log_added)
	GameState.conflict_updated.connect(_refresh_all_panels)

	# Arrancar directamente en Fase 2 (Ensamblaje Abierto) y modo 1.ª persona activo
	GameState.set_phase(CatalogData.Phase.ASSEMBLY)
	set_terminal_open(false)
	_on_role_changed(GameState.current_role)
	_refresh_all_panels()

func set_terminal_open(open: bool) -> void:
	terminal_open = open
	if is_instance_valid(terminal_modal_root):
		terminal_modal_root.visible = terminal_open
	if is_instance_valid(crosshair_label):
		crosshair_label.visible = not terminal_open
	if is_instance_valid(control_room) and is_instance_valid(control_room.player):
		control_room.player.set_ui_mode(terminal_open)

func _on_terminal_requested(role_id: int) -> void:
	GameState.set_role(role_id)
	if GameState.current_phase == CatalogData.Phase.BRIEFING:
		set_terminal_open(true)
	else:
		set_terminal_open(true)

func _on_player_hover_changed(prompt: String, held_info: String) -> void:
	if is_instance_valid(hover_prompt_label):
		hover_prompt_label.text = prompt
	if is_instance_valid(held_item_banner):
		held_item_banner.text = held_info
	if is_instance_valid(crosshair_label):
		crosshair_label.text = "[ + ]" if not prompt.is_empty() else "  +  "
		crosshair_label.add_theme_color_override(
			"font_color",
			Color(0.3, 1.0, 0.55) if not prompt.is_empty() else Color(0.85, 0.95, 1.0, 0.85)
		)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB, KEY_ESCAPE:
				set_terminal_open(not terminal_open)
			KEY_1:
				GameState.set_role(CatalogData.Role.DIRECTOR)
				if is_instance_valid(control_room):
					control_room.teleport_player_to_role_station(CatalogData.Role.DIRECTOR)
			KEY_2:
				GameState.set_role(CatalogData.Role.ENGINEER)
				if is_instance_valid(control_room):
					control_room.teleport_player_to_role_station(CatalogData.Role.ENGINEER)
			KEY_3:
				GameState.set_role(CatalogData.Role.SCIENTIST)
				if is_instance_valid(control_room):
					control_room.teleport_player_to_role_station(CatalogData.Role.SCIENTIST)
			KEY_4:
				GameState.set_role(CatalogData.Role.FLIGHT_SPEC)
				if is_instance_valid(control_room):
					control_room.teleport_player_to_role_station(CatalogData.Role.FLIGHT_SPEC)
			KEY_F2:
				_toggle_crt_shader()

func _toggle_crt_shader() -> void:
	crt_enabled = not crt_enabled
	if is_instance_valid(crt_overlay):
		crt_overlay.visible = crt_enabled

func _make_panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(10)
	return sb

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ==========================================================
	# 1. CAPA DE EXPLORACIÓN EN 1.ª PERSONA (MIRA Y MINI-HUD)
	# ==========================================================
	crosshair_label = Label.new()
	crosshair_label.text = "  +  "
	crosshair_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair_label.set_anchors_preset(Control.PRESET_CENTER)
	crosshair_label.add_theme_font_size_override("font_size", 22)
	crosshair_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 0.85))
	root.add_child(crosshair_label)

	hover_prompt_label = Label.new()
	hover_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hover_prompt_label.anchor_left = 0.2
	hover_prompt_label.anchor_right = 0.8
	hover_prompt_label.anchor_top = 0.54
	hover_prompt_label.anchor_bottom = 0.62
	hover_prompt_label.add_theme_font_size_override("font_size", 18)
	hover_prompt_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.60))
	root.add_child(hover_prompt_label)

	held_item_banner = Label.new()
	held_item_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	held_item_banner.anchor_left = 0.15
	held_item_banner.anchor_right = 0.85
	held_item_banner.anchor_top = 0.88
	held_item_banner.anchor_bottom = 0.93
	held_item_banner.add_theme_font_size_override("font_size", 16)
	held_item_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
	root.add_child(held_item_banner)

	var controls_bar := PanelContainer.new()
	controls_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	controls_bar.custom_minimum_size.y = 32
	controls_bar.add_theme_stylebox_override("panel", _make_panel_style(Color(0.02, 0.04, 0.08, 0.82), Color(0.2, 0.7, 0.9)))
	root.add_child(controls_bar)

	var lbl_controls := Label.new()
	lbl_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_controls.text = "[WASD] Caminar  [Shift] Correr  [Espacio] Saltar  [E/Clic] Agarrar/Usar  [Rueda] Distancia  [G/Der] Lanzar  [V] 1.ª/3.ª Pers.  [F] Linterna  [TAB] Terminal"
	lbl_controls.add_theme_font_size_override("font_size", 13)
	lbl_controls.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	controls_bar.add_child(lbl_controls)

	# Mini-Monitor Esquina Superior Derecha (visible mientras caminas en 1.ª persona)
	mini_hud_box = PanelContainer.new()
	mini_hud_box.anchor_left = 0.72
	mini_hud_box.anchor_right = 0.99
	mini_hud_box.anchor_top = 0.12
	mini_hud_box.anchor_bottom = 0.42
	mini_hud_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_hud_box.add_theme_stylebox_override("panel", _make_panel_style(Color(0.02, 0.05, 0.09, 0.76), Color(0.25, 0.85, 0.65)))
	root.add_child(mini_hud_box)

	lbl_mini_telemetry = RichTextLabel.new()
	lbl_mini_telemetry.bbcode_enabled = true
	lbl_mini_telemetry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_hud_box.add_child(lbl_mini_telemetry)

	# ==========================================================
	# 2. BARRA SUPERIOR COMPACTA
	# ==========================================================
	var top_bar := PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size.y = 72
	top_bar.add_theme_stylebox_override("panel", _make_panel_style(Color(0.04, 0.07, 0.11, 0.88), Color(0.2, 0.85, 0.95)))
	root.add_child(top_bar)

	var top_vbox := VBoxContainer.new()
	top_bar.add_child(top_vbox)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 18)
	top_vbox.add_child(header_row)

	lbl_header_mission = Label.new()
	lbl_header_mission.add_theme_color_override("font_color", Color(0.35, 1.0, 0.65))
	lbl_header_mission.add_theme_font_size_override("font_size", 15)
	lbl_header_mission.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(lbl_header_mission)

	lbl_header_phase = Label.new()
	lbl_header_phase.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	lbl_header_phase.add_theme_font_size_override("font_size", 15)
	header_row.add_child(lbl_header_phase)

	lbl_header_budget = Label.new()
	lbl_header_budget.add_theme_color_override("font_color", Color(0.4, 0.92, 1.0))
	lbl_header_budget.add_theme_font_size_override("font_size", 15)
	header_row.add_child(lbl_header_budget)

	var role_row := HBoxContainer.new()
	role_row.add_theme_constant_override("separation", 8)
	top_vbox.add_child(role_row)

	for r_idx in range(4):
		var btn := Button.new()
		btn.text = "[%d] %s" % [r_idx + 1, CatalogData.ROLE_NAMES[r_idx]]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var captured_role: int = r_idx
		btn.pressed.connect(func() -> void:
			GameState.set_role(captured_role)
			set_terminal_open(true)
		)
		role_row.add_child(btn)
		role_buttons.append(btn)

	var btn_brief := Button.new()
	btn_brief.text = "Briefing RPG"
	btn_brief.pressed.connect(func() -> void:
		GameState.set_phase(CatalogData.Phase.BRIEFING)
		set_terminal_open(true)
	)
	role_row.add_child(btn_brief)

	var btn_toggle_ui := Button.new()
	btn_toggle_ui.text = "[TAB] Caminar 1.ª Persona / Terminal"
	btn_toggle_ui.modulate = Color(0.45, 1.0, 0.65)
	btn_toggle_ui.pressed.connect(func() -> void: set_terminal_open(not terminal_open))
	role_row.add_child(btn_toggle_ui)

	var btn_crt := Button.new()
	btn_crt.text = "[F2] CRT"
	btn_crt.pressed.connect(_toggle_crt_shader)
	role_row.add_child(btn_crt)

	var btn_lan := Button.new()
	btn_lan.tooltip_text = "Multijugador LAN"
	btn_lan.text = "LAN"
	btn_lan.pressed.connect(func() -> void:
		set_terminal_open(true)
		panel_lan_modal.visible = not panel_lan_modal.visible
	)
	role_row.add_child(btn_lan)

	# ==========================================================
	# 3. CONTENEDOR MODAL DE TERMINALES CRT (SE ABRE CON E O TAB)
	# ==========================================================
	terminal_modal_root = Control.new()
	terminal_modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	terminal_modal_root.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(terminal_modal_root)

	_build_briefing_panel(terminal_modal_root)
	_build_assembly_panel(terminal_modal_root)
	_build_launch_panel(terminal_modal_root)
	_build_orbit_panel(terminal_modal_root)
	_build_receipt_panel(terminal_modal_root)
	_build_lan_modal(terminal_modal_root)

func _build_briefing_panel(root: Control) -> void:
	panel_briefing = PanelContainer.new()
	panel_briefing.anchor_left = 0.04
	panel_briefing.anchor_right = 0.96
	panel_briefing.anchor_top = 0.46
	panel_briefing.anchor_bottom = 0.94
	panel_briefing.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.06, 0.09, 0.94), Color(0.25, 0.95, 0.55)))
	root.add_child(panel_briefing)

	var hsplit := HBoxContainer.new()
	hsplit.add_theme_constant_override("separation", 16)
	panel_briefing.add_child(hsplit)

	var left_col := VBoxContainer.new()
	left_col.custom_minimum_size.x = 390
	hsplit.add_child(left_col)

	var lbl_sel := Label.new()
	lbl_sel.text = "SELECCIÓN DE OPERACIÓN Y MODO:"
	lbl_sel.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	left_col.add_child(lbl_sel)

	var m_row := HBoxContainer.new()
	left_col.add_child(m_row)
	var missions: Array[Dictionary] = CatalogData.get_missions()
	for i in range(missions.size()):
		var b := Button.new()
		b.text = "Misión %d" % [i + 1]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx: int = i
		b.pressed.connect(func() -> void:
			current_dialog_idx = 0
			GameState.load_mission(idx, false)
		)
		m_row.add_child(b)

	var btn_sandbox := Button.new()
	btn_sandbox.text = "MODO SANDBOX DE PRUEBAS ($ ILIMITADO)"
	btn_sandbox.modulate = Color(0.45, 1.0, 0.75)
	btn_sandbox.pressed.connect(func() -> void:
		current_dialog_idx = 0
		GameState.load_mission(GameState.current_mission_idx, true)
	)
	left_col.add_child(btn_sandbox)

	lbl_mission_specs = RichTextLabel.new()
	lbl_mission_specs.bbcode_enabled = true
	lbl_mission_specs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(lbl_mission_specs)

	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_child(right_col)

	var speaker_row := HBoxContainer.new()
	right_col.add_child(speaker_row)

	lbl_rpg_speaker = Label.new()
	lbl_rpg_speaker.add_theme_color_override("font_color", Color(0.3, 0.95, 1.0))
	lbl_rpg_speaker.add_theme_font_size_override("font_size", 17)
	lbl_rpg_speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speaker_row.add_child(lbl_rpg_speaker)

	lbl_rpg_role_hint = Label.new()
	lbl_rpg_role_hint.add_theme_color_override("font_color", Color(1.0, 0.75, 0.25))
	speaker_row.add_child(lbl_rpg_role_hint)

	lbl_rpg_text = RichTextLabel.new()
	lbl_rpg_text.bbcode_enabled = true
	lbl_rpg_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_child(lbl_rpg_text)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	right_col.add_child(btn_row)

	var btn_prev := Button.new()
	btn_prev.text = "<< Anterior"
	btn_prev.pressed.connect(func() -> void:
		current_dialog_idx = max(0, current_dialog_idx - 1)
		_refresh_briefing_dialog()
	)
	btn_row.add_child(btn_prev)

	var btn_next := Button.new()
	btn_next.text = "Siguiente Transmisión RPG >>"
	btn_next.pressed.connect(func() -> void:
		var dialogs: Array = GameState.get_current_mission()["briefing_dialogs"]
		current_dialog_idx = (current_dialog_idx + 1) % max(dialogs.size(), 1)
		_refresh_briefing_dialog()
	)
	btn_row.add_child(btn_next)

	var btn_start_assembly := Button.new()
	btn_start_assembly.text = "SALIR A EXPLORAR Y ENSAMBLAR EN 1.ª PERSONA [TAB] >>"
	btn_start_assembly.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_start_assembly.modulate = Color(0.4, 1.0, 0.55)
	btn_start_assembly.pressed.connect(func() -> void:
		GameState.set_phase(CatalogData.Phase.ASSEMBLY)
		set_terminal_open(false)
	)
	btn_row.add_child(btn_start_assembly)

func _build_assembly_panel(root: Control) -> void:
	panel_assembly = Control.new()
	panel_assembly.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_assembly.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(panel_assembly)

	var left_station := PanelContainer.new()
	left_station.anchor_left = 0.02
	left_station.anchor_right = 0.48
	left_station.anchor_top = 0.13
	left_station.anchor_bottom = 0.94
	left_station.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.06, 0.10, 0.93), Color(0.25, 0.85, 1.0)))
	panel_assembly.add_child(left_station)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 6)
	left_station.add_child(left_vbox)

	var close_row := HBoxContainer.new()
	left_vbox.add_child(close_row)

	lbl_role_banner = Label.new()
	lbl_role_banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	lbl_role_banner.add_theme_font_size_override("font_size", 16)
	lbl_role_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_row.add_child(lbl_role_banner)

	var btn_close_fp := Button.new()
	btn_close_fp.text = "Volver a 1.ª Persona [TAB]"
	btn_close_fp.modulate = Color(0.4, 1.0, 0.65)
	btn_close_fp.pressed.connect(func() -> void: set_terminal_open(false))
	close_row.add_child(btn_close_fp)

	lbl_role_desc = Label.new()
	lbl_role_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_role_desc.add_theme_color_override("font_color", Color(0.75, 0.88, 0.95))
	lbl_role_desc.add_theme_font_size_override("font_size", 12)
	left_vbox.add_child(lbl_role_desc)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(scroll)

	role_content_box = VBoxContainer.new()
	role_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_content_box.add_theme_constant_override("separation", 6)
	scroll.add_child(role_content_box)

	var right_station := PanelContainer.new()
	right_station.anchor_left = 0.64
	right_station.anchor_right = 0.98
	right_station.anchor_top = 0.13
	right_station.anchor_bottom = 0.94
	right_station.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.06, 0.10, 0.93), Color(0.3, 0.95, 0.55)))
	panel_assembly.add_child(right_station)

	var right_vbox := VBoxContainer.new()
	right_station.add_child(right_vbox)

	var lbl_tel_title := Label.new()
	lbl_tel_title.text = "DIAGNÓSTICO DE INGENIERÍA (CAUSA-EFECTO)"
	lbl_tel_title.add_theme_color_override("font_color", Color(0.35, 1.0, 0.65))
	right_vbox.add_child(lbl_tel_title)

	lbl_quick_telemetry = RichTextLabel.new()
	lbl_quick_telemetry.bbcode_enabled = true
	lbl_quick_telemetry.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(lbl_quick_telemetry)

	var lbl_log_title := Label.new()
	lbl_log_title.text = "BITÁCORA DE INTERCOMUNICADOR:"
	lbl_log_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	right_vbox.add_child(lbl_log_title)

	lbl_comms_log = RichTextLabel.new()
	lbl_comms_log.custom_minimum_size.y = 135
	right_vbox.add_child(lbl_comms_log)

	var bottom_actions := HBoxContainer.new()
	right_vbox.add_child(bottom_actions)

	var btn_preset := Button.new()
	btn_preset.text = "Auto-Ensamblar Ref."
	btn_preset.pressed.connect(func() -> void: GameState.load_recommended_preset())
	bottom_actions.add_child(btn_preset)

	var btn_launch := Button.new()
	btn_launch.text = "¡LANZAR COHETE! >>"
	btn_launch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_launch.modulate = Color(0.4, 1.0, 0.55)
	btn_launch.pressed.connect(func() -> void:
		GameState.set_phase(CatalogData.Phase.LAUNCH_SIM)
		set_terminal_open(false)
	)
	bottom_actions.add_child(btn_launch)

func _build_launch_panel(root: Control) -> void:
	panel_launch = PanelContainer.new()
	panel_launch.anchor_left = 0.15
	panel_launch.anchor_right = 0.85
	panel_launch.anchor_top = 0.62
	panel_launch.anchor_bottom = 0.93
	panel_launch.add_theme_stylebox_override("panel", _make_panel_style(Color(0.04, 0.06, 0.10, 0.92), Color(1.0, 0.65, 0.2)))
	root.add_child(panel_launch)

	var vbox := VBoxContainer.new()
	panel_launch.add_child(vbox)

	var title := Label.new()
	title.text = "FASE 3: TELEMETRÍA DE SIMULACIÓN Y ASCENSO EN TIEMPO REAL"
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.25))
	title.add_theme_font_size_override("font_size", 17)
	vbox.add_child(title)

	bar_launch_progress = ProgressBar.new()
	bar_launch_progress.max_value = 100.0
	bar_launch_progress.custom_minimum_size.y = 24
	vbox.add_child(bar_launch_progress)

	lbl_launch_telemetry = RichTextLabel.new()
	lbl_launch_telemetry.bbcode_enabled = true
	lbl_launch_telemetry.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(lbl_launch_telemetry)

func _build_orbit_panel(root: Control) -> void:
	panel_orbit = PanelContainer.new()
	panel_orbit.anchor_left = 0.03
	panel_orbit.anchor_right = 0.97
	panel_orbit.anchor_top = 0.50
	panel_orbit.anchor_bottom = 0.94
	panel_orbit.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.06, 0.10, 0.92), Color(1.0, 0.35, 0.35)))
	root.add_child(panel_orbit)

	var vbox := VBoxContainer.new()
	panel_orbit.add_child(vbox)

	lbl_crisis_banner = Label.new()
	lbl_crisis_banner.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	lbl_crisis_banner.add_theme_font_size_override("font_size", 17)
	vbox.add_child(lbl_crisis_banner)

	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	lbl_orbit_telemetry = RichTextLabel.new()
	lbl_orbit_telemetry.bbcode_enabled = true
	lbl_orbit_telemetry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl_orbit_telemetry)

	var actions_col := VBoxContainer.new()
	actions_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(actions_col)

	var lbl_act := Label.new()
	lbl_act.text = "MANIOBRAS DE RESPUESTA Y GESTIÓN DE CRISIS:"
	lbl_act.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	actions_col.add_child(lbl_act)

	var btn_rcs := Button.new()
	btn_rcs.text = "DISPARAR VECTORES DE EMPUJE RCS (-18° Deriva / -8 kg RCS)"
	btn_rcs.modulate = Color(1.0, 0.78, 0.3)
	btn_rcs.pressed.connect(func() -> void: GameState.fire_rcs_correction())
	actions_col.add_child(btn_rcs)

	var freq_row := HBoxContainer.new()
	actions_col.add_child(freq_row)
	var lbl_f := Label.new()
	lbl_f.text = "Sintonía Antena (MHz):"
	freq_row.add_child(lbl_f)

	slider_live_freq = HSlider.new()
	slider_live_freq.min_value = 1500.0
	slider_live_freq.max_value = 3500.0
	slider_live_freq.step = 10.0
	slider_live_freq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_live_freq.value_changed.connect(func(v: float) -> void:
		GameState.set_antenna_frequency(v)
	)
	freq_row.add_child(slider_live_freq)

	lbl_live_freq_val = Label.new()
	freq_row.add_child(lbl_live_freq_val)

	var scroll_inst := ScrollContainer.new()
	scroll_inst.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions_col.add_child(scroll_inst)

	orbit_instruments_box = VBoxContainer.new()
	orbit_instruments_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_inst.add_child(orbit_instruments_box)

func _build_receipt_panel(root: Control) -> void:
	panel_receipt = PanelContainer.new()
	panel_receipt.anchor_left = 0.14
	panel_receipt.anchor_right = 0.86
	panel_receipt.anchor_top = 0.14
	panel_receipt.anchor_bottom = 0.93
	panel_receipt.add_theme_stylebox_override("panel", _make_panel_style(Color(0.92, 0.90, 0.82, 0.97), Color(0.25, 0.25, 0.25)))
	root.add_child(panel_receipt)

	var vbox := VBoxContainer.new()
	panel_receipt.add_child(vbox)

	var title := Label.new()
	title.text = "=== IMPRESORA MATRICIAL EPSON-80 : INFORME DE MISIÓN Y CAUSA-EFECTO ==="
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.1, 0.12, 0.15))
	title.add_theme_font_size_override("font_size", 17)
	vbox.add_child(title)

	lbl_receipt_printer = RichTextLabel.new()
	lbl_receipt_printer.bbcode_enabled = true
	lbl_receipt_printer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl_receipt_printer.add_theme_color_override("default_color", Color(0.08, 0.10, 0.12))
	vbox.add_child(lbl_receipt_printer)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var btn_retry := Button.new()
	btn_retry.text = "VOLVER AL MUNDO 3D (CORREGIR DISEÑO)"
	btn_retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_retry.pressed.connect(func() -> void:
		GameState.set_phase(CatalogData.Phase.ASSEMBLY)
		set_terminal_open(false)
	)
	btn_row.add_child(btn_retry)

	var btn_sandbox := Button.new()
	btn_sandbox.text = "ABRIR EN MODO SANDBOX"
	btn_sandbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_sandbox.pressed.connect(func() -> void:
		GameState.load_mission(GameState.current_mission_idx, true)
		GameState.set_phase(CatalogData.Phase.ASSEMBLY)
		set_terminal_open(false)
	)
	btn_row.add_child(btn_sandbox)

	var btn_next_mission := Button.new()
	btn_next_mission.text = "SIGUIENTE MISIÓN DE CAMPAÑA >>"
	btn_next_mission.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_next_mission.pressed.connect(func() -> void:
		var next_idx: int = (GameState.current_mission_idx + 1) % CatalogData.get_missions().size()
		GameState.load_mission(next_idx, false)
		GameState.set_phase(CatalogData.Phase.ASSEMBLY)
		set_terminal_open(false)
	)
	btn_row.add_child(btn_next_mission)

func _build_lan_modal(root: Control) -> void:
	panel_lan_modal = PanelContainer.new()
	panel_lan_modal.visible = false
	panel_lan_modal.anchor_left = 0.32
	panel_lan_modal.anchor_right = 0.68
	panel_lan_modal.anchor_top = 0.25
	panel_lan_modal.anchor_bottom = 0.58
	panel_lan_modal.add_theme_stylebox_override("panel", _make_panel_style(Color(0.05, 0.08, 0.14, 0.96), Color(0.3, 0.9, 1.0)))
	root.add_child(panel_lan_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel_lan_modal.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "SALA COOPERATIVA LAN (HASTA 4 JUGADORES)"
	lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	vbox.add_child(lbl)

	var ip_input := LineEdit.new()
	ip_input.text = "127.0.0.1"
	ip_input.placeholder_text = "IP del Anfitrión"
	vbox.add_child(ip_input)

	var status_lbl := Label.new()
	status_lbl.text = "Modo actual: Exploración 1.ª Persona + Red LAN"
	vbox.add_child(status_lbl)

	var row := HBoxContainer.new()
	vbox.add_child(row)

	var btn_host := Button.new()
	btn_host.text = "Crear Partida (Host :7777)"
	btn_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_host.pressed.connect(func() -> void: status_lbl.text = GameState.host_lan_game(7777))
	row.add_child(btn_host)

	var btn_join := Button.new()
	btn_join.text = "Unirse a IP"
	btn_join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_join.pressed.connect(func() -> void: status_lbl.text = GameState.join_lan_game(ip_input.text, 7777))
	row.add_child(btn_join)

	var btn_close := Button.new()
	btn_close.text = "Cerrar"
	btn_close.pressed.connect(func() -> void: panel_lan_modal.visible = false)
	vbox.add_child(btn_close)

func _build_crt_post_overlay() -> void:
	crt_overlay = ColorRect.new()
	crt_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := load("res://shaders/crt_vhs.gdshader") as Shader
	if sh:
		var sm := ShaderMaterial.new()
		sm.shader = sh
		crt_overlay.material = sm
	add_child(crt_overlay)

# ==========================================================
# ACTUALIZACIÓN DE FASES Y PANELES ASIMÉTRICOS POR ROL
# ==========================================================
func _on_phase_changed(new_phase: int) -> void:
	panel_briefing.visible = (new_phase == CatalogData.Phase.BRIEFING)
	panel_assembly.visible = (new_phase == CatalogData.Phase.ASSEMBLY)
	panel_launch.visible = (new_phase == CatalogData.Phase.LAUNCH_SIM)
	panel_orbit.visible = (new_phase == CatalogData.Phase.ORBIT_OPS)
	panel_receipt.visible = (new_phase == CatalogData.Phase.DEBRIEF)

	if new_phase == CatalogData.Phase.DEBRIEF:
		_prepare_matrix_receipt_text()
		set_terminal_open(true)
	elif new_phase == CatalogData.Phase.ORBIT_OPS:
		_rebuild_orbit_instrument_toggles()
		set_terminal_open(true)

	_refresh_all_panels()

func _on_role_changed(new_role: int) -> void:
	for i in range(role_buttons.size()):
		role_buttons[i].modulate = Color(1.0, 0.9, 0.35) if i == new_role else Color(0.75, 0.85, 0.9)
	_rebuild_role_exclusive_panel()

func _refresh_all_panels() -> void:
	var m: Dictionary = GameState.get_current_mission()
	var stats: Dictionary = GameState.evaluate_current_design()
	var mode_tag: String = "[SANDBOX $ ILIMITADO]" if GameState.sandbox_mode else "[CAMPAÑA]"

	lbl_header_mission.text = "%s %s" % [m["title"], mode_tag]
	lbl_header_phase.text = CatalogData.PHASE_NAMES.get(GameState.current_phase, "")
	if GameState.sandbox_mode:
		lbl_header_budget.text = "GASTO: $%.0fM (SANDBOX)" % stats["total_cost"]
	else:
		lbl_header_budget.text = "PRESUPUESTO: $%.0fM / $%.0fM" % [stats["total_cost"], m["budget"]]

	_refresh_briefing_dialog()
	_rebuild_role_exclusive_panel()
	_refresh_quick_engineering_telemetry(stats, m)
	_on_log_added("")

func _refresh_briefing_dialog() -> void:
	var m: Dictionary = GameState.get_current_mission()
	var dialogs: Array = m["briefing_dialogs"]
	current_dialog_idx = clampi(current_dialog_idx, 0, max(dialogs.size() - 1, 0))
	if not dialogs.is_empty():
		var d: Dictionary = dialogs[current_dialog_idx]
		lbl_rpg_speaker.text = ">> " + String(d["speaker"])
		lbl_rpg_role_hint.text = "[ROL CLAVE: %s]" % String(d["role_hint"])
		lbl_rpg_text.text = "[font_size=16]%s[/font_size]\n\n[color=#88ccff](Transmisión %d de %d — Pulsa TAB para caminar en 1.ª persona por el Centro Espacial)[/color]" % [
			d["text"], current_dialog_idx + 1, dialogs.size()
		]

	lbl_mission_specs.text = (
		"[b][color=#66ffaa]PARÁMETROS DE MISIÓN:[/color][/b]\n"
		+ "• Presupuesto: [b]$%.0fM[/b]\n" % m["budget"]
		+ "• Altitud Orbital: [b]%.0f - %.0f km[/b]\n" % [m["target_alt_min"], m["target_alt_max"]]
		+ "• Inclinación: [b]%.0f° - %.0f°[/b]\n" % [m["target_inc_min"], m["target_inc_max"]]
		+ "• Valor Científico Mín.: [b]%d pts[/b]\n" % int(m["min_science"])
		+ "• Ancho de Banda Mín.: [b]%.0f Mbps[/b]" % float(m["min_bandwidth"])
	)

func _rebuild_role_exclusive_panel() -> void:
	if not is_instance_valid(role_content_box):
		return
	for child in role_content_box.get_children():
		child.queue_free()

	var role: int = GameState.current_role
	lbl_role_banner.text = "TERMINAL EXCLUSIVA — " + CatalogData.ROLE_NAMES[role]
	lbl_role_desc.text = CatalogData.ROLE_DESCRIPTIONS[role]

	var stats: Dictionary = GameState.evaluate_current_design()
	var m: Dictionary = GameState.get_current_mission()

	match role:
		CatalogData.Role.DIRECTOR:
			_build_director_controls(stats, m)
		CatalogData.Role.ENGINEER:
			_build_engineer_controls(stats)
		CatalogData.Role.SCIENTIST:
			_build_scientist_controls(stats, m)
		CatalogData.Role.FLIGHT_SPEC:
			_build_flight_spec_controls(stats, m)

func _build_director_controls(stats: Dictionary, _m: Dictionary) -> void:
	var fin_lbl := RichTextLabel.new()
	fin_lbl.bbcode_enabled = true
	fin_lbl.fit_content = true
	var rem: float = GameState.get_budget_limit() - float(stats["total_cost"])
	fin_lbl.text = (
		"[b][color=#ffdd55]AUDITORÍA PRESUPUESTARIA DEL DIRECTOR:[/color][/b]\n"
		+ "• Costo Módulos y Bus: [b]$%.0fM[/b]\n" % stats["parts_cost"]
		+ "• Costo Vehículo Lanzador: [b]$%.0fM[/b]\n" % stats["rocket_cost"]
		+ "• Fondos Disponibles: [b]$%.0fM[/b]\n" % rem
	)
	role_content_box.add_child(fin_lbl)

	var conf_header := Label.new()
	conf_header.text = "DECISIONES DE ARBITRAJE DEL EQUIPO:"
	conf_header.add_theme_color_override("font_color", Color(1.0, 0.65, 0.3))
	role_content_box.add_child(conf_header)

	for i in range(GameState.team_conflicts.size()):
		var c: Dictionary = GameState.team_conflicts[i]
		var box := VBoxContainer.new()
		role_content_box.add_child(box)
		var l := Label.new()
		var status_tag: String = " [RESUELTO]" if c["resolved"] else " [PENDIENTE]"
		l.text = "• " + String(c["title"]) + status_tag + "\n  " + String(c["desc"])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
		if not c["resolved"]:
			var h := HBoxContainer.new()
			box.add_child(h)
			var idx: int = i
			var ba := Button.new()
			ba.text = String(c["option_a_label"])
			ba.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ba.pressed.connect(func() -> void: GameState.resolve_conflict(idx, true))
			h.add_child(ba)
			var bb := Button.new()
			bb.text = String(c["option_b_label"])
			bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bb.pressed.connect(func() -> void: GameState.resolve_conflict(idx, false))
			h.add_child(bb)

func _build_engineer_controls(stats: Dictionary) -> void:
	var eng_info := RichTextLabel.new()
	eng_info.bbcode_enabled = true
	eng_info.fit_content = true
	var net_col: String = "#55ff77" if float(stats["power_net"]) >= 0.0 else "#ff5555"
	eng_info.text = (
		"[b][color=#55eeff]CONTROL FÍSICO DE MESA HOLOGRÁFICA 3D:[/color][/b]\n"
		+ "• Masa Total: [b]%.0f / %.0f kg[/b] (TWR: [b]%.2f[/b])\n" % [stats["total_mass"], stats["max_payload"], stats["twr"]]
		+ "• Balance Eléctrico: [b]+%.0fW gen / -%.0fW uso[/b] ([color=%s]Neto: %+.0fW[/color])\n" % [
			stats["power_gen"], stats["power_use"], net_col, stats["power_net"]
		]
		+ "• Ranuras 3D Ocupadas: [b]%d / %d[/b] (Volumen: %.1f m³)" % [
			GameState.placed_parts.size(), GameState.HOLO_SLOTS.size(), stats["total_volume"]
		]
	)
	role_content_box.add_child(eng_info)

	var rot_btn := Button.new()
	rot_btn.text = "Rotar Última Pieza en Mesa 3D (+45°)"
	rot_btn.pressed.connect(func() -> void: GameState.rotate_last_part())
	role_content_box.add_child(rot_btn)

	var cat_lbl := Label.new()
	cat_lbl.text = "ACOPLAR MÓDULO DIRECTAMENTE (O recógelos físicamente en el Hangar):"
	cat_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	role_content_box.add_child(cat_lbl)

	for p in CatalogData.get_parts():
		var btn := Button.new()
		btn.text = "+ %s ($%.0fM | %.0fkg | +%dW/-%dW)" % [
			p["name"], p["cost"], p["mass"], int(p["power_gen"]), int(p["power_use"])
		]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var pid: String = p["id"]
		btn.pressed.connect(func() -> void: GameState.add_part_to_assembly(pid))
		role_content_box.add_child(btn)

	if not GameState.placed_parts.is_empty():
		var rem_lbl := Label.new()
		rem_lbl.text = "PIEZAS ACOPLADAS EN EL CHASIS 3D (Clic para desmontar):"
		rem_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
		role_content_box.add_child(rem_lbl)
		for i in range(GameState.placed_parts.size()):
			var p_id: String = GameState.placed_parts[i]["part_id"]
			var p_data: Dictionary = CatalogData.get_part_by_id(p_id)
			var b_rem := Button.new()
			b_rem.text = "[-] Ranura #%d: %s (%.0f kg)" % [i + 1, p_data.get("name", p_id), p_data.get("mass", 0.0)]
			var idx: int = i
			b_rem.pressed.connect(func() -> void: GameState.remove_part_at(idx))
			role_content_box.add_child(b_rem)

func _build_scientist_controls(stats: Dictionary, m: Dictionary) -> void:
	var sci_info := RichTextLabel.new()
	sci_info.bbcode_enabled = true
	sci_info.fit_content = true
	sci_info.text = (
		"[b][color=#66ff88]LABORATORIO DE CARGA ÚTIL CIENTÍFICA:[/color][/b]\n"
		+ "• Valor Científico Instalado: [b]%d / %d pts[/b]\n" % [int(stats["total_science"]), int(m["min_science"])]
		+ "• Generación de Datos: [b]%.1f Mbps[/b] (Ancho de banda actual: %.1f Mbps)\n" % [
			stats["data_rate_mbps"], stats["effective_bandwidth"]
		]
	)
	role_content_box.add_child(sci_info)

	for p in CatalogData.get_parts():
		if p["category"] != "science":
			continue
		var card := VBoxContainer.new()
		role_content_box.add_child(card)
		var l := Label.new()
		l.text = "★ %s (+%d Ciencia | %.1f Mbps | $%.0fM | %.0f kg | -%.0fW)" % [
			p["name"], int(p["science"]), p["data_rate"], p["cost"], p["mass"], p["power_use"]
		]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", Color(0.45, 1.0, 0.65))
		card.add_child(l)

		var h := HBoxContainer.new()
		card.add_child(h)
		var pid: String = p["id"]
		var btn_req := Button.new()
		btn_req.text = "Solicitar al Ingeniero"
		btn_req.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_req.pressed.connect(func() -> void: GameState.request_science_part(pid))
		h.add_child(btn_req)

		var btn_mount := Button.new()
		btn_mount.text = "Acoplar en Mesa 3D"
		btn_mount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_mount.pressed.connect(func() -> void: GameState.add_part_to_assembly(pid))
		h.add_child(btn_mount)

func _build_flight_spec_controls(stats: Dictionary, m: Dictionary) -> void:
	var fl_info := RichTextLabel.new()
	fl_info.bbcode_enabled = true
	fl_info.fit_content = true
	fl_info.text = (
		"[b][color=#ff88dd]NAVEGACIÓN ORBITAL Y TELECOMUNICACIONES:[/color][/b]\n"
		+ "• Delta-V Disponible vs Requerido: [b]%.0f / %.0f m/s[/b]\n" % [stats["available_dv"], stats["required_dv"]]
		+ "• Ventana Altitud Meta: [b]%.0f - %.0f km[/b] | Inclinación: [b]%.0f° - %.0f°[/b]\n" % [
			m["target_alt_min"], m["target_alt_max"], m["target_inc_min"], m["target_inc_max"]
		]
		+ "• Ancho de Banda Efectivo: [b]%.1f Mbps[/b] (Eficiencia Sintonía: %.0f%%)" % [
			stats["effective_bandwidth"], float(stats["calibration_efficiency"]) * 100.0
		]
	)
	role_content_box.add_child(fl_info)

	var r_lbl := Label.new()
	r_lbl.text = "1. VEHÍCULO DE LANZAMIENTO:"
	r_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	role_content_box.add_child(r_lbl)

	for r in CatalogData.get_rockets():
		var b := Button.new()
		var active_mark: String = "[SELECCIONADO] " if r["id"] == GameState.selected_rocket_id else ""
		b.text = "%s%s ($%.0fM | Máx %.0f kg | %.0f m/s DV)" % [
			active_mark, r["name"], r["cost"], r["max_payload_kg"], r["base_delta_v"]
		]
		var rid: String = r["id"]
		b.pressed.connect(func() -> void: GameState.select_rocket(rid))
		role_content_box.add_child(b)

	var alt_lbl := Label.new()
	alt_lbl.text = "2. ALTITUD ORBITAL EN GLOBO 3D: %.0f km %s" % [
		GameState.target_altitude_km,
		"(¡ALERTA FRICCIÓN ATMOSFÉRICA!)" if GameState.target_altitude_km < 340.0 else ""
	]
	role_content_box.add_child(alt_lbl)

	var alt_slider := HSlider.new()
	alt_slider.min_value = 180.0
	alt_slider.max_value = 37000.0
	alt_slider.step = 50.0
	alt_slider.value = GameState.target_altitude_km
	alt_slider.value_changed.connect(func(v: float) -> void:
		GameState.set_orbital_parameters(v, GameState.target_inclination_deg)
	)
	role_content_box.add_child(alt_slider)

	var inc_lbl := Label.new()
	inc_lbl.text = "3. INCLINACIÓN ORBITAL: %.1f°" % GameState.target_inclination_deg
	role_content_box.add_child(inc_lbl)

	var inc_slider := HSlider.new()
	inc_slider.min_value = 0.0
	inc_slider.max_value = 100.0
	inc_slider.step = 1.0
	inc_slider.value = GameState.target_inclination_deg
	inc_slider.value_changed.connect(func(v: float) -> void:
		GameState.set_orbital_parameters(GameState.target_altitude_km, v)
	)
	role_content_box.add_child(inc_slider)

	var freq_lbl := Label.new()
	freq_lbl.text = "4. CALIBRACIÓN DE ANTENA: %.0f MHz (Óptimo: %.0f MHz)" % [
		GameState.antenna_freq_mhz, GameState.optimal_freq_mhz
	]
	role_content_box.add_child(freq_lbl)

	var freq_slider := HSlider.new()
	freq_slider.min_value = 1500.0
	freq_slider.max_value = 3500.0
	freq_slider.step = 10.0
	freq_slider.value = GameState.antenna_freq_mhz
	freq_slider.value_changed.connect(func(v: float) -> void:
		GameState.set_antenna_frequency(v)
	)
	role_content_box.add_child(freq_slider)

func _refresh_quick_engineering_telemetry(stats: Dictionary, m: Dictionary) -> void:
	var mass_ok: bool = float(stats["total_mass"]) <= float(stats["max_payload"]) and float(stats["twr"]) >= 1.0
	var dv_ok: bool = float(stats["available_dv"]) >= float(stats["required_dv"])
	var pwr_ok: bool = float(stats["power_net"]) >= 0.0
	var sci_ok: bool = int(stats["total_science"]) >= int(m["min_science"])
	var bw_ok: bool = float(stats["effective_bandwidth"]) >= float(m["min_bandwidth"])
	var alt_ok: bool = GameState.target_altitude_km >= float(m["target_alt_min"]) and GameState.target_altitude_km <= float(m["target_alt_max"])

	var tel_bbcode: String = (
		"• Masa / Cohete: [color=%s]%.0f / %.0f kg (TWR %.2f)[/color]\n" % [
			"#55ff77" if mass_ok else "#ff5555", stats["total_mass"], stats["max_payload"], stats["twr"]
		]
		+ "• Impulso Delta-V: [color=%s]%.0f / %.0f m/s[/color]\n" % [
			"#55ff77" if dv_ok else "#ff5555", stats["available_dv"], stats["required_dv"]
		]
		+ "• Energía Orbital: [color=%s]%+.0f W netos (Bat: %.0f Wh)[/color]\n" % [
			"#55ff77" if pwr_ok else "#ff5555", stats["power_net"], stats["battery_cap"]
		]
		+ "• Valor Científico: [color=%s]%d / %d pts[/color]\n" % [
			"#55ff77" if sci_ok else "#ffaa44", int(stats["total_science"]), int(m["min_science"])
		]
		+ "• Ancho de Banda: [color=%s]%.1f / %.1f Mbps[/color]\n" % [
			"#55ff77" if bw_ok else "#ffaa44", stats["effective_bandwidth"], m["min_bandwidth"]
		]
		+ "• Órbita Trazada: [color=%s]%.0f km | %.1f°[/color]" % [
			"#55ff77" if alt_ok else "#ffaa44", GameState.target_altitude_km, GameState.target_inclination_deg
		]
	)
	if is_instance_valid(lbl_quick_telemetry):
		lbl_quick_telemetry.text = tel_bbcode
	if is_instance_valid(lbl_mini_telemetry):
		var last_log: String = GameState.comms_log[0] if not GameState.comms_log.is_empty() else ""
		lbl_mini_telemetry.text = "[b][color=#66ffcc]ESTADO DE LA NAVE 3D (%d piezas):[/color][/b]\n" % GameState.placed_parts.size() + tel_bbcode + "\n[color=#ffdd66]" + last_log + "[/color]"

func _on_log_added(_msg: String) -> void:
	if is_instance_valid(lbl_comms_log):
		lbl_comms_log.text = "\n".join(GameState.comms_log.slice(0, 8))

func _refresh_telemetry_views() -> void:
	if GameState.current_phase == CatalogData.Phase.LAUNCH_SIM:
		bar_launch_progress.value = clampf(GameState.launch_progress * 100.0, 0.0, 100.0)
		var stats: Dictionary = GameState.evaluate_current_design()
		var launch_txt: String = (
			"[b]ALTITUD ACTUAL:[/b] %.1f km / %.0f km   |   [b]VELOCIDAD:[/b] %.0f m/s\n" % [
				GameState.launch_altitude_km, GameState.target_altitude_km, GameState.launch_velocity_ms
			]
			+ "[b]EMPUJE / PESO (TWR):[/b] %.2f   |   [b]MASA NAVE:[/b] %.0f kg / %.0f kg máx." % [
				stats["twr"], stats["total_mass"], stats["max_payload"]
			]
		)
		lbl_launch_telemetry.text = launch_txt
		if is_instance_valid(lbl_mini_telemetry):
			lbl_mini_telemetry.text = "[b][color=#ffaa33]DESPEGUE EN CURSO (Mira hacia la Rampa Norte):[/color][/b]\n" + launch_txt
	elif GameState.current_phase == CatalogData.Phase.ORBIT_OPS:
		var stats: Dictionary = GameState.evaluate_current_design()
		if GameState.active_crisis.is_empty():
			lbl_crisis_banner.text = "ESTADO ORBITAL NOMINAL — Monitoreando telemetría CRT..."
			lbl_crisis_banner.add_theme_color_override("font_color", Color(0.35, 1.0, 0.65))
		else:
			lbl_crisis_banner.text = "¡¡ALERTA DE CRISIS: %s (%.1fs)!! — %s" % [
				GameState.active_crisis.get("title", ""),
				GameState.crisis_timer,
				GameState.active_crisis.get("desc", "")
			]
			lbl_crisis_banner.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))

		lbl_orbit_telemetry.text = (
			"[b][color=#55eeff]TELEMETRÍA EN VIVO (TIEMPO RESTANTE: %.1fs):[/color][/b]\n" % max(0.0, GameState.orbit_duration_sec - GameState.orbit_time_sec)
			+ "• Carga de Batería: [b]%.0f / %.0f Wh[/b] (Consumo: %.0fW)\n" % [GameState.battery_wh, GameState.max_battery_wh, stats["power_use"]]
			+ "• Combustible RCS: [b]%.1f kg[/b]\n" % GameState.rcs_fuel_left
			+ "• Error de Actitud (Deriva): [b]%.1f°[/b] (Peligro > 65°)\n" % GameState.attitude_error_deg
			+ "• Ancho de Banda Efectivo: [b]%.1f Mbps[/b]\n" % stats["effective_bandwidth"]
			+ "• Datos Científicos Transmitidos: [b]%.1f GB[/b]" % GameState.collected_data_gb
		)
		lbl_live_freq_val.text = "%.0f / %.0f MHz" % [GameState.antenna_freq_mhz, GameState.optimal_freq_mhz]

func _rebuild_orbit_instrument_toggles() -> void:
	if not is_instance_valid(orbit_instruments_box):
		return
	for c in orbit_instruments_box.get_children():
		c.queue_free()
	for i in range(GameState.placed_parts.size()):
		var p_id: String = GameState.placed_parts[i]["part_id"]
		var part: Dictionary = CatalogData.get_part_by_id(p_id)
		if float(part.get("power_use", 0.0)) <= 0.0:
			continue
		var is_off: bool = GameState.disabled_part_indices.has(i)
		var btn := Button.new()
		btn.text = "%s: %s (%.0fW)" % [
			"ENCENDER" if is_off else "APAGAR (Ahorrar Energía)",
			part["name"],
			part["power_use"]
		]
		var idx: int = i
		btn.pressed.connect(func() -> void:
			GameState.toggle_instrument_power(idx)
			_rebuild_orbit_instrument_toggles()
		)
		orbit_instruments_box.add_child(btn)

func _prepare_matrix_receipt_text() -> void:
	var r: Dictionary = GameState.last_receipt
	if r.is_empty():
		return
	receipt_full_text = (
		"====================================================================\n"
		+ "AGENCIA AEROESPACIAL RETRO-ANALÓGICA — REGISTRO DE IMPRESORA MATRICIAL\n"
		+ "OPERACIÓN: %s   |   CALIFICACIÓN: %s\n" % [r["mission_title"], r["grade"]]
		+ "====================================================================\n\n"
		+ ">> DIAGNÓSTICO DE CAUSA Y EFECTO:\n"
		+ "%s\n\n" % r["cause_explanation"]
		+ "--------------------------------------------------------------------\n"
		+ "DESGLOSE TÉCNICO DE INGENIERÍA:\n"
		+ "  * PRESUPUESTO UTILIZADO : $%.0fM / $%.0fM\n" % [r["total_cost"], r["budget_limit"]]
		+ "  * MASA Y ESTRUCTURA     : %.0f kg / %.0f kg máx (TWR: %.2f)\n" % [r["total_mass"], r["max_payload"], r["twr"]]
		+ "  * IMPULSO DELTA-V       : %.0f m/s disponibles vs %.0f m/s requeridos\n" % [r["available_dv"], r["required_dv"]]
		+ "  * BALANCE ENERGÉTICO    : +%.0f W generados vs -%.0f W consumidos\n" % [r["power_gen"], r["power_use"]]
		+ "  * ÓRBITA ESTABLECIDA    : Altitud %.0f km | Inclinación %.1f°\n" % [r["altitude_km"], r["inclination_deg"]]
		+ "  * CIENCIA Y TELEMETRÍA  : %d / %d pts Ciencia | %.1f Mbps | %.1f GB\n" % [
			int(r["total_science"]), int(r["min_science"]), r["effective_bandwidth"], r["collected_data_gb"]
		]
		+ "====================================================================\n"
		+ "FIN DE TRANSMISIÓN — IMPRESO EN PAPEL CONTINUO PERFORADO 132 COLUMNAS"
	)
	receipt_char_progress = 0.0
	lbl_receipt_printer.text = ""

func _process(delta: float) -> void:
	if GameState.current_phase == CatalogData.Phase.DEBRIEF and receipt_char_progress < receipt_full_text.length():
		receipt_char_progress += delta * 260.0
		var chars: int = clampi(int(receipt_char_progress), 0, receipt_full_text.length())
		lbl_receipt_printer.text = receipt_full_text.substr(0, chars)
