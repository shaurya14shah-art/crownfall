extends SceneTree
func _p(n: Node, d: int) -> void:
	var extra := ""
	if n is BoneAttachment3D: extra = " bone=" + (n as BoneAttachment3D).bone_name
	if n is MeshInstance3D: extra += " mesh"
	print("  ".repeat(d) + n.name + " <" + n.get_class() + ">" + extra)
	for c in n.get_children(): _p(c, d + 1)
func _init() -> void:
	var r := (load(OS.get_cmdline_user_args()[0]) as PackedScene).instantiate()
	_p(r, 0)
	r.free()
	quit()
