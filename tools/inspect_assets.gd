extends SceneTree
## Prints what the imported art contains: bounding boxes of models, the
## animations and bones of characters. Headless:
##   Godot --headless --path . --script tools/inspect_assets.gd -- <res://dir> [anim]

func _aabb(n: Node, xf: Transform3D, box: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var b: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		if box[0] == null:
			box[0] = b
		else:
			box[0] = (box[0] as AABB).merge(b)
	for c in n.get_children():
		_aabb(c, t, box)

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := str(args[0])
	var anim := args.size() > 1
	for f in DirAccess.get_files_at(dir):
		if not (f.ends_with(".gltf") or f.ends_with(".glb")):
			continue
		var ps := load(dir + "/" + f) as PackedScene
		if ps == null:
			continue
		var root := ps.instantiate()
		var box := [null]
		_aabb(root, Transform3D.IDENTITY, box)
		var b: AABB = box[0] if box[0] != null else AABB()
		print("%-40s pos %s size %s" % [f, b.position.snapped(Vector3.ONE * 0.01), b.size.snapped(Vector3.ONE * 0.01)])
		if anim:
			for ap in root.find_children("*", "AnimationPlayer", true, false):
				var names := (ap as AnimationPlayer).get_animation_list()
				print("   anims (%d): %s" % [names.size(), ", ".join(names)])
			for sk in root.find_children("*", "Skeleton3D", true, false):
				var s := sk as Skeleton3D
				var bones: Array[String] = []
				for i in s.get_bone_count():
					bones.append(s.get_bone_name(i))
				print("   bones: %s" % ", ".join(bones))
		root.free()
	quit()
