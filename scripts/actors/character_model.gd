class_name CharacterModel
extends Node3D
## A KayKit character (adventurer or skeleton) with its animations: loads
## the model, marks the cycles as looping, chooses which held items show,
## and plays clips with a cross-fade. Shared by the player, villagers and
## enemies.

const LOOPS := ["Idle", "Walking_A", "Walking_B", "Walking_C", "Walking_Backwards", "Running_A", "Running_B",
	"Running_Strafe_Left", "Running_Strafe_Right", "Blocking", "2H_Melee_Idle", "Unarmed_Idle", "Jump_Idle",
	"Sit_Chair_Idle", "Sit_Floor_Idle", "Lie_Idle", "Spellcasting", "1H_Ranged_Aiming", "Cheer",
	"Skeletons_Idle", "Skeletons_Walking", "Skeletons_Awaken_Standing"]

var anim: AnimationPlayer
var skeleton: Skeleton3D
var current := ""
var _model: Node3D

## `path` a .glb; `keep` the names of held items to leave visible (all
## other meshes under a hand slot are hidden).
func setup(path: String, keep: Array = [], scale_to: float = 0.85) -> void:
	_model = (load(path) as PackedScene).instantiate() as Node3D
	_model.scale = Vector3.ONE * scale_to
	add_child(_model)
	anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	for slot in _model.find_children("handslot*", "BoneAttachment3D", true, false):
		for item in slot.get_children():
			(item as Node3D).visible = item.name in keep
	if anim != null:
		for lib_name in anim.get_animation_library_list():
			var lib := anim.get_animation_library(lib_name)
			for n in lib.get_animation_list():
				if n in LOOPS or n.ends_with("Idle") or n.begins_with("Walking") or n.begins_with("Running"):
					lib.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func has(clip: String) -> bool:
	return anim != null and anim.has_animation(clip)

## Plays `clip` blending over `fade` seconds. Restarting the same looping clip
## is a no-op; `restart` forces one-shots to play again from the start.
func play(clip: String, fade: float = 0.18, speed: float = 1.0, restart: bool = false) -> void:
	if anim == null or not anim.has_animation(clip):
		return
	if clip == current and not restart:
		anim.speed_scale = speed
		return
	current = clip
	anim.play(clip, fade, 1.0)
	anim.speed_scale = speed
	if restart:
		anim.seek(0.0, true)

func length_of(clip: String) -> float:
	return anim.get_animation(clip).length if has(clip) else 0.0

func playing_one_shot() -> bool:
	return anim != null and anim.is_playing() and anim.current_animation != "" \
		and anim.get_animation(anim.current_animation).loop_mode == Animation.LOOP_NONE

func bone_global(bone: String) -> Vector3:
	if skeleton == null:
		return global_position
	var i := skeleton.find_bone(bone)
	if i < 0:
		return global_position
	return skeleton.global_transform * skeleton.get_bone_global_pose(i).origin
