extends PanelContainer

## Settings modal: SFX toggle, manual save, and a two-click reset.

signal closed

const ARM_SECONDS := 3.0

var _reset_armed := -10.0
var _saved_flash := -10.0


func _ready() -> void:
	%Close.pressed.connect(closed.emit)
	%Sfx.pressed.connect(func(): Game.set_pref("mute", not Game.mute); Game.save(); Sfx.play("tick"))
	%Save.pressed.connect(func(): Game.save(); _saved_flash = _now(); Sfx.play("tick"))
	%Reset.pressed.connect(_reset)


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _reset() -> void:
	if _now() - _reset_armed > ARM_SECONDS:
		_reset_armed = _now()
		Sfx.play("deny")
		return
	_reset_armed = -10.0
	Game.reset()
	closed.emit()


func _process(_delta: float) -> void:
	if not visible:
		return
	%Sfx.text = "SFX " + ("OFF" if Game.mute else "ON")
	%Sfx.theme_type_variation = &"BtnGrey" if Game.mute else &"BtnGold"
	%Save.text = "SAVED!" if _now() - _saved_flash < 1.2 else "SAVE NOW"
	%SaveDesc.text = ("Last saved %s. " % Defs.clock(Game.saved_at) if Game.saved_at > 0.0 else "") + "Autosaves every 10s and after purchases."
	var armed := _now() - _reset_armed < ARM_SECONDS
	%Reset.text = "SURE?" if armed else "RESET"
	%Reset.theme_type_variation = &"BtnOrange" if armed else &"BtnGrey"
	for s in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
		%Reset.add_theme_color_override(s, Defs.DOWN if armed else Defs.MUTED)
