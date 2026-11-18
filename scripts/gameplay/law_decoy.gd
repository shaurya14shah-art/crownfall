class_name LawDecoy
extends Node3D
## False Image: a pale copy of the knight that the risen turn on for a few
## seconds, then it breaks like glass.

var colour := Color.WHITE
var life := 5.0
var _t := 0.0
var _model: CharacterModel

func _ready() -> void:
	add_to_group("decoys")
	_model = CharacterModel.new()
	_model.setup("res://assets/characters/Knight.glb", ["1H_Sword"])
	add_child(_model)
	_model.play("Blocking")
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(colour, 0.45)
		(mi as MeshInstance3D).material_override = m
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		Fx.sparks(get_parent(), global_position + Vector3.UP, colour, 30)
		queue_free()
