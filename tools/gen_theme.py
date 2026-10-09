"""Generates ui/theme.tres (sprite 9-slice buttons/panels + flat card styles from the v6 tokens).
Re-run after changing tokens: python3 tools/gen_theme.py"""

ext, subs, props = [], [], []

def ext_res(kind, path):
    rid = f"{len(ext)+1}"
    ext.append(f'[ext_resource type="{kind}" path="res://{path}" id="{rid}"]')
    return rid

def sub(kind, body):
    sid = f"{kind}_{len(subs)+1}"
    subs.append(f'[sub_resource type="{kind}" id="{sid}"]\n' + "\n".join(f"{k} = {v}" for k, v in body.items()))
    return f'SubResource("{sid}")'

def col(h, a=1.0):
    h = h.lstrip("#")
    r, g, b = (int(h[i:i+2], 16) / 255 for i in (0, 2, 4))
    return f"Color({r:.4f}, {g:.4f}, {b:.4f}, {a})"

def margins(prefix, l, t=None, r=None, b=None):
    t = l if t is None else t; r = l if r is None else r; b = t if b is None else b
    return {f"{prefix}_left": float(l), f"{prefix}_top": float(t), f"{prefix}_right": float(r), f"{prefix}_bottom": float(b)}

def tex_box(tex, slice_px, content, mod=None):
    body = {"texture": f'ExtResource("{tex}")', **margins("texture_margin", slice_px), **margins("content_margin", *content)}
    if mod: body["modulate_color"] = f"Color({mod}, {mod}, {mod}, 1)"
    return sub("StyleBoxTexture", body)

def flat(bg, border=None, bw=0, radius=0, content=(0,), bg_a=1.0, extra=None):
    body = {"bg_color": col(bg, bg_a), **margins("content_margin", *content)}
    if border:
        body.update({"border_width_left": bw, "border_width_top": bw, "border_width_right": bw, "border_width_bottom": bw, "border_color": col(border)})
    if radius:
        body.update({"corner_radius_top_left": radius, "corner_radius_top_right": radius, "corner_radius_bottom_right": radius, "corner_radius_bottom_left": radius})
    body.update(extra or {})
    return sub("StyleBoxFlat", body)

def p(t, k, v): props.append(f"{t}/{k} = {v}")

pix = f'ExtResource("{ext_res("FontFile", "assets/fonts/PixelifySans.ttf")}")'
# Regular Silkscreen reads too thin at the 1.5x stretch; embolden it a bit (no layout change).
silk = sub("FontVariation", {"base_font": f'ExtResource("{ext_res("FontFile", "assets/fonts/Silkscreen-Regular.ttf")}")', "variation_embolden": 0.5})
silkb = f'ExtResource("{ext_res("FontFile", "assets/fonts/Silkscreen-Bold.ttf")}")'
T = {k: ext_res("Texture2D", f"assets/ui/x3/{k}.png") for k in [
    "buttons_Blue_ButtonA_Unpressed", "buttons_Blue_ButtonA_Press", "buttons_Blue_ButtonC_Unpressed",
    "buttons_Gold_ButtonA_Highlighted", "buttons_Gold_ButtonC_Highlighted", "buttons_Orange_ButtonA_Highlighted",
    "panels_Black_PanelOutlined", "panels_Black_Panel", "panels_Black_PanelDigital", "panels_Gold_Panel"]}
empty = sub("StyleBoxEmpty", {})

# Defaults
props.append(f'default_font = {pix}')
props.append("default_font_size = 13")
p("Label", "colors/font_color", col("#ece8df"))
p("Label", "colors/font_shadow_color", col("#06080f", 0.0))

# Label variations: Silk (regular) / SilkBold
for name, font, size, c in [("Silk", silk, 9, "#9a968c"), ("SilkBold", silkb, 11, "#ece8df")]:
    p(name, "base_type", '&"Label"')
    p(name, "fonts/font", font)
    p(name, "font_sizes/font_size", size)
    p(name, "colors/font_color", col(c))

