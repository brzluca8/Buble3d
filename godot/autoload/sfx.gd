extends Node
## Efecte sonore generate din cod (fără fișiere audio). Autoload „Sfx".
## Folosire: Sfx.play("pop"). Sunetul se oprește din Setări (Game.sound).

const RATE := 22050
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)
	_streams = {
		"shoot": _tone([[520.0, 900.0, 0.09]], 0.5, "square"),
		"pop": _tone([[880.0, 1320.0, 0.07]], 0.45, "sine"),
		"fall": _tone([[700.0, 260.0, 0.22]], 0.35, "triangle"),
		"bomb": _noise(0.35, 0.6),
		"rainbow": _tone([[660.0, 660.0, 0.06], [880.0, 880.0, 0.06], [1100.0, 1100.0, 0.06], [1320.0, 1320.0, 0.1]], 0.35, "sine"),
		"win": _tone([[523.0, 523.0, 0.12], [659.0, 659.0, 0.12], [784.0, 784.0, 0.12], [1046.0, 1046.0, 0.3]], 0.4, "triangle"),
		"lose": _tone([[440.0, 440.0, 0.18], [330.0, 300.0, 0.35]], 0.35, "triangle"),
		"coin": _tone([[988.0, 988.0, 0.07], [1319.0, 1319.0, 0.18]], 0.35, "square"),
		"click": _tone([[1200.0, 1000.0, 0.03]], 0.25, "sine"),
		"tick": _tone([[1800.0, 1500.0, 0.015]], 0.18, "sine"),
		"reel_stop": _tone([[420.0, 300.0, 0.06]], 0.4, "triangle"),
		"bigwin": _tone([[523.0, 523.0, 0.09], [659.0, 659.0, 0.09], [784.0, 784.0, 0.09], [1046.0, 1046.0, 0.09], [1318.0, 1318.0, 0.35]], 0.4, "sine"),
		"build": _tone([[300.0, 260.0, 0.05], [300.0, 260.0, 0.05], [420.0, 380.0, 0.08]], 0.35, "square"),
		"upgrade": _tone([[392.0, 392.0, 0.08], [523.0, 523.0, 0.08], [659.0, 659.0, 0.08], [784.0, 1046.0, 0.25]], 0.4, "square"),
		# mașina de bule
		"lever": _ratchet(6, 0.035, 0.5),
		"spin": _whoosh(0.5, 0.35, true),
		"whoosh": _whoosh(0.35, 0.4, false),
		"anticip": _sweep(240.0, 920.0, 1.7, 0.32),
		"win_small": _tone([[784.0, 784.0, 0.07], [1046.0, 1046.0, 0.07], [1318.0, 1318.0, 0.16]], 0.33, "sine"),
		"win_big": _tone([[523.0, 523.0, 0.08], [659.0, 659.0, 0.08], [784.0, 784.0, 0.08], [1046.0, 1046.0, 0.08], [784.0, 784.0, 0.08], [1046.0, 1046.0, 0.08], [1318.0, 1318.0, 0.45]], 0.38, "triangle"),
		"win_huge": _tone([[392.0, 392.0, 0.12], [523.0, 523.0, 0.12], [659.0, 659.0, 0.12], [784.0, 784.0, 0.12], [659.0, 659.0, 0.1], [784.0, 784.0, 0.1], [1046.0, 1046.0, 0.14], [1318.0, 1318.0, 0.14], [1568.0, 1568.0, 0.6]], 0.4, "triangle"),
		"shrug": _tone([[330.0, 300.0, 0.14], [262.0, 190.0, 0.3]], 0.32, "triangle"),
		"smash": _shatter(0.6, 0.6),
		"chest": _tone([[880.0, 880.0, 0.05], [1175.0, 1175.0, 0.05], [1480.0, 1480.0, 0.05], [1760.0, 2200.0, 0.25]], 0.3, "sine"),
		"shield": _sweep(520.0, 780.0, 0.6, 0.3),
		"zap": _tone([[1600.0, 400.0, 0.12], [1400.0, 300.0, 0.12]], 0.3, "square"),
	}


## Vibrație scurtă (dacă jucătorul nu a oprit-o în Setări).
func buzz(ms := 40) -> void:
	if Game.vibration:
		Input.vibrate_handheld(ms)


func play(name: String, pitch := 1.0) -> void:
	if not Game.sound or not _streams.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.play()


