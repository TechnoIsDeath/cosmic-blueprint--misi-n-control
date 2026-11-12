class_name PickupItem3D
extends RigidBody3D

## Objeto físico 3D que el jugador puede recoger con las manos en 1.ª persona,
## transportar, rotar, lanzar o acoplar en la Mesa Holográfica de Ensamblaje.

enum ItemType {
	SPACECRAFT_PART = 0,
	BATTERY_CELL = 1,
	RCS_TANK = 2,
	VHS_BRIEFING = 3
}

var item_type: int = ItemType.SPACECRAFT_PART
var part_id: String = "solar_std"
var display_name: String = "Módulo Espacial"
var item_subtitle: String = ""
var is_held: bool = false
var label_3d: Label3D

func setup_part(p_id: String) -> void:
	item_type = ItemType.SPACECRAFT_PART
	part_id = p_id
	var data: Dictionary = CatalogData.get_part_by_id(p_id)
	if data.is_empty():
		return
	display_name = String(data["name"])
	item_subtitle = "$%.0fM | %.0f kg | +%dW/-%dW" % [
		data["cost"], data["mass"], int(data["power_gen"]), int(data["power_use"])
	]
	if int(data["science"]) > 0:
		item_subtitle += " | +%d Ciencia" % int(data["science"])
	
	mass = clampf(float(data["mass"]) * 0.02, 1.0, 12.0)
	collision_layer = 4
	collision_mask = 1 | 4
	continuous_cd = true
	var sz: Vector3 = data["size"] * 0.65
	sz.x = clampf(sz.x, 0.35, 1.25)
	sz.y = clampf(sz.y, 0.25, 0.85)
	sz.z = clampf(sz.z, 0.35, 1.05)
	_build_visual_and_collider(sz, data["color"], p_id)

func setup_utility_item(u_type: int, title: String, subtitle: String, col: Color, sz: Vector3) -> void:
	item_type = u_type
	part_id = ""
	display_name = title
	item_subtitle = subtitle
	mass = 2.5
	collision_layer = 4
	collision_mask = 1 | 4
	continuous_cd = true
	var model_name: String = ""
	if u_type == ItemType.BATTERY_CELL:
		model_name = "battery_cell"
	elif u_type == ItemType.RCS_TANK:
		model_name = "rcs_tank"
	elif u_type == ItemType.VHS_BRIEFING:
		model_name = "vhs_tape"
	_build_visual_and_collider(sz, col, model_name)

func _build_visual_and_collider(sz: Vector3, col: Color, prop_name: String = "") -> void:
	for c in get_children():
		c.queue_free()

	var final_sz: Vector3 = sz
	var model_node: Node3D = PropModelLoader.instantiate_prop(prop_name)
	if model_node != null:
		var aabb: AABB = PropModelLoader.get_combined_aabb(model_node)
		var max_dim: float = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
		var scale_factor: float = 1.0
		if max_dim > 1.05:
			scale_factor = 1.05 / max_dim
		elif max_dim > 0.01 and max_dim < 0.32:
			scale_factor = 0.36 / max_dim
		model_node.scale = Vector3.ONE * scale_factor
		var scaled_aabb := AABB(aabb.position * scale_factor, aabb.size * scale_factor)
		var center: Vector3 = scaled_aabb.position + scaled_aabb.size * 0.5
		model_node.position = -center
		add_child(model_node)
		final_sz = Vector3(
			max(scaled_aabb.size.x, 0.24),
			max(scaled_aabb.size.y, 0.18),
			max(scaled_aabb.size.z, 0.24)
		)
	else:
		# Respaldo procedural
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sz
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.roughness = 0.45
		mat.metallic = 0.35
		mi.material_override = mat
		add_child(mi)

	var col_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = final_sz
	col_shape.shape = box_shape
	add_child(col_shape)

	label_3d = Label3D.new()
	label_3d.text = "%s\n[%s]" % [display_name, item_subtitle]
	label_3d.font_size = 20
	label_3d.outline_size = 6
	label_3d.modulate = Color(0.85, 1.0, 0.95)
	label_3d.position = Vector3(0.0, final_sz.y * 0.5 + 0.26, 0.0)
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label_3d)

func get_prompt_text() -> String:
	if item_type == ItemType.SPACECRAFT_PART:
		return "[E / Clic Izq] Recoger %s (%s)" % [display_name, item_subtitle]
	return "[E / Clic Izq] Recoger %s — %s" % [display_name, item_subtitle]
