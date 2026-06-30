extends Control
#
# ============================================================
#  FinalScene.gd
#  Tela final cinematográfica (mobile / portrait 1080x1920)
#  Fundo PRETO + partículas suaves. Sprite real de celebração.
# ============================================================
#  Sequência aproximada (~13 segundos):
#
#    0.0s  Tela 100% preta
#    1.0s  Fade-in suave + partículas suaves ligam. Música começa (se atribuída).
#    2.2s  "PARABÉNS!" entra com fade + scale bouncy + shimmer dourado
#    3.9s  "Você terminou o jogo." digitada letra a letra
#    5.3s  Personagem (joinha) aparece: fade + subida + leve scale
#    6.5s  Celebração: aura acende + burst de sparkles + bounce + SFX
#    7.9s  "Obrigado por jogar." faz fade-in
#    8.9s  Pausa emocional (~3s) — aura pulsando, partículas subindo
#   12.1s  Fade-out final cinematográfico para preto
#   14.3s  Próxima cena (se configurada)
# ============================================================


# ---------- TEXTOS (TROQUE AQUI) ----------
const TITLE_TEXT: String   = "PARABÉNS!"
const MESSAGE_TEXT: String = "Você terminou o jogo."
const THANKS_TEXT: String  = "Obrigado por jogar."

# ---------- DURAÇÕES (TROQUE AQUI para ajustar o ritmo) ----------
const INITIAL_BLACK_HOLD: float      = 1.0
const BG_FADE_IN: float              = 1.2
const TITLE_FADE_IN: float           = 1.0
const PAUSE_AFTER_TITLE: float       = 0.3
const MESSAGE_TYPE_SPEED: float      = 0.055
const PAUSE_BEFORE_CHARACTER: float  = 0.45
const CHARACTER_FADE_IN: float       = 1.0
const PAUSE_BEFORE_CELEBRATION: float = 0.25
const THANKS_FADE_IN: float          = 1.0
const EMOTIONAL_PAUSE: float         = 3.0
const FINAL_FADE_OUT: float          = 2.2
const CINEMATIC_ZOOM_DURATION: float = 13.0
const CINEMATIC_ZOOM_TARGET: float   = 1.04

# ---------- PRÓXIMA CENA (TROQUE AQUI) ----------
# Caminho da cena chamada DEPOIS do fade final.
# Deixe "" para apenas terminar (tela fica preta).
# Exemplos:
#   const NEXT_SCENE_PATH := "res://MainMenu.tscn"
#   const NEXT_SCENE_PATH := "res://Credits.tscn"
const NEXT_SCENE_PATH: String = "res://scenes/ui/Menu/MainMenu.tscn"


# ---------- Referências de nó ----------
@onready var ambience: CPUParticles2D       = $AmbienceParticles
@onready var content_root: Control          = $ContentRoot
@onready var title_label: Label             = $ContentRoot/TitleLabel
@onready var message_label: Label           = $ContentRoot/MessageLabel
@onready var character_container: Control   = $ContentRoot/CharacterContainer
@onready var glow_aura: TextureRect         = $ContentRoot/CharacterContainer/GlowAura
@onready var character_sprite: TextureRect  = $ContentRoot/CharacterContainer/CharacterSprite
@onready var sparkles: CPUParticles2D       = $ContentRoot/CharacterContainer/CelebrationSparkles
@onready var thanks_label: Label            = $ContentRoot/ThanksLabel
@onready var music_player: AudioStreamPlayer    = $Audio/MusicPlayer
@onready var achievement_sfx: AudioStreamPlayer = $Audio/AchievementSfx
@onready var fade_sfx: AudioStreamPlayer        = $Audio/FadeSfx
@onready var fade_rect: ColorRect           = $FadeLayer/FadeRect
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _character_base_y: float = 0.0


func _ready() -> void:
	# Espera 1 frame para que o layout dos Controls (anchors -> size)
	# esteja resolvido antes de medirmos size para o pivot_offset.
	await get_tree().process_frame
	_reset_initial_state()
	start_final_sequence()


# Estado inicial: tudo invisível, tela coberta de preto.
func _reset_initial_state() -> void:
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.modulate.a = 1.0

	# Título
	title_label.text = TITLE_TEXT
	title_label.modulate = Color(1, 1, 1, 0)
	title_label.pivot_offset = title_label.size / 2.0
	title_label.scale = Vector2(0.82, 0.82)

	# Mensagem (digitada depois)
	message_label.text = ""

	# Texto final
	thanks_label.text = THANKS_TEXT
	thanks_label.modulate = Color(1, 1, 1, 0)

	# Personagem invisível, deslocado para baixo
	_character_base_y = character_container.position.y
	character_container.position.y = _character_base_y + 55.0
	character_container.modulate.a = 1.0
	character_container.pivot_offset = character_container.size / 2.0
	character_container.scale = Vector2(0.96, 0.96)

	character_sprite.modulate.a = 0.0
	glow_aura.modulate.a = 0.0

	# Partículas paradas
	ambience.emitting = false
	sparkles.emitting = false

	# ContentRoot com pivot central para o slow zoom cinematográfico
	content_root.pivot_offset = content_root.size / 2.0
	content_root.scale = Vector2(1.0, 1.0)


