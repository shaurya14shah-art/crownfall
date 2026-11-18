class_name LoadingScreen
extends Control
## While the island is built: the title, a hairline gold bar that fills,
## what is being made, and a line of lore. Fades away when done.

const LORE := [
	"Aldermere was the last island to keep its crown when the Realms broke apart.",
	"Brightwater's fishermen say the sea remembers every ship it has taken.",
	"The Barrow of Ash was sealed by the old kings. The seal has not held.",
	"Highmoor Keep has stood empty since the night the bells rang on their own.",
]

var _bar: Control
var _status: Label
var _progress := 0.0
var _shown := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.025, 0.03, 0.045)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var centre := VBoxContainer.new()
	centre.set_anchors_preset(Control.PRESET_CENTER)
	centre.position = Vector2(-300, -110)
	centre.custom_minimum_size = Vector2(600, 0)
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_theme_constant_override("separation", 12)
	add_child(centre)
	var t := UIStyle.title("CROWNFALL", 64, UIStyle.IVORY, 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre.add_child(t)
	var rule := UIStyle.rule(420)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	centre.add_child(rule)
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(600, 30)
	_bar.draw.connect(_draw_bar)
	centre.add_child(_bar)
	_status = UIStyle.text("", 14, UIStyle.IVORY_DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre.add_child(_status)
	var lore := UIStyle.text(LORE[randi() % LORE.size()], 15, Color(UIStyle.IVORY, 0.55))
	lore.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	lore.position = Vector2(-450, -90)
	lore.custom_minimum_size = Vector2(900, 0)
	lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(lore)

func report(fraction: float, text: String) -> void:
	_progress = fraction
	_status.text = text.to_upper() + "…" if fraction < 1.0 else ""

func _process(delta: float) -> void:
	_shown = move_toward(_shown, _progress, delta * 1.5)
	_bar.queue_redraw()

func _draw_bar() -> void:
	var w := _bar.size.x
	var y := _bar.size.y * 0.5
	_bar.draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, 0.1), 2.0)
	_bar.draw_line(Vector2(0, y), Vector2(w * _shown, y), UIStyle.GOLD, 2.0)
	_bar.draw_circle(Vector2(w * _shown, y), 3.5, UIStyle.GOLD_BRIGHT, true, -1.0, true)

func finish() -> void:
	_progress = 1.0
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.tween_callback(queue_free)
