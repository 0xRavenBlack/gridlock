extends Node
## AudioManager (autoload) - owns the SFX/Music buses, a small player pool and
## the runtime-generated sound bank, including a seamlessly looping chill-out
## bed. Call play("clear") from anywhere; it all ships as generated PCM, no audio
## files. The music is the one costly sound, so it is synthesised on a worker
## thread and fades in; startup is never blocked waiting for it.

const BUS_SFX := "SFX"
const BUS_MUSIC := "Music"
const POOL_SIZE := 8
const MUSIC_KEY := "music"
const MUSIC_FADE_SECONDS := 2.5

## Warm, unhurried A-minor progression (Am7 – Fmaj7 – Cmaj7 – G6) for the menus
## and idle moments. Each bar carries a mid-register chord voicing and a low bass
## root, both in Hz, and is looped by `ToneFactory.chillout`.
const MUSIC_PROGRESSION := [
	{"bass": 110.00, "chord": [220.00, 261.63, 329.63, 392.00]},
	{"bass": 87.31, "chord": [174.61, 220.00, 261.63, 329.63]},
	{"bass": 130.81, "chord": [261.63, 329.63, 392.00, 493.88]},
	{"bass": 98.00, "chord": [196.00, 246.94, 293.66, 329.63]},
]

## A-minor pentatonic notes the bell layer improvises over, in Hz.
const MUSIC_MELODY := [440.0, 523.25, 587.33, 659.25, 783.99, 880.0, 1046.5]

const SOUND_SPECS := {
	"click": {"kind": "tone", "freq": 660.0, "duration": 0.06, "decay": 34.0, "volume": 0.35},
	"pickup": {"kind": "tone", "freq": 520.0, "duration": 0.07, "decay": 26.0, "volume": 0.30},
	"place": {"kind": "tone", "freq": 300.0, "duration": 0.09, "decay": 24.0, "volume": 0.45},
	"invalid": {"kind": "tone", "freq": 150.0, "duration": 0.12, "decay": 18.0, "volume": 0.40},
	"clear": {"kind": "chord", "low": 660.0, "high": 990.0, "duration": 0.20, "decay": 12.0, "volume": 0.45},
	"combo": {"kind": "chord", "low": 880.0, "high": 1320.0, "duration": 0.30, "decay": 9.0, "volume": 0.45},
	"mega": {"kind": "chord", "low": 1318.0, "high": 1975.0, "duration": 0.45, "decay": 7.0, "volume": 0.50},
	"new_best": {"kind": "rise", "notes": [523.25, 659.25, 783.99, 1046.5], "step": 0.12, "volume": 0.5, "sustain": 2.0},
	"game_over": {"kind": "tone", "freq": 140.0, "duration": 0.75, "decay": 3.5, "volume": 0.45},
	"music": {
		"kind": "chillout",
		"progression": MUSIC_PROGRESSION,
		"bar_seconds": 2.6,
		"repeats": 2,
		"melody": MUSIC_MELODY,
		"volume": 0.45,
		"seed": 1010,
	},
}

var _bank: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music_player: AudioStreamPlayer
var _music: AudioStreamWAV
var _music_pending: AudioStreamWAV
var _music_thread: Thread

func _ready() -> void:
	_ensure_bus(BUS_SFX)
	_ensure_bus(BUS_MUSIC)
	_build_bank()
	_build_pool()
	_build_music()
	apply_volumes()
	_start_music()

## Stops every voice and drops the bank on shutdown so a force-quit mid-note
## doesn't leave the active streams referenced by the audio server.
func _exit_tree() -> void:
	if _music_thread != null and _music_thread.is_started():
		_music_thread.wait_to_finish()
	if _music_player != null:
		_music_player.stop()
		_music_player.stream = null
	for player in _players:
		player.stop()
		player.stream = null
	_bank.clear()
	_music = null
	# Drop a bed that finished generating but was never handed to the main thread,
	# so quitting mid-build cannot leak the stream.
	_music_pending = null

func play(sound: String, pitch: float = 1.0) -> void:
	if not _bank.has(sound):
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _bank[sound]
	player.pitch_scale = pitch
	player.play()

## Starts the ambient bed playing once it has been generated (a no-op before then).
func play_music() -> void:
	if _music == null:
		return
	_music_player.stream = _music
	_music_player.play()

func set_sfx_volume(value: float) -> void:
	SaveManager.set_value("audio", "sfx", value)
	apply_volumes()

func set_music_volume(value: float) -> void:
	SaveManager.set_value("audio", "music", value)
	apply_volumes()

func apply_volumes() -> void:
	_set_bus_volume(BUS_SFX, float(SaveManager.get_value("audio", "sfx", 0.8)))
	_set_bus_volume(BUS_MUSIC, float(SaveManager.get_value("audio", "music", 0.6)))
	_set_bus_volume("Master", 1.0)

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)

func _set_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	var db := linear_to_db(clampf(linear, 0.001, 1.0)) if linear > 0.0 else -80.0
	AudioServer.set_bus_volume_db(index, db)

func _build_bank() -> void:
	# The ambient bed is built off-thread (see _start_music); everything else is
	# short enough to synthesise synchronously.
	for name in SOUND_SPECS:
		if name == MUSIC_KEY:
			continue
		_bank[name] = _build_sound(SOUND_SPECS[name])

func _build_sound(spec: Dictionary) -> AudioStreamWAV:
	match spec["kind"]:
		"chord":
			return ToneFactory.chord(spec["low"], spec["high"], spec["duration"], spec["decay"], spec["volume"])
		"rise":
			return ToneFactory.arpeggio(spec["notes"], spec["step"], spec["volume"], spec["sustain"])
		"chillout":
			return ToneFactory.chillout(spec)
		_:
			return ToneFactory.tone(spec["freq"], spec["duration"], spec["decay"], spec["volume"])

func _build_pool() -> void:
	for _i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_players.append(player)

func _build_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = BUS_MUSIC
	add_child(_music_player)

## Synthesises the ambient bed on a worker thread so the menu appears instantly;
## the result is handed back to the main thread via a deferred call.
func _start_music() -> void:
	_music_thread = Thread.new()
	_music_thread.start(_generate_music)

func _generate_music() -> void:
	_music_pending = _build_sound(SOUND_SPECS[MUSIC_KEY])
	# Notify the main thread without passing the stream as an argument: a pending
	# deferred call would otherwise keep the stream alive if we quit first.
	call_deferred("_on_music_ready")

func _on_music_ready() -> void:
	if _music_pending == null or not is_inside_tree():
		return
	_music = _music_pending
	_music_pending = null
	_music_player.volume_db = -40.0
	play_music()
	create_tween().tween_property(_music_player, "volume_db", 0.0, MUSIC_FADE_SECONDS)