# Orquestra toda a sequência cinematográfica.
func start_final_sequence() -> void:
	_safe_play(music_player)

	# 1) Tela 100% preta
	await get_tree().create_timer(INITIAL_BLACK_HOLD).timeout

	# 2a) Slow zoom cinematográfico (paralelo de fundo — NÃO awaited)
	var zoom := create_tween()
	zoom.tween_property(content_root, "scale",
		Vector2(CINEMATIC_ZOOM_TARGET, CINEMATIC_ZOOM_TARGET),
		CINEMATIC_ZOOM_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 2b) Fade do preto + partículas suaves ligam
	ambience.emitting = true
	var t := create_tween()
	t.tween_property(fade_rect, "modulate:a", 0.0, BG_FADE_IN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t.finished

	# 3) "PARABÉNS!"
	await show_title()
	await get_tree().create_timer(PAUSE_AFTER_TITLE).timeout

	# 4) "Você terminou o jogo."
	await type_message(MESSAGE_TEXT)

	# 5) Personagem entra
	await get_tree().create_timer(PAUSE_BEFORE_CHARACTER).timeout
	await show_character()

	# 6) Celebração — momento principal
	await get_tree().create_timer(PAUSE_BEFORE_CELEBRATION).timeout
	await play_thumbs_up()

	# 7) "Obrigado por jogar."
	await show_thanks()

	# 8) Pausa emocional
	await get_tree().create_timer(EMOTIONAL_PAUSE).timeout

	# 9) Fade-out final
	await fade_out_finish()


# ============================================================
#  Animações nomeadas (separadas para facilitar ajustes)
# ============================================================

# Aparição do "PARABÉNS!" com fade, scale (back-out) e shimmer dourado.
func show_title() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(title_label, "modulate:a", 1.0, TITLE_FADE_IN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(title_label, "scale", Vector2.ONE, TITLE_FADE_IN) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished

	var shimmer := create_tween()
	shimmer.tween_property(title_label, "modulate",
		Color(1.35, 1.25, 1.0, 1.0), 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	shimmer.tween_property(title_label, "modulate",
		Color(1.0, 1.0, 1.0, 1.0), 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await shimmer.finished


# Efeito de digitação letra por letra (respeita Unicode).
func type_message(text_to_type: String) -> void:
	message_label.text = ""
	for i in text_to_type.length():
		message_label.text += text_to_type[i]
		await get_tree().create_timer(MESSAGE_TYPE_SPEED).timeout


# Personagem (já dando joinha) entra: fade + subida + leve scale.
func show_character() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(character_sprite, "modulate:a", 1.0, CHARACTER_FADE_IN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(character_container, "position:y",
		_character_base_y, CHARACTER_FADE_IN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(character_container, "scale",
		Vector2(1.0, 1.0), CHARACTER_FADE_IN) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished


# Momento principal de celebração: aura acende + sparkles + bounce + SFX.
# (O sprite já está na pose de joinha — aqui damos vida à comemoração.)
func play_thumbs_up() -> void:
	_safe_play(achievement_sfx)

	# Aura acende + punch de escala
	var t := create_tween().set_parallel(true)
	t.tween_property(glow_aura, "modulate:a", 0.85, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(character_container, "scale",
		Vector2(1.06, 1.06), 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished

	# Burst de partículas de celebração
	sparkles.restart()
	sparkles.emitting = true

	# Pulso ambiente da aura (AnimationPlayer, em loop)
	if animation_player.has_animation("ambient_glow"):
		animation_player.play("ambient_glow")

	# Bounce comemorando (2 ciclos suaves)
	var bounce := create_tween().set_loops(2)
	bounce.tween_property(character_container, "position:y",
		_character_base_y - 12.0, 0.32) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bounce.tween_property(character_container, "position:y",
		_character_base_y, 0.32) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await bounce.finished

	# Volta da escala ao normal suavemente
	var unzoom := create_tween()
	unzoom.tween_property(character_container, "scale",
		Vector2(1.0, 1.0), 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# Fade-in do "Obrigado por jogar."
func show_thanks() -> void:
	var t := create_tween()
	t.tween_property(thanks_label, "modulate:a", 1.0, THANKS_FADE_IN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t.finished


# Fade-out final cinematográfico + troca de cena (opcional).
func fade_out_finish() -> void:
	_safe_play(fade_sfx)

	var t := create_tween().set_parallel(true)
	t.tween_property(fade_rect, "modulate:a", 1.0, FINAL_FADE_OUT) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(glow_aura, "modulate:a", 0.0, FINAL_FADE_OUT * 0.8)
	if music_player.playing:
		t.tween_property(music_player, "volume_db", -60.0, FINAL_FADE_OUT)
	await t.finished

	if animation_player.is_playing():
		animation_player.stop()

	# TROQUE AQUI (ou em NEXT_SCENE_PATH no topo) para chamar a próxima cena.
	if NEXT_SCENE_PATH != "":
		get_tree().change_scene_to_file(NEXT_SCENE_PATH)


# ============================================================
#  Helpers
# ============================================================

# Toca o AudioStreamPlayer apenas se houver stream atribuído,
# permitindo deixar os nós de áudio prontos sem quebrar sem os arquivos.
func _safe_play(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	if player.stream != null:
		player.play()
