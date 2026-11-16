extends Control
## Mașina de bule: trei role cu simboluri în bule premium. Rezultatul vine din Game.spin()
## (tabelul de probabilități din data/spin_table.json); rolele doar îl arată: accelerează,
## se rotesc, apoi frânează pe rând, cu un mic recul. Sunet la fiecare simbol, vibrație și
## particule la câștigurile mari.

signal result_ready(res: Dictionary)

const K := preload("res://scripts/ui/ui_kit.gd")
const SYM := {
	"coin": ["coins", Color("f2b630")], "bag": ["hand-coins", Color("d99a2b")], "gem": ["gem", Color("2bd4c8")],
	"energy": ["zap", Color("5fc8ff")], "shield": ["shield", Color("6f8cff")], "hammer": ["hammer", Color("e8645a")],
	"shovel": ["shovel", Color("9a6ae8")], "chest": ["package", Color("e0a040")], "card": ["layers", Color("e66fa8")],
}

class Reel:
	extends Control
	var strip: Array = []           # simbolurile de pe rolă
	var pos := 0.0                  # poziția (în simboluri) a centrului ferestrei
	var cell := 140.0
	var bubble: Texture2D
	var _last_tick := 0

	func _draw() -> void:
		var h := size.y
		var cy := h / 2.0
		var first := int(floor(pos - 1.5))
		for k in range(first, first + 4):
			var sym: String = strip[posmod(k, strip.size())]
			var y := cy + (k - pos) * cell
			var info: Array = SYM[sym]
			var r := cell * 0.42
			var c: Color = info[1]
			var rect := Rect2(Vector2(size.x / 2 - r, y - r), Vector2(r * 2, r * 2))
			draw_texture_rect(bubble, rect, false, c)
			var ic: Texture2D = K.icon(info[0])
			if ic:
				var ir := rect.grow(-r * 0.45)
				draw_texture_rect(ic, ir, false, Color(1, 1, 1, 0.96))
		# umbră sus și jos (adâncime de tambur)
		for i in 12:
			var a := 0.55 * (1.0 - i / 12.0)
			draw_rect(Rect2(0, i * 4, size.x, 4), Color(0.05, 0.03, 0.18, a))
			draw_rect(Rect2(0, h - (i + 1) * 4, size.x, 4), Color(0.05, 0.03, 0.18, a))

	func _process(_dt: float) -> void:
		var t := int(floor(pos + 0.5))
		if t != _last_tick:
			_last_tick = t
			if is_visible_in_tree():
				Sfx.play("tick", 0.9 + randf() * 0.2)
		queue_redraw()


var reels: Array[Reel] = []
var spin_btn: Button
var spin_lbl: Label
var energy_lbl: Label
var mult_btn: Button
var result_lbl: Label
var sparks: CPUParticles2D
var busy := false
var _bubble_tex: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_tex = _make_bubble()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", K.glass(36, 14, 0.88))
	K.full_rect(panel)
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	# role
	var frame := PanelContainer.new()
	var fs := K.box(Color(0.04, 0.03, 0.14, 0.95), 26, K.GOLD, 3, 0, 6)
	frame.add_theme_stylebox_override("panel", fs)
	frame.custom_minimum_size = Vector2(0, 168)
	vb.add_child(frame)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	frame.add_child(hb)
	var syms: Array = Game.D.spin_table.symbols
	for i in 3:
		var r := Reel.new()
		r.bubble = _bubble_tex
		r.clip_contents = true
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.custom_minimum_size = Vector2(0, 156)
		r.cell = 132.0
		for k in 24:
			r.strip.append(syms[(k * (i + 2) + i * 3) % syms.size()])
		r.pos = randi() % 24
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(r)
		reels.append(r)
	# linia de câștig
	result_lbl = K.label(" ", 24, Color("ffe08a"), 800)
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(result_lbl)
	# comenzi
	var ctl := HBoxContainer.new()
	ctl.add_theme_constant_override("separation", 10)
	vb.add_child(ctl)
	mult_btn = K.button("×1", 28, K.glass(22, 8), K.GOLD)
	mult_btn.custom_minimum_size = Vector2(108, 86)
	mult_btn.pressed.connect(func():
		Sfx.play("click")
		Game.cycle_mult()
		if Game.multipliers().size() == 1:
			Game.toast.emit("Multiplicatorul se deblochează la nivelul %d" % int(Game.cfg("multiplier_unlock_level", 5))))
	ctl.add_child(mult_btn)
	spin_btn = K.gold_button("", 34)
	spin_btn.custom_minimum_size = Vector2(0, 86)
	spin_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sv := VBoxContainer.new()
	K.full_rect(sv)
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	sv.add_theme_constant_override("separation", -4)
	sv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spin_lbl = K.label("Rotește", 36, K.INK, 900)
	spin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_lbl = K.label("", 18, Color(K.INK, 0.75), 800)
	energy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(spin_lbl)
	sv.add_child(energy_lbl)
	spin_btn.add_child(sv)
	spin_btn.pressed.connect(spin)
	ctl.add_child(spin_btn)
	var odds := K.icon_button("circle-help", "", 20, K.glass(22, 8), Color(1, 1, 1, 0.85), 36)
	odds.custom_minimum_size = Vector2(86, 86)
	odds.tooltip_text = "Șanse"
	odds.pressed.connect(func(): get_parent().get_parent().open_modal("sanse"))
	ctl.add_child(odds)
	# particule pentru câștiguri mari
	sparks = CPUParticles2D.new()
	sparks.emitting = false
	sparks.one_shot = true
	sparks.explosiveness = 0.9
	sparks.amount = 70
	sparks.lifetime = 1.4
	sparks.texture = _spark_tex()
	sparks.direction = Vector2.UP
	sparks.spread = 80.0
	sparks.initial_velocity_min = 300.0
	sparks.initial_velocity_max = 700.0
	sparks.gravity = Vector2(0, 900)
	sparks.scale_amount_min = 0.4
	sparks.scale_amount_max = 1.0
	sparks.color = Color(1.0, 0.85, 0.4)
	add_child(sparks)
	Game.changed.connect(refresh)
	refresh()


