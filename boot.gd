extends Control

## Loading screen: threads in main.tscn while the press bears down on a blank in step with the
## bar; the blank pops just before 100%, the head lifts, then the game takes over.

const MAIN := "res://main.tscn"
const MIN_TIME := 2.0  # ponytail: the real load is near-instant; the bar never runs faster than this
const POP := 0.92  # progress at which the blank pops
const DIE_TOP := 178.0
const DIE_W := 150.0
const BLANK := Vector2(40, 36)
const THUD_SLOW := 0.35  # seconds between thuds at the start of the press
const THUD_FAST := 0.06  # ... and just before the pop

var _t := 0.0
var _next_thud := 0.0
var _popped := false


func _ready() -> void:
	var cols := PackedColorArray(Defs.BOXES.map(func(b): return b.color))
	%Blank.material.set_shader_parameter(&"n", cols.size())
	%Blank.material.set_shader_parameter(&"cols", cols)
	ResourceLoader.load_threaded_request(MAIN)


func _process(delta: float) -> void:
	_t += delta
	var real := []
	var status := ResourceLoader.load_threaded_get_status(MAIN, real)
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		get_tree().change_scene_to_file(MAIN)  # surfaces the real load error
		return
	var p := minf(real[0], _t / MIN_TIME)
	%Bar.value = p
	if p >= 1.0 and status == ResourceLoader.THREAD_LOAD_LOADED:
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(MAIN))
		return
	# Head slams down over 0..POP squashing the blank, then lifts back up off the empty die.
	var f := ease(p / POP, 2.0) if p < POP else 1.0 - (p - POP) / (1.0 - POP)
	var head_top := roundf(118.0 + 32.0 * f)
	%Head.position.y = head_top
	%Rod.size.y = head_top - 64.0
	if p >= POP and not _popped:
		_pop()
	elif not _popped and _t >= _next_thud:  # thuds speed up and climb in pitch, like a building combo
		Sfx.play("press", int(20.0 * p / POP))
		_next_thud = _t + lerpf(THUD_SLOW, THUD_FAST, p / POP)
	if not _popped:
		var bh := roundf(minf(BLANK.y, DIE_TOP - head_top - 24.0))
		var bw := minf(DIE_W, roundf(BLANK.x * BLANK.y / bh))
		%Blank.size = Vector2(bw, bh)
		%Blank.position = Vector2(roundf(%Press.size.x / 2.0 - bw / 2.0), DIE_TOP - bh)


func _pop() -> void:
	_popped = true
	%Blank.visible = false
	var c: Vector2 = %Press.global_position + Vector2(%Press.size.x / 2.0, DIE_TOP - 4.0)
	Fx.burst(c, 24, Defs.BOXES.map(func(b): return b.color), 260.0, 700.0)
	Fx.quake(%Press, 7.0)
	Sfx.play("press", 20)
