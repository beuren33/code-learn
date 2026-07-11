extends Control
# ============================================================
#  ending_sequence.gd
#  Sequência FINAL cinematográfica — HORIZONTAL 16:9 (base 1920x1080)
#  Universo tecnológico / sci-fi (escuro, azul/ciano, elegante).
# ============================================================
#  DOIS MOMENTOS:
#    1) VÍDEO FINAL — vídeo em tela cheia + mensagens de parabéns
#    2) CRÉDITOS    — fundo sci-fi, personagem fixo à esquerda,
#                     créditos subindo no centro / centro-direita
#
#  FLUXO:
#    preto -> fade in -> vídeo + textos -> fade out -> pausa preta
#    -> fade in créditos -> créditos sobem -> fade out final -> menu
#
#  ROBUSTO: se algum asset não existir, usa placeholder seguro e
#  NÃO quebra a cena (mesma filosofia do _safe_play).
# ============================================================


# ---------- ASSETS (troque aqui se mudar os caminhos) ----------
const VIDEO_PATH: String  = "res://tela-final-refeita/assets/final/final_video.ogv"
# A nova imagem de créditos JÁ inclui o personagem (embutido à esquerda),
# por isso usamos ela como fundo completo e NÃO há sprite separado.
const BG_PATH: String     = "res://tela-final-refeita/assets/final/credits_scene.png"
const MUSIC_PATH: String  = "res://tela-final-refeita/assets/final/ending_music.ogg"

# ---------- TEXTOS DO VÍDEO (troque aqui) ----------
const CONGRATS_TEXT: String = "Parabéns, você concluiu o jogo!"
const THANKS_TEXT: String   = "Muito obrigado por jogar."

# ---------- FINALIZAÇÃO (config fácil no Inspector) ----------
@export var return_to_menu: bool = true
@export var main_menu_scene_path: String = "res://scenes/MainMenu.tscn"
@export var quit_on_finish: bool = false          # usado só se return_to_menu = false

# ---------- RITMO / TIMING (ajuste no Inspector) ----------
@export_group("Timing")
@export var initial_black_hold: float       = 0.6
@export var intro_fade_in: float            = 1.4
@export var video_placeholder_duration: float = 9.0   # usado se NÃO houver vídeo
@export var congrats_in_delay: float        = 1.2
@export var congrats_fade: float            = 1.2
@export var thanks_gap: float               = 1.0
@export var intro_text_hold: float          = 3.2
@export var intro_text_out: float           = 1.0
@export var video_to_black: float           = 1.4
@export var black_pause: float              = 0.6     # 0.4–0.7
@export var credits_fade_in: float          = 1.6
@export var credits_pre_roll: float         = 0.8
@export var credits_scroll_duration: float  = 28.0    # 20–35
@export var credits_end_hold: float         = 1.4
@export var final_fade_out: float           = 2.4

# ---------- AMBIENTE ----------
@export_group("Ambiente")
@export var music_volume_db: float = -10.0
@export_range(0.0, 1.0, 0.01) var overlay_darkness: float = 0.32  # 0.20–0.40
@export var allow_skip: bool = true


# ---------- Referências de nó ----------
@onready var video_layer: Control              = $VideoLayer
@onready var video_player: VideoStreamPlayer   = $VideoLayer/VideoStreamPlayer
@onready var intro_text: Control               = $VideoLayer/IntroTextContainer
@onready var congrats_label: Label             = $VideoLayer/IntroTextContainer/CongratulationsLabel
@onready var thanks_label: Label               = $VideoLayer/IntroTextContainer/ThanksLabel

@onready var credits_layer: Control            = $CreditsLayer
@onready var credits_background: TextureRect    = $CreditsLayer/CreditsBackground
@onready var dark_overlay: ColorRect           = $CreditsLayer/BackgroundDarkOverlay
@onready var credits_viewport: Control          = $CreditsLayer/CreditsViewport
@onready var credits_container: VBoxContainer   = $CreditsLayer/CreditsViewport/CreditsContainer

@onready var effects_layer: Control            = $EffectsLayer
@onready var ambient_particles: CPUParticles2D  = $EffectsLayer/ParticlesContainer/AmbientParticles
@onready var glow_overlay: TextureRect          = $EffectsLayer/GlowOverlay
@onready var vignette: TextureRect              = $EffectsLayer/VignetteOverlay

