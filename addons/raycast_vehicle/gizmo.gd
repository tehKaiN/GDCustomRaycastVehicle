extends EditorNode3DGizmoPlugin


func _has_gizmo(node):
	return node is SuspensionAnimator

func get_name():
	return "CustomNode"

func _get_gizmo_name() -> String:
	return "Suspension Animator"

func _init():
	create_material("main", Color.DARK_MAGENTA, false, true)
	# create_handle_material("handles")
	pass


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()

	var suspension_animator := gizmo.get_node_3d() as SuspensionAnimator
	# var lines := PackedVector3Array()

	# lines.push_back(Vector3(0, 0, 0))
	# lines.push_back(suspension_animator.castTo)
#
	#var handles = PackedVector3Array()
#
	#handles.push_back(Vector3(0, 1, 0))
	#handles.push_back(Vector3(0, 10, 0))
#
	# gizmo.add_lines(lines, get_material("main", gizmo), false)
	#gizmo.add_handles(handles, get_material("handles", gizmo), [])
	var default_material : Material = null
	var main_material := get_material("main", gizmo)

	var mesh := suspension_animator.shape.get_debug_mesh()
	if mesh:
		var equilibrium_transform := Transform3D.IDENTITY.translated(suspension_animator.equilibrium_offset)
		gizmo.add_mesh(mesh, default_material, equilibrium_transform)
		var transform := equilibrium_transform.translated(suspension_animator.castTo)
		gizmo.add_mesh(mesh, main_material, transform)
