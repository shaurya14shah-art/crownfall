class_name Arts
extends Node
## The Knight's Arts: four plain, trained techniques on Z X V B, learned at
## the root of the four combat trees before anything grander. Whirlwind is
## known from the start. No Law is involved — just practice.

const ALL := {
	"whirlwind": {"key": "art_1", "label": "Z", "name": "Whirlwind", "cd": 6.0, "stamina": 18.0, "glyph": "sword"},
	"shield_bash": {"key": "art_2", "label": "X", "name": "Shield Bash", "cd": 4.0, "stamina": 10.0, "glyph": "shield"},
	"charge": {"key": "art_3", "label": "V", "name": "Charge", "cd": 7.0, "stamina": 14.0, "glyph": "boot"},
	"battle_cry": {"key": "art_4", "label": "B", "name": "Battle Cry", "cd": 22.0, "stamina": 0.0, "glyph": "heart"},
}
const ORDER := ["whirlwind", "shield_bash", "charge", "battle_cry"]

var player: Player
var cooldown := {}
var rally_t := 0.0             ## Battle Cry's strength, seconds left

func _process(delta: float) -> void:
	for k in cooldown.keys():
		cooldown[k] = maxf(0.0, float(cooldown[k]) - delta)
	rally_t = maxf(0.0, rally_t - delta)
	if not Game.playing or player.state in [Player.S.DEAD, Player.S.SWIM, Player.S.CLIMB] or player.helm != null:
		return
	for id in ORDER:
		if Input.is_action_just_pressed(str(ALL[id]["key"])):
			use(id)

static func known(id: String) -> bool:
	return Run.unlocked.has(id)

func ready_fraction(id: String) -> float:
	return 1.0 - float(cooldown.get(id, 0.0)) / float(ALL[id]["cd"])

func use(id: String) -> void:
	if not known(id):
		Run.toast.emit("Learn %s in the Skills tree" % ALL[id]["name"], "warn")
		return
	if float(cooldown.get(id, 0.0)) > 0.0 or player.state in [Player.S.ROLL, Player.S.HIT, Player.S.ART]:
		return
	var cost := float(ALL[id]["stamina"])
	if player.stamina < cost:
		return
	player.stamina -= cost
	cooldown[id] = float(ALL[id]["cd"])
	Run.record("art")
	match id:
		"whirlwind": _whirlwind()
		"shield_bash": _bash()
		"charge": _charge()
		"battle_cry": _cry()

func _foes(reach: float) -> Array:
	var out := []
	for e in player.get_tree().get_nodes_in_group("enemies"):
		var n := e as Node3D
		if n == null or (n.has_method("is_dead") and bool(n.call("is_dead"))):
			continue
		if n.global_position.distance_to(player.global_position) < reach:
			out.append(n)
	return out

func _weapon_damage() -> float:
	return float(player.weapon().get("damage", 20.0)) * (1.0 + Run.perk("damage")) * (1.25 if rally_t > 0.0 else 1.0)

func _ring(col: Color, r: float) -> void:
	var ring := LawRing.new()
	ring.colour = col
	ring.radius = r
	ring.life = 0.45
	ring.expanding = true
	player.get_parent().add_child(ring)
	ring.global_position = player.global_position + Vector3.UP * 0.15

func _whirlwind() -> void:
	player.play_art("2H_Melee_Attack_Spin", 1.6, 0.55)
	Audio.play("swing", player.global_position, 0.0, 0.8)
	await player.get_tree().create_timer(0.18).timeout
	_ring(Color(1.0, 0.85, 0.5), 2.0)
	var hit := false
	for n in _foes(3.4):
		n.call("take_hit", _weapon_damage() * 1.3, player)
		if n.has_method("knock"):
			n.call("knock", (n.global_position - player.global_position).normalized() * 7.0)
		hit = true
	if hit:
		Fx.hit_stop(0.08)
		player.rig.shake(0.5)
		Run.gain("blade", 8.0)

func _bash() -> void:
	var has_shield := not player.shield().is_empty()
	player.play_art("Block_Attack" if has_shield else "Unarmed_Melee_Attack_Kick", 1.4, 0.45)
	var foe := player.nearest_enemy(4.0)
	if foe != null:
		var to := (foe.global_position - player.global_position) * Vector3(1, 0, 1)
		player.model.rotation.y = atan2(to.x, to.z)
	await player.get_tree().create_timer(0.15).timeout
	var fwd := player.model.global_basis.z
	for n in _foes(2.9):
		if fwd.dot((n.global_position - player.global_position).normalized()) > 0.3:
			n.call("take_hit", 10.0 + _weapon_damage() * 0.4, player, 45.0)
			if n.has_method("stagger") and not bool(n.call("is_boss")):
				n.call("stagger")
			if n.has_method("knock"):
				n.call("knock", fwd * 9.0)
			Fx.sparks(player.get_parent(), n.global_position + Vector3.UP, Color(0.95, 0.95, 1.0), 20)
			Audio.play("block", n.global_position, 2.0, 0.8)
			Run.gain("guard", 6.0)

func _charge() -> void:
	var dir := Vector3(player.velocity.x, 0, player.velocity.z)
	var foe := player.nearest_enemy(12.0)
	if foe != null:
		dir = (foe.global_position - player.global_position) * Vector3(1, 0, 1)
	if dir.length() < 0.1:
		dir = player.model.global_basis.z
	dir = dir.normalized()
	player.model.rotation.y = atan2(dir.x, dir.z)
	player.velocity = dir * 22.0
	player.dash(0.36)
	Audio.play("roll", player.global_position, 0.0, 0.7)
	_ring(Color(0.9, 0.95, 1.0), 1.5)
	var from := player.global_position
	await player.get_tree().create_timer(0.3).timeout
	for n in _foes(12.0):
		var rel: Vector3 = n.global_position - from
		var along := rel.dot(dir)
		var off := (rel - dir * along).length()
		if along > 0.0 and along < 9.0 and off < 2.2:
			n.call("take_hit", 14.0 + _weapon_damage() * 0.3, player, 30.0)
			if n.has_method("knock"):
				var side := Vector3(-dir.z, 0, dir.x) * signf(rel.dot(Vector3(-dir.z, 0, dir.x)) + 0.001)
				n.call("knock", (side * 0.8 + dir * 0.6).normalized() * 11.0)
			Run.gain("agility", 4.0)
	# Plant the feet when the dash ends, rather than skidding on.
	await player.get_tree().create_timer(0.07).timeout
	player.velocity.x *= 0.2
	player.velocity.z *= 0.2

func _cry() -> void:
	player.play_art("Cheer", 1.3, 0.8)
	rally_t = 8.0
	player.powers._heal_over(35.0, 4.0)
	_ring(Color(1.0, 0.75, 0.35), 4.0)
	Audio.play("heal", player.global_position, 2.0, 0.85)
	Run.gain("vitality", 6.0)
