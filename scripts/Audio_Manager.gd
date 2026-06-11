extends Node

# musica e efeitos sonoros

const SAVE_PATH = "user://audio_config.cfg"

const MUSIC = {
	"home":      "res://audio/music/music_home.ogg",
	"tabuleiro": "res://audio/music/music_tabuleiro.ogg",
	"bioma1":    "res://audio/music/music_bioma1.ogg",
	"bioma2":    "res://audio/music/music_bioma2.ogg",
	"bioma3":    "res://audio/music/music_bioma3.ogg",
	"bioma4":    "res://audio/music/music_bioma4.ogg",
	"boss":      "res://audio/music/music_boss.ogg",
	"vitoria":   "res://audio/music/music_vitoria.ogg",
}

const SFX = {
	"acerto":       "res://audio/sfx/sfx_acerto.ogg",
	"erro":         "res://audio/sfx/sfx_erro.ogg",
	"level_up":     "res://audio/sfx/sfx_level_up.ogg",
	"badge":        "res://audio/sfx/sfx_badge.ogg",
	"compra":       "res://audio/sfx/sfx_compra.ogg",
	"click":        "res://audio/sfx/sfx_click.ogg",
	"dano_heroi":   "res://audio/sfx/sfx_dano_heroi.ogg",
	"dano_boss":    "res://audio/sfx/sfx_dano_boss.ogg",
	"boss_derrota": "res://audio/sfx/sfx_boss_derrota.ogg",
	"estrela":      "res://audio/sfx/sfx_estrela.ogg",
	"avanco":       "res://audio/sfx/sfx_avanco.ogg",
}

var _music_player: AudioStreamPlayer = null
var _music_volume: float = 0.8
var _sfx_volume: float = 1.0
var _music_muted: bool = false
var _sfx_muted: bool = false
var _current_music: String = ""

func _ready():
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	_load_config()
	_apply_volume()

# musica

func play_music(key: String, force: bool = false) -> void:
	if key == _current_music and not force:
		return
	if not MUSIC.has(key):
		return
	var path = MUSIC[key]
	if not ResourceLoader.exists(path):
		return
	_music_player.stream = load(path)
	_music_player.play()
	_current_music = key

func stop_music() -> void:
	_music_player.stop()
	_current_music = ""

func set_music_volume(value: float) -> void:
	_music_volume = clamp(value, 0.0, 1.0)
	_apply_volume()
	_save_config()

func toggle_music_mute() -> void:
	_music_muted = not _music_muted
	_apply_volume()
	_save_config()

# sfx

func play_sfx(key: String) -> void:
	if _sfx_muted or not SFX.has(key):
		return
	var path = SFX[key]
	if not ResourceLoader.exists(path):
		return
	var player = AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = load(path)
	player.volume_db = linear_to_db(_sfx_volume)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func set_sfx_volume(value: float) -> void:
	_sfx_volume = clamp(value, 0.0, 1.0)
	_save_config()

func toggle_sfx_mute() -> void:
	_sfx_muted = not _sfx_muted
	_save_config()

# config

func _apply_volume() -> void:
	var vol = linear_to_db(_music_volume) if not _music_muted else -80.0
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), vol)

func _save_config() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "music_volume", _music_volume)
	cfg.set_value("audio", "sfx_volume",   _sfx_volume)
	cfg.set_value("audio", "music_muted",  _music_muted)
	cfg.set_value("audio", "sfx_muted",    _sfx_muted)
	cfg.save(SAVE_PATH)

func _load_config() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	_music_volume = cfg.get_value("audio", "music_volume", 0.8)
	_sfx_volume   = cfg.get_value("audio", "sfx_volume",   1.0)
	_music_muted  = cfg.get_value("audio", "music_muted",  false)
	_sfx_muted    = cfg.get_value("audio", "sfx_muted",    false)
