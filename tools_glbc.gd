extends SceneTree
func _initialize():
	for t in ["hyena", "bulldog", "cat"]:
		var s: Node3D = (load("res://assets/models/enemy_%s.glb" % t) as PackedScene).instantiate()
		root.add_child(s)
		var ap: AnimationPlayer = s.find_children("*", "AnimationPlayer", true, false)[0]
		var info := []
		for a in ap.get_animation_list():
			info.append("%s %.2fs %d" % [a, ap.get_animation(a).length, ap.get_animation(a).get_track_count()])
		var sk: Skeleton3D = s.find_children("*", "Skeleton3D", true, false)[0]
		var aabb := AABB()
		for mi in s.find_children("*", "MeshInstance3D", true, false):
			aabb = (mi as MeshInstance3D).get_aabb()
		print(t, " anims=", info, " bones=", sk.get_bone_count(), " aabb=", aabb)
	quit()
