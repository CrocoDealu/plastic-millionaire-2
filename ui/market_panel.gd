extends PanelContainer

## Centre column: ticker tabs, chart header, chart, sell bar (asks at a set price), the
## "exchange closed" gate and the quotes drawer with open asks and the trade log.

const TRADE_ROW := preload("res://ui/trade_row.tscn")
const ASK_ROW := preload("res://ui/ask_row.tscn")
const KIND := {ask = "Ask filled", bot = "Bot sold"}
const SELL_MODES := {"Sell1": "1", "Sell10": "10", "SellHalf": "half", "SellAll": "all"}



func _ready() -> void:
	%QuotesBtn.pressed.connect(_toggle_quotes)
	%Close.pressed.connect(_toggle_quotes)
	for n: String in SELL_MODES:
		var b: Button = get_node("%" + n)
		b.pressed.connect(_ask.bind(SELL_MODES[n], b))
		Fx.hover_tip(b, "up", _ask_tip.bind(SELL_MODES[n]))
	%AskDown.pressed.connect(func(): Game.ask_step(-1); Sfx.play("tick"))
	%AskUp.pressed.connect(func(): Game.ask_step(1); Sfx.play("tick"))
	%AskFollow.pressed.connect(func(): Game.ask_follow(); Sfx.play("tick"))
	Game.changed.connect(_refresh)
	_refresh()


func _toggle_quotes() -> void:
	Game.set_pref("quotes", not Game.quotes)
	Sfx.play("tick")


func _ask(mode: String, b: Button) -> void:
	var i := Game.sel
	var ok := Game.sell_qty(mode, i) > 0 and Game.orders.size() < Defs.MAX_ORDERS
	if Fx.button_fx(b, ok, "", [Defs.CAUTION, Defs.BOXES[i].color, Color.WHITE]):
		var o := Game.place_ask(mode)
		var r := b.get_global_rect()
		Fx.float_text(Vector2(r.get_center().x, r.position.y - 6.0), "ASK %s @ $%s" % [Defs.fmt(o.q), Defs.px(o.px)], Defs.CAUTION, 12)
		Sfx.play("tick")


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

	%Chip.color = b.color
	%Name.text = b.name.to_upper()
	%Price.text = "$" + Defs.px(m.p)
	%HL.text = "H %s · L %s" % [Defs.px(cs.map(func(c): return c.h).max()), Defs.px(cs.map(func(c): return c.l).min())]
	%QuotesBtn.theme_type_variation = &"BtnGold" if Game.quotes else &"BtnGrey"
	Defs.tint(%QuotesBtn, &"font_color", Defs.GOLD if Game.quotes else Defs.TEXT)
	Defs.tint(%QuotesBtn, &"font_hover_color", Defs.GOLD if Game.quotes else Defs.TEXT)

	# Sell bar
	var book := Game.on_book(i)
	var ap := Game.ask_price(i)
	%Count.text = Defs.fmt(Game.inv[i])
	%Tk.text = b.k
	Defs.tint(%Tk, &"font_color", b.color)
	%Sub.text = "· %s on the book" % Defs.fmt(book) if book else ""
	%AskPx.text = "$" + Defs.px(ap)
	var locked := Game.ask_base[i] > 0.0
	%AskFollow.disabled = not locked
	%AskFollow.theme_type_variation = &"BtnCGold" if locked else &"BtnCGrey"
	for n: String in SELL_MODES:
		var mode: String = SELL_MODES[n]
		var btn: Button = get_node("%" + n)
		var q := Game.sell_qty(mode, i)
		var ok := q > 0
		btn.theme_type_variation = (&"BtnGold" if mode == "all" else &"BtnOrange") if ok else &"BtnGrey"
		var fg := (Defs.GOLD if mode == "all" else Defs.TEXT) if ok else Defs.FAINT
		var sub: Label = btn.get_node("VBox/Sub")
		sub.text = Defs.cash(q * ap) if ok else "—"
		for l: Label in [btn.get_node("VBox/Label"), sub]:
			Defs.tint(l, &"font_color", fg)

	# Quotes drawer
	%Drawer.visible = Game.quotes
	if Game.quotes:
		for q in %Quotes.get_children():
			q.refresh()
		_refresh_asks()
		_refresh_trades()


