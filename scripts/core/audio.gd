extends Node
## Audio: named one-shot sounds at a point in the world (or flat, for the
## interface), drawn from the Kenney packs, each with a little pitch
## variation so repeats never sound mechanical. A small pool of players is
## reused rather than nodes created per sound.

const SFX := "res://assets/audio/sfx/"
const UI := "res://assets/audio/ui/"
const BANK := {
	"swing": ["knifeSlice", "knifeSlice2", "drawKnife1"],
	"hit": ["chop", "metalPot1", "metalPot2"],
	"block": ["metalClick", "metalLatch", "metalPot3"],
	"hurt": ["cloth3", "cloth4", "dropLeather"],
	"roll": ["cloth1", "cloth2", "clothBelt"],
	"heal": ["bookFlip2", "handleSmallLeather"],
	"coin": ["handleCoins", "handleCoins2"],
	"door": ["doorOpen_1", "doorOpen_2"],
	"step": ["footstep00", "footstep01", "footstep02", "footstep03", "footstep04", "footstep05", "footstep06",
		"footstep07", "footstep08", "footstep09"],
	"bones": ["creak1", "creak2", "creak3"],
}
const UI_BANK := {
	"hover": ["tick_001", "tick_002"],
	"click": ["click_002", "click_003"],
	"open": ["open_001", "open_002"],
	"close": ["close_001", "close_002"],
	"confirm": ["confirmation_001", "confirmation_002"],
	"back": ["back_001", "back_002"],
}

var _streams := {}
var _pool: Array[AudioStreamPlayer3D] = []
var _flat: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 24:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 6.0
		p.max_distance = 60.0
		p.attenuation_filter_cutoff_hz = 9000.0
		add_child(p)
		_pool.append(p)
	for i in 6:
		var f := AudioStreamPlayer.new()
		add_child(f)
		_flat.append(f)

func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path)
	return _streams[path]

func play(name: String, at: Vector3, db: float = 0.0, pitch: float = 1.0) -> void:
	if not BANK.has(name):
		return
	var list: Array = BANK[name]
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _stream(SFX + str(list[randi() % list.size()]) + ".ogg")
	p.global_position = at
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(0.93, 1.07)
	p.play()

func footstep(at: Vector3) -> void:
	play("step", at, -14.0, 1.0)

func ui(name: String, db: float = -6.0) -> void:
	if not UI_BANK.has(name):
		return
	var list: Array = UI_BANK[name]
	for f in _flat:
		if not f.playing:
			f.stream = _stream(UI + str(list[randi() % list.size()]) + ".ogg")
			f.volume_db = db
			f.pitch_scale = randf_range(0.97, 1.03)
			f.play()
			return
