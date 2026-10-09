class_name Defs
extends RefCounted

## Economy constants and number formatting from the Box Exchange v6 handoff.

const BOXES := [
	{k = "GRY", name = "Grey Box", color = Color("#b9b5aa"), base = 1.0, depth = 300.0},
	{k = "RED", name = "Red Box", color = Color("#e0504a"), base = 6.0, depth = 120.0},
	{k = "AMB", name = "Amber Box", color = Color("#f0a422"), base = 30.0, depth = 50.0},
	{k = "TEA", name = "Teal Box", color = Color("#34b7a2"), base = 220.0, depth = 20.0},
	{k = "VIO", name = "Violet Box", color = Color("#9563de"), base = 1500.0, depth = 8.0},
]
## `inputs` maps box index -> quantity per batch; `out` is a box index.
const GENS := [
	{id = "arm", name = "Press Arm", cost = 12.0, inputs = {}, out = 0, cyc = 2.0},
	{id = "vat", name = "Red Dye Vat", cost = 60.0, inputs = {0: 3}, out = 1, cyc = 3.0},
	{id = "kiln", name = "Amber Kiln", cost = 300.0, inputs = {1: 2, 0: 3}, out = 2, cyc = 5.0},
	{id = "fuse", name = "Teal Fuser", cost = 2500.0, inputs = {2: 3, 1: 4}, out = 3, cyc = 8.0},
	{id = "forge", name = "Violet Forge", cost = 15000.0, inputs = {3: 3, 2: 2}, out = 4, cyc = 12.0},
]
const UPS := [
	{id = "heavy", tier = 0, name = "Heavy Press", cost = 40.0, desc = "+1 grey box per press.", req_t = ""},
	{id = "sweep", tier = 0, name = "Floor Sweeper", cost = 120.0, desc = "Collects every box on the press floor each 1.5s.", req_t = "OWN 1 ARM"},
	{id = "heavy2", tier = 0, name = "Hydraulic Press", cost = 450.0, desc = "+2 more grey boxes per press.", req_t = "HEAVY PRESS"},
	{id = "broker", tier = 1, name = "Broker Bot", cost = 500.0, desc = "Every 5s, sells surplus of any box trading above its average.", req_t = "OWN 1 VAT"},
	{id = "insider", tier = 1, name = "Market Maker", cost = 1500.0, desc = "Halves the price drop caused by your own sales.", req_t = "OWN 5 VATS"},
]
const MILESTONES := [
	["press1", "First press"], ["box1", "Market open"], ["sell1", "First sale"], ["arm", "Press Arm"],
	["auto", "First Auto-In"], ["vat", "Dye Vat · RED"], ["sweep", "Sweeper"], ["kiln", "Kiln · AMB"],
	["broker", "Broker Bot"], ["fuse", "Fuser · TEA"], ["forge", "Forge · VIO"],
]
const MU_MAX := 5
const N_CANDLES := 48

# Design tokens scripts need for state-driven colours; static looks live in ui/theme.tres.
const INK := Color("#06080f")
const BG := Color("#141416")
const CARD := Color("#202023")
const LINE := Color("#3a3a3d")
const DIM_LINE := Color("#2d2d30")
const TEXT := Color("#ece8df")
const SOFT := Color("#bdb8ad")
const MUTED := Color("#9a968c")
const FAINT := Color("#77746c")
const DEAD := Color("#4a4a4d")
const CAUTION := Color("#f5c518")
const ORANGE := Color("#e2702a")
const GOLD := Color("#ffd166")
const GOLD_LABEL := Color("#e8c48a")
const UP := Color("#7bc96f")
const DOWN := Color("#e0504a")
const WARN := Color("#ff9a8a")
const AFFORD_BORDER := Color("#5a4a14")
const LIT_BG := Color("#3a3010")

const _SUF := ["", "K", "M", "B", "T", "Qa", "Qi"]

static func fmt(n: float) -> String:
	var a := absf(n)
	if a < 1000.0:
		return "%.1f" % n if a < 10.0 and fmod(n, 1.0) != 0.0 else str(floori(n))
	var i := 0
	var v := a
	while v >= 1000.0 and i < _SUF.size() - 1:
		v /= 1000.0
		i += 1
	var s := ("%.1f" % v) if v < 100.0 else ("%.0f" % v)
	return ("-" if n < 0.0 else "") + s.trim_suffix(".0") + _SUF[i]

static func cash(n: float) -> String:
	return "$" + ("%.2f" % n if absf(n) < 100.0 else fmt(n))

static func px(p: float) -> String:
	return "%.2f" % p if p < 10.0 else "%.1f" % p if p < 1000.0 else fmt(p)

static func rt(r: float) -> String:
	return "%.2f" % r if absf(r) < 1.0 else "%.1f" % r if absf(r) < 10.0 else fmt(r)

static func pct(v: float, digits := 1) -> String:
	return ("+" if v >= 0.0 else "") + ("%." + str(digits) + "f%%") % v

## Wall-clock HH:MM:SS for a unix timestamp in seconds.
static func clock(t: float) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(t) + _tz_bias())
	return "%02d:%02d:%02d" % [d.hour, d.minute, d.second]

static func mmss(s: float) -> String:
	return "%02d:%02d" % [floori(s / 60.0), floori(fmod(s, 60.0))]

static func _tz_bias() -> int:
	return int(Time.get_time_zone_from_system().bias) * 60
