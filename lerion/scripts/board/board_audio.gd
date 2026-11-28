extends Node
## Separate short-lived voices allow a landing and its reward to overlap.
const ROLL := preload("res://assets/board/audio/tumble.wav")
const STEP := preload("res://assets/board/audio/step.wav")
const LAND := preload("res://assets/board/audio/land.wav")
const COIN := preload("res://assets/board/audio/coin.wav")
const GEM := preload("res://assets/board/audio/gem.wav")
const UPGRADE := preload("res://assets/board/audio/upgrade.wav")
const BUTTON := preload("res://assets/board/audio/button.wav")
const IMPACT := preload("res://assets/board/audio/contact.wav")
const MUSIC := preload("res://assets/board/audio/poiana.wav")
var music_enabled := true
var suspended := false
var effects_enabled := true
var music_voice: AudioStreamPlayer
var impacts: AudioStreamPlayer
var has_output := false
var rolling: AudioStreamPlayer
var feet: AudioStreamPlayer
var chime: AudioStreamPlayer


func _ready() -> void:
	has_output = AudioServer.get_driver_name() != "Dummy" or not Engine.get_write_movie_path().is_empty()
	rolling = _voice(-5.0)
	feet = _voice(-7.0)
	chime = _voice(-4.0)
	impacts = _voice(-8.0)
	music_voice = _voice(-17.0)
	music_voice.stream = MUSIC


func _voice(volume: float) -> AudioStreamPlayer:
	var voice := AudioStreamPlayer.new()
	voice.volume_db = volume
	add_child(voice)
	return voice


func _play(voice: AudioStreamPlayer, clip: AudioStream, pitch := 1.0) -> void:
	if not has_output or not effects_enabled or suspended:
		return
	voice.stream = clip
	voice.pitch_scale = pitch
	voice.play()


func toss() -> void:
	_play(rolling,ROLL)


func step(index: int) -> void:
	_play(feet,STEP,1.04 if index % 2 == 0 else 0.96)


func land() -> void:
	rolling.stop()
	_play(feet,LAND)


func reward(resource: String) -> void:
	_play(chime,COIN if resource == "coins" else GEM,0.85 if resource == "build_points" else 1.0)


func upgrade() -> void:
	_play(chime,UPGRADE)

func configure(music: bool, effects: bool) -> void:
	music_enabled = music
	effects_enabled = effects
	if not effects:
		for voice in [rolling,feet,chime,impacts] + fx_voices:
			voice.stop()
	if not music:
		music_voice.stop()
	elif has_output and not suspended and not music_voice.playing:
		music_voice.play()

func click() -> void:
	_play(impacts,BUTTON)

func impact(strength: float) -> void:
	_play(impacts,IMPACT,1.0+(1.0-strength)*0.55)

func magic() -> void:
	_play(impacts,GEM,1.35)


## Named sound events for the polish layer. Each name may get its own stream later (assign it in
## `event_streams`); until then it falls back to the closest existing sound, so the call sites
## never change when real audio arrives.
const EVENTS := {
	"roll_press": "click", "wheel_spin": "toss", "wheel_tick": "click", "wheel_stop": "land",
	"win_energy": "gem", "win_chest_wood": "magic", "win_chest_silver": "magic", "win_chest_gold": "upgrade",
	"coin_gain": "coin", "hud_pop": "click", "start_pass": "coin", "landing": "land", "crystal_pulse": "magic",
	"crystal_ready": "upgrade", "chest_open": "upgrade", "card_reveal": "click", "card_reveal_rare": "upgrade",
	"upgrade": "upgrade", "dice_settle": "click", "chest_beat": "gem", "crystal_activate": "upgrade", "hammer": "click", "hammer_big": "land", "cheer": "coin", "sneeze": "magic"}