# Sprite buttons. A: 34x18 slice 4 -> 12px border. C: 32x14 slice 3 -> 9px border.
A_PAD, C_PAD = (16, 13), (13, 9)
def button(name, tex, fg, pad, slice_px, font, size, hover_tex=None, press_tex=None, hover_fg=None):
    p(name, "base_type", '&"Button"')
    p(name, "styles/normal", tex_box(tex, slice_px, pad))
    p(name, "styles/hover", tex_box(hover_tex, slice_px, pad) if hover_tex else tex_box(tex, slice_px, pad, 1.3))
    p(name, "styles/pressed", tex_box(press_tex, slice_px, pad) if press_tex else tex_box(tex, slice_px, pad, 0.85))
    p(name, "styles/hover_pressed", tex_box(press_tex, slice_px, pad) if press_tex else tex_box(tex, slice_px, pad, 0.85))
    p(name, "styles/disabled", tex_box(tex, slice_px, pad))
    p(name, "styles/focus", empty)
    p(name, "fonts/font", font)
    p(name, "font_sizes/font_size", size)
    for state in ["font_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
        p(name, f"colors/{state}", col(fg))
    p(name, "colors/font_hover_color", col(hover_fg or fg))

button("BtnGold", T["buttons_Gold_ButtonA_Highlighted"], "#ffd166", A_PAD, 12, silkb, 10)
button("BtnOrange", T["buttons_Orange_ButtonA_Highlighted"], "#ece8df", A_PAD, 12, silkb, 10)
button("BtnGrey", T["buttons_Blue_ButtonA_Unpressed"], "#77746c", A_PAD, 12, silkb, 10)
button("BtnOwned", T["buttons_Blue_ButtonA_Press"], "#7bc96f", A_PAD, 12, silkb, 10)
button("BtnCGold", T["buttons_Gold_ButtonC_Highlighted"], "#ffd166", C_PAD, 9, silk, 9)
button("BtnCGrey", T["buttons_Blue_ButtonC_Unpressed"], "#9a968c", C_PAD, 9, silk, 9)
button("BtnSettings", T["buttons_Blue_ButtonA_Unpressed"], "#ece8df", A_PAD, 12, silkb, 10,
       hover_tex=T["buttons_Orange_ButtonA_Highlighted"], press_tex=T["buttons_Blue_ButtonA_Press"], hover_fg="#f5c518")

# Sprite panels (PanelContainer variations).
def panel(name, style):
    p(name, "base_type", '&"PanelContainer"')
    p(name, "styles/panel", style)

panel("PanelOutlined", tex_box(T["panels_Black_PanelOutlined"], 12, (12,)))
panel("PanelBlack", tex_box(T["panels_Black_Panel"], 12, (12,)))
panel("PanelGold", tex_box(T["panels_Gold_Panel"], 12, (18, 12)))
# Money panel: CSS lets the 8+20px labels overflow into the 12px border; tighter vertical margins emulate that.
panel("PanelMoney", tex_box(T["panels_Gold_Panel"], 12, (18, 4)))
panel("PanelDigital", tex_box(T["panels_Black_PanelDigital"], 24, (24,)))

# Flat panels from the design tokens.
panel("Header", flat("#06080f", bg_a=0.8, content=(14, 0), extra={"border_width_bottom": 3, "border_color": col("#3a3a3d")}))
panel("Stage", flat("#141416", radius=6))
panel("Inset", flat("#141416", radius=6, content=(9, 7)))
panel("SellBar", flat("#1d1d20", radius=6, content=(12, 10)))
panel("Card", flat("#202023", "#3a3a3d", 2, 8, (10,)))
panel("CardAfford", flat("#202023", "#5a4a14", 2, 8, (10,)))
panel("CardHover", flat("#242427", "#e2702a", 2, 8, (10,)))
panel("CardLarge", flat("#202023", "#3a3a3d", 2, 8, (12,)))
panel("CardLargeAfford", flat("#202023", "#5a4a14", 2, 8, (12,)))
panel("Teaser", flat("#000000", bg_a=0.0, content=(12,)))
panel("Tab", flat("#1d1d20", "#3a3a3d", 2, 6, (10, 7)))
panel("TabSel", flat("#2d2d30", "#f5c518", 2, 6, (10, 7)))
panel("TabHover", flat("#1d1d20", "#e2702a", 2, 6, (10, 7)))
panel("Slot", flat("#1a1a1c", "#3a3a3d", 2, 8, (12, 10)))
panel("SlotSel", flat("#26262a", "#f5c518", 2, 8, (12, 10)))
panel("SlotHover", flat("#1a1a1c", "#e2702a", 2, 8, (12, 10)))
panel("Pill", flat("#141416", radius=99, content=(6, 3)))
panel("Drawer", flat("#141416", "#3a3a3d", 2, 8, (14,), extra={"shadow_color": col("#06080f", 0.45), "shadow_size": 1, "shadow_offset": "Vector2(-12, 0)"}))
panel("QuoteRow", flat("#000000", radius=6, content=(6,), bg_a=0.0))
panel("QuoteRowSel", flat("#2d2d30", radius=6, content=(6,)))
panel("Tooltip", flat("#06080f", "#f5c518", 2, 8, (13, 11), extra={"shadow_color": col("#000000", 0.5), "shadow_size": 1, "shadow_offset": "Vector2(4, 4)"}))
panel("Badge", flat("#e2702a", radius=2, content=(5, 2)))
panel("ModalBody", flat("#141416"))

# Scroll bars: thin and quiet.
p("VScrollBar", "styles/scroll", flat("#141416", radius=2, content=(2,)))
p("VScrollBar", "styles/grabber", flat("#3a3a3d", radius=2, content=(2,)))
p("VScrollBar", "styles/grabber_highlight", flat("#4a4a4d", radius=2, content=(2,)))
p("VScrollBar", "styles/grabber_pressed", flat("#77746c", radius=2, content=(2,)))

out = [f'[gd_resource type="Theme" load_steps={len(ext)+len(subs)+1} format=3]', ""] + ext + [""]
for s in subs: out += [s, ""]
out += ["[resource]"] + props
open("ui/theme.tres", "w").write("\n".join(out) + "\n")
print("wrote ui/theme.tres", len(subs), "styles")
