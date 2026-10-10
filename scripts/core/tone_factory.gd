class_name ToneFactory
extends RefCounted
## Generates small 16-bit mono PCM tones at runtime so the game ships with
## real sound without depending on binary audio assets.

const MIX_RATE := 44100
## The ambient bed is generated at a reduced rate. It is plenty for a soft,
## low-frequency wash, lends the music a gentle lo-fi warmth, and keeps the cost
## of building it at startup down.
const MUSIC_RATE := 16000

## Builds a single tone with an exponential decay envelope.
static func tone(frequency: float, duration: float, decay: float, volume: float = 0.6) -> AudioStreamWAV:
	var samples := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var time := float(i) / MIX_RATE
		var envelope := exp(-time * decay)
		var wave := sin(TAU * frequency * time) * envelope * volume
		_write_sample(data, i, wave)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream

## Two stacked tones give a richer, bell-like "clear" sound.
static func chord(low: float, high: float, duration: float, decay: float, volume: float = 0.5) -> AudioStreamWAV:
	var samples := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var time := float(i) / MIX_RATE
		var envelope := exp(-time * decay)
		var wave := (sin(TAU * low * time) + sin(TAU * high * time)) * 0.5 * envelope * volume
		_write_sample(data, i, wave)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream

## A seamless ambient loop: notes cycle every `step` seconds, each softened by its
## own decay so the phrase feels like gentle synth arpeggios rather than beeps.
## A fifth below each note keeps the bed warm without crowding the top line.
## Higher `sustain` values click-free loop; lower ones ring (used for one-shots).
static func arpeggio(notes: Array, step: float, volume: float = 0.3, sustain: float = 6.0) -> AudioStreamWAV:
	var samples := int(notes.size() * step * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var time := float(i) / MIX_RATE
		var note_index := mini(int(time / step), notes.size() - 1)
		var note_time := time - note_index * step
		var freq := float(notes[note_index])
		# Decay fast enough that each note is silent before the next starts,
		# so the loop has no clicks at note boundaries.
		var envelope := exp(-sustain * note_time / step)
		var wave := sin(TAU * freq * note_time) + sin(TAU * freq * 0.5 * note_time) * 0.45
		_write_sample(data, i, wave * envelope * volume)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream

## Builds a soft, seamlessly looping chill-out bed from a chord progression.
##
## Every bar renders three layers: a warm, gently detuned stereo pad, a rounded
## sub-bass root and a sparse bell melody picked from `melody` (a pentatonic set
## that sits comfortably over every chord). The progression is repeated `repeats`
## times so a four-chord loop becomes a longer, unhurried phrase.
##
## Voices are mixed with wrap-around at the loop point, so their long release
## tails continue seamlessly into the repeat instead of clicking, and the whole
## mix is peak-normalised so no amount of layering can clip.
##
## `spec` keys: progression (Array of `{bass, chord}` bars), bar_seconds,
## repeats, melody, volume, seed.
static func chillout(spec: Dictionary) -> AudioStreamWAV:
	var progression: Array = spec["progression"]
	var bar_seconds: float = spec["bar_seconds"]
	var repeats: int = int(spec.get("repeats", 2))
	var melody: Array = spec.get("melody", [])
	var volume: float = float(spec.get("volume", 0.35))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.get("seed", 1010))

	var bars := progression.size() * repeats
	var left := _blank(int(round(bars * bar_seconds * MUSIC_RATE)))
	var right := _blank(left.size())

	# Pad and bass depend only on the chord, so render one pass of the
	# progression and tile it across the repeats instead of rebuilding it.
	var phrase := int(round(progression.size() * bar_seconds * MUSIC_RATE))
	var pad_left := _blank(phrase)
	var pad_right := _blank(phrase)
	for slot in progression.size():
		var bar: Dictionary = progression[slot]
		var start := slot * bar_seconds
		_render_pad(pad_left, pad_right, start, bar_seconds, bar["chord"])
		_render_bass(pad_left, pad_right, start, bar_seconds, bar["bass"])
	for i in left.size():
		left[i] = pad_left[i % phrase]
		right[i] = pad_right[i % phrase]

	# The melody runs across the whole loop so it changes between repeats.
	for slot in bars:
		_render_bells(left, right, slot * bar_seconds, bar_seconds, melody, rng)

	return _encode_stereo(left, right, volume)

## A warm chord pad. Each tone is duplicated with a tiny detune and panned to
## opposite sides, so the pair beats slowly and fills the stereo field.
static func _render_pad(l: PackedFloat32Array, r: PackedFloat32Array, start: float, dur: float, tones: Array) -> void:
	for tone in tones:
		var freq := float(tone)
		_mix_voice(l, r, start, dur * 1.7, freq * 1.004, 0.16, -0.55, "pad")
		_mix_voice(l, r, start, dur * 1.7, freq * 0.996, 0.16, 0.55, "pad")

## The bass root sits an octave below the pad: warmth without muddiness.
static func _render_bass(l: PackedFloat32Array, r: PackedFloat32Array, start: float, dur: float, root: float) -> void:
	_mix_voice(l, r, start, dur * 1.4, float(root), 0.30, 0.0, "bass")

