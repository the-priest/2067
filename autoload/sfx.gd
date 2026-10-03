extends Node
## Every sound in the game is synthesised here at startup: gunshots that
## roll across the valley, footsteps, the hybrids' calls (Earth animal with
## something wrong in it), wind, heartbeats. No audio files to ship.

const RATE := 22050

var bank: Dictionary = {}
var _pool: Array = []
var _wind: AudioStreamPlayer = null
var _pad: AudioStreamPlayer = null


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_make_all()
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	print("SFX %d sounds in %d ms" % [bank.size(), Time.get_ticks_msec() - t0])


func play(n: String, db: float = 0.0, pitch: float = 1.0) -> void:
	if not bank.has(n):
		return
	for p in _pool:
		var ap := p as AudioStreamPlayer
		if not ap.playing:
			ap.stream = bank[n]
			ap.volume_db = db
			ap.pitch_scale = pitch
			ap.play()
			return


## A sound out in the world. Far sounds arrive late (343 m/s), so a distant
## shot's crack lands after you see the flash.
func play_at(n: String, pos: Vector3, db: float = 0.0, range_m: float = 80.0, pitch: float = 1.0, parent: Node = null) -> void:
	if not bank.has(n):
		return
	var host: Node = parent if parent != null else get_tree().current_scene
	if host == null:
		return
	var ap := AudioStreamPlayer3D.new()
	ap.stream = bank[n]
	ap.volume_db = db
	ap.unit_size = range_m * 0.12
	ap.max_distance = range_m * 4.0
	ap.pitch_scale = pitch
	ap.attenuation_filter_cutoff_hz = 5000.0
	ap.attenuation_filter_db = -18.0
	host.add_child(ap)
	ap.global_position = pos
	var cam := get_viewport().get_camera_3d()
	var delay := 0.0
	if cam != null:
		delay = cam.global_position.distance_to(pos) / 343.0
	if delay > 0.05:
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_instance_valid(ap):
				ap.play())
	else:
		ap.play()
	ap.finished.connect(ap.queue_free)
	get_tree().create_timer(delay + 8.0).timeout.connect(func() -> void:
		if is_instance_valid(ap):
			ap.queue_free())


func ambience(on: bool, night: bool = false) -> void:
	if _wind == null:
		_wind = AudioStreamPlayer.new()
		_wind.stream = bank["wind"]
		_wind.volume_db = -14.0
		add_child(_wind)
		_pad = AudioStreamPlayer.new()
		_pad.stream = bank["pad"]
		_pad.volume_db = -22.0
		add_child(_pad)
	if on:
		if not _wind.playing:
			_wind.play()
			_pad.play()
		_pad.volume_db = -17.0 if night else -24.0
	else:
		_wind.stop()
		_pad.stop()


func wind_level(strength: float) -> void:
	if _wind != null:
		_wind.volume_db = lerpf(-22.0, -8.0, clampf(strength, 0.0, 1.0))


# ------------------------------------------------------------------ synth

func _make_all() -> void:
	seed(7)
	bank["rifle"] = _shot(0.9, 58.0, 1.4, 1.0)
	bank["big"] = _shot(1.0, 42.0, 1.9, 1.3)
	bank["rail"] = _rail()
	bank["coil"] = _coil()
	bank["plasma"] = _plasma()
	bank["click"] = _click(0.03, 2400.0)
	bank["bolt"] = _bolt()
	bank["lever"] = _lever()
	bank["load"] = _click(0.05, 1400.0)
	bank["step"] = _step(0.09, 0.12)
	bank["step_soft"] = _step(0.07, 0.06)
	bank["impact"] = _impact()
	bank["heart"] = _heartbeat()
	bank["wind"] = _windloop()
	bank["pad"] = _padloop()
	bank["ui"] = _click(0.025, 3200.0)
	bank["cash"] = _cash()
	bank["rank"] = _chime()
	bank["harvest"] = _harvest()
	bank["moo"] = _call(1.6, 105.0, 0.55, 0.8, 0.0, 0.4)
	bank["bugle"] = _bugle()
	bank["grunt"] = _grunt()
	bank["bleat"] = _call(0.8, 330.0, 0.2, 7.0, 0.04, 0.5)
	bank["bellow"] = _call(2.2, 72.0, 0.25, 1.2, 0.0, 0.9)
	bank["howl"] = _howl()
	bank["snort"] = _snort()
	bank["drone"] = _droneloop()
	bank["thud"] = _impact(0.25, 50.0)
	bank["scanner"] = _beep()


func _wav(buf: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	var peak := 0.001
	for s in buf:
		peak = maxf(peak, absf(s))
	var g := 0.92 / peak if peak > 0.92 else 1.0
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i] * g, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b