var event_streams := {}
## Etapa 4.2 cues (tools/build_fx_audio.py). Events without a cue keep their fallback.
const CUES := {
	"wheel_tick": preload("res://assets/board/audio/fx_wheel_tick.wav"),
	"wheel_stop": preload("res://assets/board/audio/fx_wheel_stop.wav"),
	"win_energy": preload("res://assets/board/audio/fx_win_energy.wav"),
	"win_chest_wood": preload("res://assets/board/audio/fx_win_chest.wav"),
	"win_chest_silver": preload("res://assets/board/audio/fx_win_chest.wav"),
	"win_chest_gold": preload("res://assets/board/audio/fx_win_gold.wav"),
	"chest_beat": preload("res://assets/board/audio/fx_chest_beat.wav"),
	"chest_open": preload("res://assets/board/audio/fx_chest_open.wav"),
	"card_reveal": preload("res://assets/board/audio/fx_card_flip.wav"),
	"card_reveal_rare": preload("res://assets/board/audio/fx_card_rare.wav"),
	"crystal_pulse": preload("res://assets/board/audio/fx_crystal_pulse.wav"),
	"crystal_ready": preload("res://assets/board/audio/fx_awaken.wav"),
	"crystal_activate": preload("res://assets/board/audio/fx_crystal_activate.wav"),
	"dice_settle": preload("res://assets/board/audio/fx_dice_settle.wav"),
	"hammer": preload("res://assets/board/audio/fx_hammer.wav"),
	"hammer_big": preload("res://assets/board/audio/fx_hammer_big.wav"),
	"cheer": preload("res://assets/board/audio/fx_cheer.wav"),
	"sneeze": preload("res://assets/board/audio/fx_sneeze.wav"),
	"landing": preload("res://assets/board/audio/fx_landing.wav"),
	"hud_pop": preload("res://assets/board/audio/fx_hud_pop.wav"),
}
## Minimum gap between two plays of the same cue, and a small random pitch spread, so sounds
## heard dozens of times per session do not stack up or become mechanical.
const MIN_GAP := {"wheel_tick": 0.045, "hud_pop": 0.1, "card_reveal": 0.06, "crystal_pulse": 0.25, "landing": 0.15, "hammer": 0.08}
const JITTER := {"wheel_tick": 0.06, "hud_pop": 0.05, "card_reveal": 0.05, "landing": 0.04, "hammer": 0.05, "dice_settle": 0.03}
var last_played := {}
var fx_voices: Array[AudioStreamPlayer] = []
var fx_next := 0


func play_event(event: String, pitch := 1.0) -> void:
	if not EVENTS.has(event) and not CUES.has(event):
		return
	var now := Time.get_ticks_msec()/1000.0
	if now - float(last_played.get(event,-10.0)) < float(MIN_GAP.get(event,0.0)):
		return
	last_played[event] = now
	var clip: AudioStream = event_streams.get(event,CUES.get(event))
	if clip != null:
		var spread := float(JITTER.get(event,0.0))
		_play(_fx_voice(),clip,pitch*(1.0 + randf_range(-spread,spread)))
		return
	if not EVENTS.has(event):
		return
	match EVENTS[event]:
		"click": click()
		"toss": toss()
		"land": land()
		"gem": _play(chime,GEM,pitch)
		"coin": _play(chime,COIN,pitch)
		"magic": magic()
		"upgrade": upgrade()

func _notification(what: int) -> void:
	if not is_instance_valid(music_voice):
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		suspended = true
		for voice in [rolling,feet,chime,impacts,music_voice] + fx_voices:
			voice.stop()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		suspended = false
		configure(music_enabled,effects_enabled)


## A small pool of voices so overlapping cues (a tick during a chime) do not cut each other off.
func _fx_voice() -> AudioStreamPlayer:
	if fx_voices.is_empty():
		for i in range(4):
			fx_voices.append(_voice(-6.0))
	fx_next = (fx_next + 1) % fx_voices.size()
	return fx_voices[fx_next]