## Note: [[frecvență început, frecvență sfârșit, durată], ...] cântate una după alta.
func _tone(notes: Array, vol: float, wave: String) -> AudioStreamWAV:
	var data := PackedByteArray()
	for n in notes:
		var f0: float = n[0]
		var f1: float = n[1]
		var dur: float = n[2]
		var count := int(dur * RATE)
		var phase := 0.0
		for i in count:
			var t := float(i) / count
			var f := lerpf(f0, f1, t)
			phase += f / RATE
			var x := fmod(phase, 1.0)
			var v: float
			match wave:
				"square": v = 1.0 if x < 0.5 else -1.0
				"triangle": v = 4.0 * absf(x - 0.5) - 1.0
				_: v = sin(phase * TAU)
			var env := minf(1.0, t * 20.0) * pow(1.0 - t, 1.6)
			_put(data, v * env * vol * (0.6 if wave == "square" else 1.0))
	return _wav(data)


## Clicuri de clichet (maneta trasă), tot mai joase, apoi o bufnitură scurtă.
func _ratchet(n: int, gap: float, vol: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	for k in n:
		var count := int(gap * RATE)
		for i in count:
			var t := float(i) / count
			var v := sin(TAU * (2200.0 - k * 180.0) * i / RATE) * pow(1.0 - t, 8.0) + randf_range(-1.0, 1.0) * pow(1.0 - t, 14.0) * 0.6
			_put(data, v * vol)
	var count2 := int(0.12 * RATE)
	for i in count2:
		var t := float(i) / count2
		_put(data, sin(TAU * lerpf(160.0, 70.0, t) * i / RATE) * pow(1.0 - t, 2.0) * vol)
	return _wav(data)


## Foșnet de aer (rotirea rolelor / un obiect care zboară); `rising` = urcă în frecvență.
func _whoosh(dur: float, vol: float, rising: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	var count := int(dur * RATE)
	var lp := 0.0
	for i in count:
		var t := float(i) / count
		var k := lerpf(0.05, 0.45, t) if rising else lerpf(0.45, 0.05, t)
		lp = lerpf(lp, randf_range(-1.0, 1.0), k)
		var env := sin(PI * t)
		_put(data, lp * env * vol)
	return _wav(data)


## Ton care urcă, cu tremolo (anticiparea: „muzica urcă”).
func _sweep(f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	var count := int(dur * RATE)
	var phase := 0.0
	var phase2 := 0.0
	for i in count:
		var t := float(i) / count
		var f := lerpf(f0, f1, t * t)
		phase += f / RATE
		phase2 += f * 1.5 / RATE
		var trem := 0.65 + 0.35 * sin(TAU * lerpf(6.0, 16.0, t) * i / RATE)
		var env := minf(1.0, t * 8.0) * minf(1.0, (1.0 - t) * 12.0)
		_put(data, (sin(phase * TAU) * 0.7 + sin(phase2 * TAU) * 0.3) * trem * env * vol)
	return _wav(data)


## Sticlă spartă: zgomot strălucitor cu clinchete scurte, peste o bufnitură.
func _shatter(dur: float, vol: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	var count := int(dur * RATE)
	var prev := 0.0
	for i in count:
		var t := float(i) / count
		var n := randf_range(-1.0, 1.0)
		var hp := n - prev
		prev = n
		var ting := sin(TAU * (3100.0 + 900.0 * sin(i * 0.002)) * i / RATE) * (0.5 if int(t * 40.0) % 3 == 0 else 0.0)
		var boom := sin(TAU * lerpf(110.0, 45.0, t) * i / RATE) * pow(1.0 - t, 3.0)
		_put(data, (hp * 0.5 * pow(1.0 - t, 1.5) + ting * pow(1.0 - t, 2.0) + boom * 0.7) * vol)
	return _wav(data)


func _noise(dur: float, vol: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	var count := int(dur * RATE)
	var lp := 0.0
	for i in count:
		var t := float(i) / count
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.25)
		var boom := sin(TAU * lerpf(90.0, 40.0, t) * i / RATE)
		_put(data, (lp * 0.7 + boom * 0.6) * pow(1.0 - t, 2.0) * vol)
	return _wav(data)


func _put(data: PackedByteArray, v: float) -> void:
	var s := int(clampf(v, -1.0, 1.0) * 32767.0)
	data.append(s & 0xFF)
	data.append((s >> 8) & 0xFF)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