@onready var fade_rect: ColorRect              = $FadeLayer/FadeRect
@onready var music_player: AudioStreamPlayer    = $AudioStreamPlayer
@onready var animation_player: AnimationPlayer  = $AnimationPlayer

# ---------- Estado interno ----------
var _congrats_base_y: float = 0.0
var _thanks_base_y: float   = 0.0
var _finished: bool         = false
var _in_credits: bool       = false
var _scroll_tween: Tween


# ============================================================
#  Ciclo de vida
# ============================================================
func _ready() -> void:
	# Espera 1 frame para o layout dos Controls (anchors -> size/position)
	# estar resolvido antes de medirmos posições base.
	await get_tree().process_frame
	_load_media()
	_reset_initial_state()
	start_sequence()


func _unhandled_input(event: InputEvent) -> void:
	if not allow_skip or _finished:
		return
	var skip := false
	if event is InputEventKey and event.pressed and not event.echo:
		skip = true
	elif event is InputEventMouseButton and event.pressed:
		skip = true
	elif event is InputEventScreenTouch and event.pressed:
		skip = true
	if skip:
		_skip()


# ============================================================
#  Carregamento seguro de mídia (nunca quebra se faltar arquivo)
# ============================================================
func _load_media() -> void:
	if credits_background.texture == null and ResourceLoader.exists(BG_PATH):
		var bg := load(BG_PATH)
		if bg is Texture2D:
			credits_background.texture = bg
	if ResourceLoader.exists(VIDEO_PATH):
		var vs := load(VIDEO_PATH)
		if vs is VideoStream:
			video_player.stream = vs
	if ResourceLoader.exists(MUSIC_PATH):
		var ms := load(MUSIC_PATH)
		if ms is AudioStream:
			music_player.stream = ms


# Estado inicial: vídeo pronto e coberto de preto; créditos ocultos.
func _reset_initial_state() -> void:
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.modulate.a = 1.0

	video_layer.visible = true
	credits_layer.visible = false
	effects_layer.visible = false

	# Textos do vídeo invisíveis (aparecem depois)
	congrats_label.text = CONGRATS_TEXT
	thanks_label.text = THANKS_TEXT
	congrats_label.modulate.a = 0.0
	thanks_label.modulate.a = 0.0
	_congrats_base_y = congrats_label.position.y
	_thanks_base_y = thanks_label.position.y

	# Créditos / ambiente
	dark_overlay.color.a = overlay_darkness
	glow_overlay.modulate.a = 0.0
	ambient_particles.emitting = false


# ============================================================
#  Orquestração principal
# ============================================================
func start_sequence() -> void:
	# 1) Segura o preto um instante
	await get_tree().create_timer(initial_black_hold).timeout

	# 2) Fade in + começa o vídeo
	await play_intro_video()

	# 3) Transição cinematográfica vídeo -> créditos
	await transition_to_credits()

	# 4) Créditos sobem até o fim
	await start_credits()


# ---------- MOMENTO 1: vídeo + textos ----------
func play_intro_video() -> void:
	video_layer.visible = true
	var has_video := video_player.stream != null
	if has_video:
		video_player.play()

	# Revela a cena (fade do preto)
	await fade_from_black(intro_fade_in)

	# Textos entram em paralelo com o vídeo (fire-and-forget)
	show_intro_text()

	# Espera o vídeo terminar (ou um tempo fixo se for placeholder)
	if has_video:
		await video_player.finished
	else:
		await get_tree().create_timer(video_placeholder_duration).timeout


