extends PanelContainer

## Centre column: ticker tabs, chart header, chart, sell bar, the "exchange closed" gate and
## the quotes drawer with the trade log.

const TRADE_ROW := preload("res://ui/trade_row.tscn")
const SELL_MODES := {"Sell1": "1", "Sell10": "10", "SellHalf": "half", "SellAll": "all"}

@export var check_on: StyleBox
@export var check_off: StyleBox


func _ready() -> void:
	%Candles.pressed.connect(func(): Game.set_pref("chart", "candles"); Sfx.play("tick"))
	%Line.pressed.connect(func(): Game.set_pref("chart", "line"); Sfx.play("tick"))
	%QuotesBtn.pressed.connect(_toggle_quotes)
	%Close.pressed.connect(_toggle_quotes)
	%Reserve.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Game.set_pref("reserve", not Game.reserve))
	for n: String in SELL_MODES:
		var b: Button = get_node("%" + n)
		b.pressed.connect(_sell.bind(SELL_MODES[n], b))
		Fx.hover_tip(b, "up", _sell_tip.bind(SELL_MODES[n]))
	Game.changed.connect(_refresh)
	_refresh()


func _toggle_quotes() -> void:
	Game.set_pref("quotes", not Game.quotes)
	Sfx.play("tick")


func _sell(mode: String, b: Button) -> void:
	var i := Game.sel
	if Fx.button_fx(b, Game.sell_qty(mode, i) > 0, "", [Defs.GOLD, Defs.BOXES[i].color, Color.WHITE]):
		Game.sell(mode)
		Sfx.play("sell")


func _process(_delta: float) -> void:
	if %Drawer.visible:
		%Live.modulate.a = 1.0 if fmod(Time.get_ticks_msec() / 1000.0, 1.4) < 0.7 else 0.55
		%Clock.text = Defs.clock(Game.now())


func _refresh() -> void:
	%Closed.visible = not Game.market_open()
	var i := Game.sel
	var b: Dictionary = Defs.BOXES[i]
	var m: Dictionary = Game.market[i]
	var cs := Game.window(i)
	var chg := Game.change_pct(i)
	var chg_c := Defs.UP if chg >= 0.0 else Defs.DOWN

	%Chip.color = b.color
	%Name.text = "%s · %dS CANDLES" % [b.name.to_upper(), int(Game.CANDLE_S)]
	%Price.text = "$" + Defs.px(m.p)
	%Chg.text = Defs.pct(chg, 2)
	%Chg.add_theme_color_override(&"font_color", chg_c)
	%HL.text = "H %s · L %s" % [Defs.px(cs.map(func(c): return c.h).max()), Defs.px(cs.map(func(c): return c.l).min())]
	%Candles.theme_type_variation = &"BtnCGold" if Game.chart == "candles" else &"BtnCGrey"
	%Line.theme_type_variation = &"BtnCGold" if Game.chart == "line" else &"BtnCGrey"
	%QuotesBtn.theme_type_variation = &"BtnGold" if Game.quotes else &"BtnGrey"
	%QuotesBtn.add_theme_color_override(&"font_color", Defs.GOLD if Game.quotes else Defs.TEXT)
	%QuotesBtn.add_theme_color_override(&"font_hover_color", Defs.GOLD if Game.quotes else Defs.TEXT)

	# Sell bar
	var res := Game.reserve_of(i)
	var sellable := Game.sellable(i)
	%Count.text = Defs.fmt(Game.inv[i])
	%Tk.text = b.k
	%Tk.add_theme_color_override(&"font_color", b.color)
	%Sub.text = "%s%s sellable ≈ %s" % ["%s kept for machines · " % Defs.fmt(res) if res and Game.reserve else "",
		Defs.fmt(sellable), Defs.cash(Game.sell_quote(i, sellable).total)]
	%Check.add_theme_stylebox_override(&"panel", check_on if Game.reserve else check_off)
	%ResLabel.add_theme_color_override(&"font_color", Defs.CAUTION if Game.reserve else Defs.FAINT)
	for n: String in SELL_MODES:
		var mode: String = SELL_MODES[n]
		var btn: Button = get_node("%" + n)
		btn.visible = mode == "1" or mode == "all" or sellable >= 10
		var q := Game.sell_qty(mode, i)
		var ok := q > 0
		btn.theme_type_variation = (&"BtnGold" if mode == "all" else &"BtnOrange") if ok else &"BtnGrey"
		var fg := (Defs.GOLD if mode == "all" else Defs.TEXT) if ok else Defs.FAINT
		var sub: Label = btn.get_node("VBox/Sub")
		sub.text = Defs.cash(Game.sell_quote(i, q).total) if ok else "—"
		for l: Label in [btn.get_node("VBox/Label"), sub]:
			l.add_theme_color_override(&"font_color", fg)

	# Quotes drawer
	%Drawer.visible = Game.quotes
	if Game.quotes:
		for q in %Quotes.get_children():
			q.refresh()
		_refresh_trades()


func _refresh_trades() -> void:
	%NoTrades.visible = Game.trades.is_empty()
	%Earned.text = "%s EARNED" % Defs.cash(Game.total_earned) if Game.total_earned > 0.0 else ""
	var rows := %Trades.get_children().filter(func(c): return c != %NoTrades)
	while rows.size() < Game.trades.size():
		var r := TRADE_ROW.instantiate()
		%Trades.add_child(r)
		rows.append(r)
	for k in rows.size():
		var r: Control = rows[k]
		r.visible = k < Game.trades.size()
		if not r.visible:
			continue
		var t: Dictionary = Game.trades[k]
		var b: Dictionary = Defs.BOXES[t.i]
		r.get_node("HBox/Time").text = Defs.clock(t.t)
		r.get_node("HBox/Tk").text = b.k
		r.get_node("HBox/Tk").add_theme_color_override(&"font_color", b.color)
		r.get_node("HBox/Desc").text = "%s %s @ $%s" % ["Bot sold" if t.auto else "Sold", Defs.fmt(t.q), Defs.px(t.avg)]
		r.get_node("HBox/Total").text = "+" + Defs.cash(t.total)


func _sell_tip(mode: String) -> Array:
	var i := Game.sel
	var b: Dictionary = Defs.BOXES[i]
	var q := Game.sell_qty(mode, i)
	if q == 0:
		return ["SELL " + b.k, [["Nothing sellable. Machine reserve is kept back.", Defs.WARN]]]
	var quote := Game.sell_quote(i, q)
	return ["SELL %s %s" % [Defs.fmt(q), b.k], [
		["Avg fill $%s · total %s" % [Defs.px(quote.avg), Defs.cash(quote.total)], Defs.GOLD],
		["Price impact −%.1f%%" % (quote.imp * 100.0), Defs.WARN if quote.imp > 0.08 else Defs.SOFT],
		["Price recovers toward fair value over ~15s."]]]
