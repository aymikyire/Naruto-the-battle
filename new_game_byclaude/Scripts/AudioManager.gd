extends Node

# AudioManager - 音效与背景音乐管理器
# 使用 music/ 目录下的真实音频文件 + 无对应文件时用程序化生成

# ---------- 音频总线 ----------
const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

# ---------- 预加载音频资源 ----------
const SFX_SWING      := preload("res://music/swing.mp3")
const SFX_WHOOSH     := preload("res://music/whoosh.mp3")
const SFX_SHOOT      := preload("res://music/shoot.wav")
const SFX_RASENGAN   := preload("res://music/rasengan.mp3")
const SFX_HURT       := preload("res://music/hurt.ogg")
const BGM_STREAM     := preload("res://music/bgm.mp3")

# ---------- 播放器 ----------
var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer2D] = []
var _sfx_index := 0
const POOL_SIZE := 10

# ---------- 音效库 ----------
var _sounds := {}

func _ready():
	_setup_audio_buses()

	# 创建 BGM 播放器
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = BUS_MUSIC
	_music_player.volume_db = -8.0
	add_child(_music_player)

	# 创建 SFX 播放器池
	for i in range(POOL_SIZE):
		var p = AudioStreamPlayer2D.new()
		p.bus = BUS_SFX
		p.max_distance = 300.0
		p.attenuation = 1.5
		add_child(p)
		_sfx_pool.append(p)

	# 构建音效库（真实文件 + 生成兜底）
	_build_sound_library()

	# 启动 BGM
	_start_bgm()

func _build_sound_library():
	# --- 有真实音频文件 ---
	_sounds["swing"]    = SFX_SWING      # 普通攻击音效
	_sounds["whoosh"]   = SFX_WHOOSH     # 佐助特殊普攻效果(冲刺)
	_sounds["shoot"]    = SFX_SHOOT      # 火球术音效后1s
	_sounds["rasengan"] = SFX_RASENGAN   # 螺旋丸音效
	_sounds["hurt"]     = SFX_HURT       # 受伤音效

	# --- 无对应文件 → 程序化生成 ---
	_sounds["hit"] = _make_tone_sfx(0.08, 0.6, 120.0, 120.0)
	_sounds["poof"] = _make_noise_sfx(0.2, 0.5, 300.0, 3000.0)
	_sounds["pickup"] = _make_chime_sfx(0.25, 0.5, [400.0, 600.0, 800.0])
	_sounds["death"] = _make_sweep_sfx(0.6, 0.6, 400.0, 80.0)
	_sounds["base_hit"] = _make_noise_sfx(0.15, 0.6, 60.0, 200.0)
	_sounds["base_destroy"] = _make_sweep_sfx(0.8, 0.7, 300.0, 40.0)
	_sounds["game_over"] = _make_game_over_sfx()
	_sounds["game_start"] = _make_chime_sfx(0.6, 0.5, [400.0, 550.0, 700.0, 900.0])

# ==================== WAV 合成工具函数（兜底用） ====================

func _make_tone_sfx(duration: float, volume: float, freq_start: float, freq_end: float, loop: bool = false) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in range(num_samples):
		var t := float(i) / sample_rate
		var freq := freq_start + (freq_end - freq_start) * (t / duration)
		var env := _envelope(t, duration, 0.005, 0.03)
		var sample := sin(2.0 * PI * freq * t) * env * volume
		_write_sample(data, i, sample)
	return _make_wav(data, sample_rate, loop)

func _make_noise_sfx(duration: float, volume: float, low_cut: float, high_cut: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in range(num_samples):
		var t := float(i) / sample_rate
		var env := _envelope(t, duration, 0.002, 0.05)
		var noise := randf_range(-1.0, 1.0)
		var cutoff_ratio: float = clamp((high_cut - low_cut) / 2000.0, 0.0, 1.0)
		noise *= cutoff_ratio * 2.0
		var sample := noise * env * volume * 0.5
		_write_sample(data, i, sample)
	return _make_wav(data, sample_rate, false)

func _make_sweep_sfx(duration: float, volume: float, freq_start: float, freq_end: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	var phase := 0.0
	for i in range(num_samples):
		var t := float(i) / sample_rate
		var freq := freq_start + (freq_end - freq_start) * (t / duration)
		var env := _envelope(t, duration, 0.005, 0.05)
		phase += 2.0 * PI * freq / sample_rate
		var sample := sin(phase) * env * volume
		_write_sample(data, i, sample)
	return _make_wav(data, sample_rate, false)

func _make_chime_sfx(duration: float, volume: float, freqs: Array[float]) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in range(num_samples):
		var t := float(i) / sample_rate
		var env := _envelope(t, duration, 0.005, duration * 0.3)
		var sample := 0.0
		for j in range(freqs.size()):
			sample += sin(2.0 * PI * freqs[j] * t) * (1.0 / (j + 1))
		sample = sample / freqs.size() * env * volume
		_write_sample(data, i, sample)
	return _make_wav(data, sample_rate, false)

func _make_game_over_sfx() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 1.2
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in range(num_samples):
		var t := float(i) / sample_rate
		var env := _envelope(t, duration, 0.01, 0.4)
		var s1 := sin(2.0 * PI * (400.0 - 300.0 * t / duration) * t)
		var s2 := sin(2.0 * PI * (300.0 - 200.0 * t / duration) * t) * 0.5
		_write_sample(data, i, (s1 + s2) * env * 0.5)
	return _make_wav(data, sample_rate, false)

func _envelope(t: float, duration: float, attack: float, release: float) -> float:
	if t < attack: return t / attack
	elif t > duration - release: return max(0.0, (duration - t) / release)
	else: return 1.0

func _write_sample(data: PackedByteArray, index: int, sample: float):
	var s16 := int(clamp(sample * 32767.0, -32768.0, 32767.0))
	var pos := index * 2
	data[pos] = s16 & 0xFF
	data[pos + 1] = (s16 >> 8) & 0xFF

func _make_wav(data: PackedByteArray, sample_rate: int, loop: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = data.size() / 2
	return wav

# ==================== 播放接口 ====================

func play_sfx(name: String, position: Vector2 = Vector2.ZERO):
	if not _sounds.has(name):
		push_warning("AudioManager: 未知音效 '" + name + "'")
		return
	var stream = _sounds[name]
	var player = _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % POOL_SIZE
	player.stream = stream
	player.global_position = position
	player.play(0.0)

func play_sfx_global(name: String):
	if not _sounds.has(name):
		push_warning("AudioManager: 未知音效 '" + name + "'")
		return
	var stream = _sounds[name]
	var player = _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % POOL_SIZE
	player.stream = stream
	player.global_position = Vector2.ZERO
	player.play(0.0)

# ==================== BGM ====================

func _start_bgm():
	_music_player.stream = BGM_STREAM
	_music_player.play(0.0)

func set_bgm_volume(db: float):
	_music_player.volume_db = db

# ==================== 音频总线 ====================

func _setup_audio_buses():
	_find_or_create_bus("Music")
	_find_or_create_bus("SFX")

func _find_or_create_bus(name: String) -> int:
	var server = AudioServer
	var idx = server.get_bus_index(name)
	if idx >= 0:
		return idx
	server.add_bus()
	idx = server.get_bus_count() - 1
	server.set_bus_name(idx, name)
	server.set_bus_volume_db(idx, 0.0)
	return idx