# Coreografia dos textos sobre o vídeo:
# título entra com fade + leve subida; subtítulo depois; ambos somem.
func show_intro_text() -> void:
	await get_tree().create_timer(congrats_in_delay).timeout

	var t1 := create_tween().set_parallel(true)
	t1.tween_property(congrats_label, "modulate:a", 1.0, congrats_fade) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t1.tween_property(congrats_label, "position:y", _congrats_base_y, congrats_fade) \
		.from(_congrats_base_y + 26.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t1.finished

	await get_tree().create_timer(thanks_gap).timeout

	var t2 := create_tween()
	t2.tween_property(thanks_label, "modulate:a", 1.0, congrats_fade) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t2.finished

	# Permanecem alguns segundos e somem suavemente
	await get_tree().create_timer(intro_text_hold).timeout
	if _finished:
		return
	var t3 := create_tween().set_parallel(true)
	t3.tween_property(congrats_label, "modulate:a", 0.0, intro_text_out) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t3.tween_property(thanks_label, "modulate:a", 0.0, intro_text_out) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


# ---------- TRANSIÇÃO vídeo -> créditos ----------
func transition_to_credits() -> void:
	if _finished:
		return
	# Garante que os textos sumiram
	congrats_label.modulate.a = 0.0
	thanks_label.modulate.a = 0.0

	# Fade out para preto
	await fade_to_black(video_to_black)

	# Pausa curta no preto
	await get_tree().create_timer(black_pause).timeout

	# Esconde vídeo, prepara créditos (ainda sob o preto)
	if video_player.is_playing():
		video_player.stop()
	video_layer.visible = false
	setup_credits()

	# Fade in da cena de créditos
	await fade_from_black(credits_fade_in)


# ---------- MOMENTO 2: montar e iniciar créditos ----------
func setup_credits() -> void:
	credits_layer.visible = true
	effects_layer.visible = true
	dark_overlay.color.a = overlay_darkness

	# Ambientação de fundo (partículas + brilho pulsante)
	animate_background_effects()

	# Música emocional (se existir), entrando suave
	if music_player.stream != null:
		music_player.volume_db = -40.0
		music_player.play()
		var m := create_tween()
		m.tween_property(music_player, "volume_db", music_volume_db, 2.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Posiciona o bloco de créditos logo abaixo da área visível
	credits_container.position.y = credits_viewport.size.y + 40.0


func start_credits() -> void:
	if _finished:
		return
	_in_credits = true
	await get_tree().create_timer(credits_pre_roll).timeout
	if _finished:
		return

	# Mede o conteúdo real dos créditos para calcular o percurso
	var content_h: float = credits_container.get_combined_minimum_size().y
	credits_container.size = Vector2(credits_viewport.size.x, content_h)
	var start_y: float = credits_viewport.size.y + 40.0
	var end_y: float = -content_h - 40.0
	credits_container.position.y = start_y

	# Subida contínua, linear e confortável
	_scroll_tween = create_tween()
	_scroll_tween.tween_property(credits_container, "position:y", end_y,
		credits_scroll_duration).set_trans(Tween.TRANS_LINEAR)
	await _scroll_tween.finished

	if _finished:
		return
	await get_tree().create_timer(credits_end_hold).timeout
	end_credits()


# ---------- Animações de ambientação ----------
# Brilho pulsante sutil no fundo (AnimationPlayer) + partículas.
func animate_background_effects() -> void:
	ambient_particles.emitting = true
	if animation_player.has_animation("ambient_pulse"):
		animation_player.play("ambient_pulse")


# ---------- Encerramento ----------
func end_credits() -> void:
	if _finished:
		return
	var t := create_tween().set_parallel(true)
	t.tween_property(fade_rect, "modulate:a", 1.0, final_fade_out) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if music_player.playing:
		t.tween_property(music_player, "volume_db", -50.0, final_fade_out)
	t.tween_property(glow_overlay, "modulate:a", 0.0, final_fade_out * 0.8)
	await t.finished
	finish_sequence()


func finish_sequence() -> void:
	if _finished:
		return
	_finished = true

	if animation_player.is_playing():
		animation_player.stop()
	ambient_particles.emitting = false
	if music_player.playing:
		music_player.stop()

	if return_to_menu and main_menu_scene_path != "" \
			and ResourceLoader.exists(main_menu_scene_path):
		get_tree().change_scene_to_file(main_menu_scene_path)
	elif quit_on_finish:
		get_tree().quit()
	# Caso contrário: permanece em preto, pronto para o próximo passo.


# ============================================================
#  Helpers
# ============================================================
# Pula direto para o encerramento (fade final + finish), com segurança.
func _skip() -> void:
	if _finished:
		return
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	# Se ainda estava no vídeo, para tudo antes de encerrar.
	if video_player.is_playing():
		video_player.stop()
	end_credits()


func fade_from_black(duration: float) -> void:
	var t := create_tween()
	t.tween_property(fade_rect, "modulate:a", 0.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t.finished


func fade_to_black(duration: float) -> void:
	var t := create_tween()
	t.tween_property(fade_rect, "modulate:a", 1.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
