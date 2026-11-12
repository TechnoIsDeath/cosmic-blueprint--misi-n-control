class_name PropModelLoader
extends RefCounted

## Cargador con caché para los modelos 3D exportados desde Blender (res://assets/models/props/*.glb).

static var _cache: Dictionary = {}

static func clear_cache() -> void:
	for k in _cache.keys():
		var n := _cache[k] as Node
		if is_instance_valid(n):
			n.free()
	_cache.clear()

static func instantiate_prop(prop_name: String) -> Node3D:
	if prop_name.is_empty():
		return null

	if _cache.has(prop_name):
		var cached_node := _cache[prop_name] as Node3D
		if is_instance_valid(cached_node):
			return cached_node.duplicate() as Node3D

	var res_path: String = "res://assets/models/props/%s.glb" % prop_name
	var template: Node3D = null

	if ResourceLoader.exists(res_path):
		var packed := load(res_path) as PackedScene
		if packed:
			template = packed.instantiate() as Node3D

	if template == null:
		var abs_path: String = ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_path):
			var doc := GLTFDocument.new()
			var state := GLTFState.new()
			if doc.append_from_file(abs_path, state) == OK:
				template = doc.generate_scene(state) as Node3D

	if template != null:
		_cache[prop_name] = template
		return template.duplicate() as Node3D

	return null

static func get_combined_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var has_first: bool = false
	for child in root.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var aabb: AABB = mi.transform * mi.get_aabb()
			if not has_first:
				result = aabb
				has_first = true
			else:
				result = result.merge(aabb)
		elif child is Node3D:
			var sub_aabb: AABB = get_combined_aabb(child as Node3D)
			if sub_aabb.size != Vector3.ZERO:
				var xform_aabb: AABB = (child as Node3D).transform * sub_aabb
				if not has_first:
					result = xform_aabb
					has_first = true
				else:
					result = result.merge(xform_aabb)
	return result