## A rifle: the supersonic crack, the boom, the long rolling tail off the hills.
func _shot(sec: float, boom_hz: float, tail: float, weight: float) -> AudioStreamWAV:
	var b := _buf(sec + tail)
	var lp := 0.0
	var lp2 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var n := randf_range(-1.0, 1.0)
		var crack := n * exp(-t * 90.0)
		lp += (n - lp) * 0.08
		lp2 += (lp - lp2) * 0.05
		var boom := sin(TAU * boom_hz * t * (1.0 - t * 0.6)) * exp(-t * 9.0 / weight) * 1.4
		var body := lp * exp(-t * 14.0) * 3.0
		# Echo off the far hills: a softer copy, then the rumble.
		var echo := 0.0
		var te := t - 0.38
		if te > 0.0:
			echo = lp2 * exp(-te * 2.6 / tail) * 4.0
		b[i] = crack * 0.9 + boom * weight + body + echo
	return _wav(b)


func _rail() -> AudioStreamWAV:
	var b := _buf(2.0)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var n := randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.06
		var whine := sin(TAU * (2600.0 - t * 900.0) * t) * exp(-t * 2.2) * 0.35
		var zap := n * exp(-t * 40.0)
		var boom := sin(TAU * 48.0 * t) * exp(-t * 6.0) * 1.2
		var roll := lp * exp(-t * 1.6) * 3.5
		b[i] = whine + zap + boom + roll
	return _wav(b)


func _coil() -> AudioStreamWAV:
	var b := _buf(0.35)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 300.0 + 2600.0 * minf(1.0, t / 0.06)
		ph += TAU * f / RATE
		var env := exp(-t * 18.0)
		b[i] = (sin(ph) * 0.5 + randf_range(-1.0, 1.0) * 0.15 * exp(-t * 60.0)) * env * 0.6
	return _wav(b)


func _plasma() -> AudioStreamWAV:
	var b := _buf(0.9)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 900.0 * exp(-t * 4.0) + 70.0
		ph += TAU * f / RATE
		var saw := fmod(ph / TAU, 1.0) * 2.0 - 1.0
		lp += (randf_range(-1.0, 1.0) - lp) * 0.1
		b[i] = (saw * 0.6 + lp * 2.0) * exp(-t * 3.5) * minf(1.0, t * 80.0)
	return _wav(b)


func _click(sec: float, hz: float) -> AudioStreamWAV:
	var b := _buf(sec)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (sin(TAU * hz * t) * 0.6 + randf_range(-1.0, 1.0) * 0.4) * exp(-t * 120.0)
	return _wav(b)


func _bolt() -> AudioStreamWAV:
	var b := _buf(0.5)
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		for c: float in [0.0, 0.18, 0.32]:
			var tc: float = t - c
			if tc >= 0.0:
				s += (sin(TAU * 1800.0 * tc) * 0.4 + randf_range(-1, 1) * 0.6) * exp(-tc * 90.0)
		b[i] = s
	return _wav(b)


func _lever() -> AudioStreamWAV:
	var b := _buf(0.45)
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		for c: float in [0.0, 0.22]:
			var tc: float = t - c
			if tc >= 0.0:
				s += (sin(TAU * 1300.0 * tc) * 0.5 + randf_range(-1, 1) * 0.5) * exp(-tc * 70.0)
		b[i] = s
	return _wav(b)


func _step(sec: float, cut: float) -> AudioStreamWAV:
	var b := _buf(sec)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * cut
		b[i] = lp * exp(-t * 40.0) * minf(1.0, t * 400.0) * 3.0
	return _wav(b)


func _impact(sec: float = 0.18, hz: float = 90.0) -> AudioStreamWAV:
	var b := _buf(sec)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.2
		b[i] = (sin(TAU * hz * t) * 1.2 + lp * 1.5) * exp(-t * 25.0)
	return _wav(b)


func _heartbeat() -> AudioStreamWAV:
	var b := _buf(0.9)
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		for c: float in [0.0, 0.28]:
			var tc: float = t - c
			if tc >= 0.0:
				s += sin(TAU * 48.0 * tc) * exp(-tc * 18.0) * (1.0 if c == 0.0 else 0.7)
		b[i] = s
	return _wav(b)


func _windloop() -> AudioStreamWAV:
	var sec := 8.0
	var b := _buf(sec)
	var lp := 0.0
	var lp2 := 0.0
	var n := b.size()
	for i in n:
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.02
		lp2 += (lp - lp2) * 0.15
		var gust := 0.6 + 0.4 * sin(TAU * t / sec * 2.0) * sin(TAU * t / sec * 3.0 + 1.0)
		b[i] = lp2 * 6.0 * gust
	# Crossfade the end into the start so the loop doesn't click.
	var xf := int(RATE * 0.5)
	for i in xf:
		var a := float(i) / xf
		b[i] = b[i] * a + b[n - xf + i] * (1.0 - a)
	b.resize(n - xf)
	return _wav(b, true)