## Newest first; rows for the selected box are highlighted.
func _refresh_asks() -> void:
	var os := Game.orders.duplicate()
	os.reverse()
	%NoAsks.visible = os.is_empty()
	%AskCols.visible = not os.is_empty()
	%AskSum.text = "%d OPEN · %s" % [os.size(), Defs.cash(os.reduce(func(a, o): return a + o.q * o.px, 0.0))] if os else ""
	var rows := %Asks.get_children().filter(func(c): return c != %NoAsks)
	while rows.size() < os.size():
		var r := ASK_ROW.instantiate()
		%Asks.add_child(r)
		r.get_node("HBox/Cancel").pressed.connect(func():
			Game.cancel_ask(r.get_meta("id"))
			Sfx.play("tick"))
		rows.append(r)
	for k in rows.size():
		var r: Control = rows[k]
		r.visible = k < os.size()
		if not r.visible:
			continue
		var o: Dictionary = os[k]
		var b: Dictionary = Defs.BOXES[o.i]
		var d: float = (o.px / Game.market[o.i].p - 1.0) * 100.0
		r.set_meta("id", o.id)
		r.theme_type_variation = &"QuoteRowSel" if o.i == Game.sel else &"QuoteRow"
		r.get_node("HBox/Tk/Chip").color = b.color
		r.get_node("HBox/Tk/Name").text = b.k
		r.get_node("HBox/Desc").text = "%s @ %s" % [Defs.fmt(o.q), Defs.px(o.px)]
		r.get_node("HBox/Value").text = Defs.cash(o.q * o.px)
		var st: Label = r.get_node("HBox/Status")
		st.text = "FILLING" if d <= 0.0 else "+%.1f%% AWAY" % d
		Defs.tint(st, &"font_color", Defs.UP if d <= Defs.FILL_NEAR else Defs.MUTED)
	%AskScroll.custom_minimum_size.y = clampf(%Asks.get_combined_minimum_size().y, 30.0, 150.0)


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
		Defs.tint(r.get_node("HBox/Tk"), &"font_color", b.color)
		r.get_node("HBox/Desc").text = "%s %s @ $%s" % [KIND.get(t.get("kind"), "Sold"), Defs.fmt(t.q), Defs.px(t.avg)]
		r.get_node("HBox/Total").text = "+" + Defs.cash(t.total)


func _ask_tip(mode: String) -> Array:
	var i := Game.sel
	var b: Dictionary = Defs.BOXES[i]
	var q := Game.sell_qty(mode, i)
	if q == 0:
		return ["ASK " + b.k, [["Not enough %s in the warehouse. Boxes on the book are held back." % b.k, Defs.WARN]]]
	if Game.orders.size() >= Defs.MAX_ORDERS:
		return ["ASK " + b.k, [["The book is full (%d open asks). Cancel one first." % Defs.MAX_ORDERS, Defs.WARN]]]
	var ap := Game.ask_price(i)
	var imp := Game.impact(i, q)
	var d: float = (ap / Game.market[i].p - 1.0) * 100.0
	return ["ASK %s %s @ $%s" % [Defs.fmt(q), b.k, Defs.px(ap)], [
		["Fills for %s once %s trades at $%s or higher." % [Defs.cash(q * ap), b.k, Defs.px(ap)], Defs.GOLD],
		["Last $%s · ask %s" % [Defs.px(Game.market[i].p), Defs.pct(d)]],
		["On fill the price drops %.1f%%." % (imp * 100.0), Defs.WARN if imp > 0.08 else Defs.SOFT],
		["Boxes stay on the book until filled or cancelled."]]]
