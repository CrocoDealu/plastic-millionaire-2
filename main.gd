extends Control

## Box Exchange root: header money counter, warehouse summary, modals and the scrolling
## background. Panels are self-contained scenes that bind to the Game autoload themselves.

@export var scanlines := true

const GRID_SPEED := 8.0
const MONEY_LERP := 12.0

var _shown := 0.0


func _ready() -> void:
	%Scanlines.visible = scanlines
	_shown = Game.money
	%Settings.pressed.connect(open_settings)
	%SellSurplus.pressed.connect(_sell_surplus)
	%Modals.gui_input.connect(_on_backdrop_input)
	%MachinesPanel.open_machine.connect(open_machine)
	%MachineModal.closed.connect(close_modal)
	%SettingsModal.closed.connect(close_modal)
	Game.changed.connect(_refresh)
	Game.sold.connect(_on_sold)
	Game.toast.connect(_on_toast)
	_refresh()


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0 * GRID_SPEED
	%Grid.position = Vector2(fmod(t, 400.0) - 400.0, fmod(t, 300.0) - 300.0).round()
	_shown += (Game.money - _shown) * minf(1.0, delta * MONEY_LERP)
	if absf(Game.money - _shown) < 0.01:
		_shown = Game.money
	%Value.text = Defs.cash(_shown)


func _refresh() -> void:
	%WhValue.text = Defs.cash(Game.warehouse_value())
	%SellSurplus.theme_type_variation = &"BtnCGold" if Game.sell_value() > 0.0 else &"BtnCGrey"


func _sell_surplus() -> void:
	if Fx.button_fx(%SellSurplus, Game.sell_value() > 0.0, "", [Defs.GOLD, Defs.CAUTION, Color("#fff3c4")]):
		Game.sell_surplus()
		Sfx.play("sell")


func _on_sold(_i: int, _q: int, total: float, auto: bool) -> void:
	var m: Control = %Money
	m.pivot_offset = Vector2(m.size.x, m.size.y / 2.0)
	m.scale = Vector2(1.08, 1.08)
	m.create_tween().tween_property(m, "scale", Vector2.ONE, 0.2)
	var r := m.get_global_rect()
	Fx.float_text(Vector2(r.get_center().x, r.end.y + 4.0), "+" + Defs.cash(total), Defs.GOLD, 12 if auto else 16)
	Fx.burst(Vector2(r.end.x - 40.0, r.get_center().y), 4 if auto else 10, [Defs.GOLD, Defs.CAUTION, Color("#fff3c4")], 160.0, 400.0)


func _on_toast(title: String, sub: String, chime: bool) -> void:
	Fx.toast(title, sub)
	if chime:
		Sfx.play("unlock")


func open_machine(i: int) -> void:
	Fx.tip_off()
	%SettingsModal.visible = false
	%MachineModal.open(i)
	%Modals.visible = true
	Sfx.play("tick")


func open_settings() -> void:
	Fx.tip_off()
	%MachineModal.visible = false
	%SettingsModal.visible = true
	%Modals.visible = true
	Sfx.play("tick")


func close_modal() -> void:
	%Modals.visible = false
	%MachineModal.visible = false
	%SettingsModal.visible = false


func _on_backdrop_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		close_modal()