## An impromptu bell melody: one or two quiet, widely panned notes per bar, so the
## bed evolves instead of repeating verbatim.
static func _render_bells(l: PackedFloat32Array, r: PackedFloat32Array, start: float, dur: float, melody: Array, rng: RandomNumberGenerator) -> void:
	if melody.is_empty():
		return
	for _i in rng.randi_range(1, 2):
		var freq := float(melody[rng.randi_range(0, melody.size() - 1)])
		if rng.randf() < 0.3:
			freq *= 2.0
		var offset := rng.randf_range(0.0, dur * 0.7)
		var pan := rng.randf_range(-0.75, 0.75)
		_bell(l, r, start + offset, dur * 2.2, freq, 0.10, pan)

## A soft mallet: a sine fundamental plus two quiet, faster-decaying partials.
static func _bell(l: PackedFloat32Array, r: PackedFloat32Array, start: float, dur: float, freq: float, gain: float, pan: float) -> void:
	_mix_voice(l, r, start, dur, freq, gain, pan, "bell")
	_mix_voice(l, r, start, dur * 0.5, freq * 2.0, gain * 0.22, pan, "bell")
	_mix_voice(l, r, start, dur * 0.3, freq * 3.0, gain * 0.08, pan, "bell")

## Mixes one enveloped sine into the stereo loop. The write index wraps past the
## end so long tails continue seamlessly into the repeat. `pan` is -1 (left) to
## 1 (right) with constant-power gains.
##
## The sine is generated by the recurrence y[n] = 2cos(w)·y[n−1] − y[n−2] and the
## envelope is advanced with precomputed slopes, because calling sin()/exp() once
## per sample is far too slow to build a multi-second bed during startup.
static func _mix_voice(l: PackedFloat32Array, r: PackedFloat32Array, start: float, dur: float, freq: float, gain: float, pan: float, shape: String) -> void:
	var loop := l.size()
	var total := int(round(dur * MUSIC_RATE))
	if total <= 0 or total > loop:
		return
	var index := int(round(start * MUSIC_RATE)) % loop
	var left_gain := gain * sqrt(0.5 * (1.0 - pan))
	var right_gain := gain * sqrt(0.5 * (1.0 + pan))

	var omega := TAU * freq / MUSIC_RATE
	var two_cos := 2.0 * cos(omega)
	var previous := -sin(omega)
	var value := 0.0

	# Envelope constants, hoisted so the hot loop only multiplies and adds.
	var strike := shape == "bell"
	var ring := 0.0
	var attack_steps := 0
	var attack_slope := 0.0
	var attack_seconds := 0.0
	var release_start := 0.0
	var inv_attack := 0.0
	var inv_release := 0.0
	var decay_rate := 0.0
	var env := 1.0
	var time := 0.0
	var time_step := 1.0 / MUSIC_RATE
	if strike:
		var attack := 0.006
		attack_seconds = attack
		attack_steps = int(attack * MUSIC_RATE)
		attack_slope = 1.0 / (attack * MUSIC_RATE)
		ring = exp(-4.0 / (MUSIC_RATE * dur))
	else:
		var attack := dur * (0.05 if shape == "bass" else 0.3)
		var release := dur * (0.4 if shape == "bass" else 0.45)
		attack_seconds = attack
		inv_attack = 1.0 / attack
		inv_release = 1.0 / release
		decay_rate = 0.25 / dur
		release_start = dur - release

	for n in total:
		if strike:
			env = n * attack_slope if n <= attack_steps else env * ring
		else:
			var base := time * inv_attack if time < attack_seconds else 1.0
			if time > release_start:
				base = minf(base, (dur - time) * inv_release)
			env = base * (1.0 - decay_rate * time)
		if env > 0.0:
			var sample := value * env
			l[index] += sample * left_gain
			r[index] += sample * right_gain
		var upcoming := two_cos * value - previous
		previous = value
		value = upcoming
		time += time_step
		index += 1
		if index == loop:
			index = 0

## Peak-normalises the mix so stacking voices can never clip, then encodes it as
## interleaved 16-bit stereo PCM with a forward loop.
static func _encode_stereo(l: PackedFloat32Array, r: PackedFloat32Array, volume: float) -> AudioStreamWAV:
	var peak := 0.0
	for i in l.size():
		peak = maxf(peak, maxf(absf(l[i]), absf(r[i])))
	var scale := volume / peak if peak > 0.0 else 0.0
	var data := PackedByteArray()
	data.resize(l.size() * 4)
	for i in l.size():
		_write_stereo(data, i, l[i] * scale, r[i] * scale)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MUSIC_RATE
	stream.stereo = true
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	# loop_end is measured in frames (one L/R pair each). Leaving it at 0 makes the
	# player terminate after the first frame, so it must be the frame count.
	stream.loop_end = l.size()
	return stream

static func _blank(size: int) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(size)
	return buffer

static func _write_stereo(data: PackedByteArray, index: int, left: float, right: float) -> void:
	var left_sample := clampi(int(round(left * 32767.0)), -32768, 32767)
	var right_sample := clampi(int(round(right * 32767.0)), -32768, 32767)
	var offset := index * 4
	data[offset] = left_sample & 0xFF
	data[offset + 1] = (left_sample >> 8) & 0xFF
	data[offset + 2] = right_sample & 0xFF
	data[offset + 3] = (right_sample >> 8) & 0xFF

static func _write_sample(data: PackedByteArray, index: int, value: float) -> void:
	var clamped := clampi(int(round(value * 32767.0)), -32768, 32767)
	data[index * 2] = clamped & 0xFF
	data[index * 2 + 1] = (clamped >> 8) & 0xFF