## The valley's hum: low detuned tones that drift, a little wrong.
func _padloop() -> AudioStreamWAV:
	var sec := 12.0
	var b := _buf(sec)
	var freqs := [55.0, 82.5, 110.25, 164.0, 207.0]
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		for k in freqs.size():
			var f: float = freqs[k]
			# Whole cycles per loop keep it seamless.
			f = round(f * sec) / sec
			var lfo := 0.5 + 0.5 * sin(TAU * t * float(k + 1) / sec)
			s += sin(TAU * f * t) * lfo * (0.5 / float(k + 1))
		b[i] = s
	return _wav(b, true)


func _cash() -> AudioStreamWAV:
	var b := _buf(0.6)
	for i in b.size():
		var t := float(i) / RATE
		var s := sin(TAU * 1320.0 * t) * exp(-t * 6.0) * 0.5
		if t > 0.08:
			s += sin(TAU * 1760.0 * (t - 0.08)) * exp(-(t - 0.08) * 6.0) * 0.5
		b[i] = s
	return _wav(b)


func _chime() -> AudioStreamWAV:
	var b := _buf(1.6)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		for k in notes.size():
			var tk: float = t - k * 0.12
			if tk > 0.0:
				s += sin(TAU * float(notes[k]) * tk) * exp(-tk * 3.0) * 0.4
		b[i] = s
	return _wav(b)


func _harvest() -> AudioStreamWAV:
	var b := _buf(1.2)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.25
		var saw := 0.5 + 0.5 * sin(TAU * 3.2 * t)
		b[i] = lp * saw * 1.6 * minf(1.0, (1.2 - t) * 4.0)
	return _wav(b)


## An animal's voice with something else in it: a pitched call with vibrato,
## a nasal formant, and a ring-modulated alien overtone that warbles in.
func _call(sec: float, f0: float, glide: float, vib: float, noise: float, alien: float) -> AudioStreamWAV:
	var b := _buf(sec)
	var ph := 0.0
	var ph2 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var u := t / sec
		var f := f0 * (1.0 + glide * sin(PI * u)) * (1.0 + 0.02 * sin(TAU * vib * t))
		ph += TAU * f / RATE
		ph2 += TAU * f * 2.73 / RATE
		var env := sin(PI * minf(1.0, u * 1.15)) * minf(1.0, t * 20.0)
		var tone := sin(ph) + 0.5 * sin(ph * 2.0) + 0.35 * sin(ph * 3.0) + 0.2 * sin(ph * 5.0)
		var ring := sin(ph2) * sin(TAU * 5.0 * t) * alien * u
		b[i] = (tone * 0.5 + ring * 0.6 + randf_range(-1.0, 1.0) * noise) * env
	return _wav(b)


func _bugle() -> AudioStreamWAV:
	var b := _buf(2.0)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var u := t / 2.0
		var f := 380.0 + 1100.0 * sin(PI * minf(1.0, u * 1.6)) * (1.0 if u < 0.62 else 0.4)
		ph += TAU * f / RATE
		var env := minf(1.0, t * 8.0) * exp(-maxf(0.0, t - 1.2) * 4.0)
		b[i] = (sin(ph) * 0.6 + sin(ph * 2.0) * 0.25 + randf_range(-1.0, 1.0) * 0.18 + sin(ph * 1.5) * sin(TAU * 31.0 * t) * 0.3) * env
	return _wav(b)


func _grunt() -> AudioStreamWAV:
	var b := _buf(0.9)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.12
		var pulse := maxf(0.0, sin(TAU * 78.0 * t)) ** 3.0
		var env := 0.0
		for c: float in [0.0, 0.3, 0.55]:
			var tc: float = t - c
			if tc >= 0.0:
				env += exp(-tc * 9.0) * minf(1.0, tc * 60.0)
		b[i] = (pulse * 1.4 + lp * 1.2) * env
	return _wav(b)


func _snort() -> AudioStreamWAV:
	var b := _buf(0.5)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.3
		b[i] = lp * 2.0 * exp(-t * 7.0) * minf(1.0, t * 50.0)
	return _wav(b)


func _howl() -> AudioStreamWAV:
	var b := _buf(3.0)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var u := t / 3.0
		var f := 380.0 + 320.0 * sin(PI * minf(1.0, u * 1.3)) + 8.0 * sin(TAU * 5.5 * t)
		ph += TAU * f / RATE
		var env := sin(PI * u) * minf(1.0, t * 5.0)
		b[i] = (sin(ph) * 0.7 + sin(ph * 2.0) * 0.2 + sin(ph * 1.414) * sin(TAU * 9.0 * t) * 0.25 * u) * env
	return _wav(b)


func _droneloop() -> AudioStreamWAV:
	var sec := 2.0
	var b := _buf(sec)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (sin(TAU * 180.0 * t) * 0.4 + sin(TAU * 361.0 * t) * 0.25 + randf_range(-1, 1) * 0.08)
	return _wav(b, true)


func _beep() -> AudioStreamWAV:
	var b := _buf(0.12)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * 1900.0 * t) * minf(1.0, (0.12 - t) * 60.0) * 0.5
	return _wav(b)