func refresh() -> void:
	energy_lbl.text = "Energie %d / %d%s" % [Game.energy, Game.energy_cap(), ("   +1 în " + Game.fmt_time(Game.energy_next_in())) if Game.energy < Game.energy_cap() else ""]
	mult_btn.text = "×%d" % Game.mult
	mult_btn.modulate = Color.WHITE if Game.multipliers().size() > 1 else Color(1, 1, 1, 0.45)
	spin_btn.modulate = Color.WHITE if Game.energy >= Game.mult else Color(0.75, 0.72, 0.8)


func _process(_dt: float) -> void:
	if Engine.get_process_frames() % 30 == 0:
		refresh()


## O rotire completă: rezultat din tabel, animația rolelor, apoi semnalul result_ready.
func spin() -> void:
	if busy:
		return
	var res := Game.spin()
	if res.is_empty():
		Sfx.play("click")
		get_parent().get_parent().open_modal("energie")
		return
	busy = true
	result_lbl.text = " "
	Sfx.play("click")
	Sfx.buzz(20)
	var tws := []
	for i in 3:
		var r := reels[i]
		# pune simbolul dorit pe rolă, la o distanță care dă 2–3 ture complete
		var turns := 2 + i
		var target := floori(r.pos) + turns * r.strip.size() + randi_range(3, 8)
		r.strip[posmod(target, r.strip.size())] = res.reels[i]
		var tw := create_tween()
		tw.tween_property(r, "pos", r.pos + 1.2, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)      # accelerare
		tw.tween_property(r, "pos", float(target) + 0.18, 0.75 + 0.35 * i).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)   # frânare
		tw.tween_property(r, "pos", float(target), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)   # recul
		tw.tween_callback(func():
			Sfx.play("reel_stop", 1.0 + i * 0.08)
			Sfx.buzz(15))
		tws.append(tw)
	await tws[2].finished
	r_normalize()
	result_lbl.text = res.msg
	if res.big:
		_celebrate()
	elif res.coins > 0 or res.energy > 0:
		Sfx.play("coin")
	busy = false
	result_ready.emit(res)


func r_normalize() -> void:
	for r in reels:
		r.pos = fposmod(r.pos, r.strip.size())


func _celebrate() -> void:
	sparks.position = Vector2(size.x / 2, 90)
	sparks.restart()
	Sfx.play("bigwin")
	Sfx.buzz(120)
	var tw := create_tween()
	for k in 4:
		tw.tween_property(self, "position:x", position.x + (8 if k % 2 == 0 else -8), 0.04)
	tw.tween_property(self, "position:x", position.x, 0.04)


# ---------------- texturi generate ----------------
func _make_bubble() -> Texture2D:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x - n / 2.0 + 0.5, y - n / 2.0 + 0.5) / (n / 2.0)
			var d := p.length()
			if d > 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var edge := clampf((1.0 - d) * 40.0, 0.0, 1.0)
			var shade := 0.55 + 0.45 * (1.0 - d * d) - 0.25 * p.y
			var rim := pow(d, 6.0) * 0.6
			var hl := clampf(1.0 - (p - Vector2(-0.35, -0.42)).length() / 0.32, 0.0, 1.0)
			var v := clampf(shade + rim, 0.0, 1.0)
			var c := Color(v, v, v).lerp(Color.WHITE, hl * 0.85)
			c.a = edge
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _spark_tex() -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.5).length() / 8.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
