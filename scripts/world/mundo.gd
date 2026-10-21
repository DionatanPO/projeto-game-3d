extends Node3D
## Mundo: cena agregadora. Instancia os 4 cenarios, cada um na sua origem
## no mundo (ver CENARIOS.md). Modele cada cenario no seu arquivo; aqui
## nada de conteudo, so posicionamento + luz/ceu compartilhados.

var _som_musica: AudioStreamPlayer
var _rain_active = false
var _original_env: Environment
var _rain_particles: GPUParticles3D
var _rain_sound: AudioStreamPlayer
var _lightning_timer: Timer
var _lightning_interval_min: float = 5.0
var _lightning_interval_max: float = 15.0
var _player_ref: Node3D  # Referencia ao jogador para posicionar a chuva
var _sun: DirectionalLight3D
var _sun_day_energy: float = 0.0
var _sun_day_color: Color = Color.WHITE
var _lightning_generation: int = 0

## ---- Cutscene Cinematográfica de Abertura ---------------------------
const INTRO_CLAREAR := 0.4
const INTRO_ESCURECER := 0.6
const INTRO_VOLTA := 0.5
const POS_FINAL_JOGADOR := Vector3(0.0, 1.5, -11.91)
const POS_INICIAL_JOGADOR := Vector3(0.0, 1.5, -19.5)

const CINEMATICA: Array[Dictionary] = [
	{
		"pos_ini": Vector3(-45.0, 40.0, 120.0), "pos_fim": Vector3(-18.0, 26.0, 88.0),
		"alvo_ini": Vector3(-1.0, 8.0, 89.0), "alvo_fim": Vector3(0.0, 2.0, 30.0),
		"tempo": 4.5, "texto": "FAZENDA AGROBRASIL  •  INOVAÇÃO E SUSTENTABILIDADE",
	},
	{
		"pos_ini": Vector3(-48.0, 9.5, 62.0), "pos_fim": Vector3(-18.0, 6.5, 36.0),
		"alvo_ini": Vector3(-36.0, 1.5, 41.0), "alvo_fim": Vector3(10.0, 1.0, 20.0),
		"tempo": 4.2, "texto": "CAMPOS DE CULTIVO  •  TECNOLOGIA E AGRICULTURA DE PRECISÃO",
	},
	{
		"pos_ini": Vector3(18.0, 5.5, -14.0), "pos_fim": Vector3(8.5, 3.5, -4.0),
		"alvo_ini": Vector3(13.0, 1.5, -7.0), "alvo_fim": Vector3(7.2, 1.2, 1.0),
		"tempo": 3.8, "texto": "EQUIPAMENTOS INTELIGENTES  •  TRATORES E DRONES DE MONITORAMENTO",
	},
	{
		"pos_ini": Vector3(-14.0, 6.0, -22.0), "pos_fim": Vector3(-4.5, 3.2, -16.5),
		"alvo_ini": Vector3(1.2, 2.0, 3.0), "alvo_fim": Vector3(0.0, 1.6, -11.9),
		"tempo": 3.8, "texto": "SEDE DA FAZENDA  •  O PONTO DE PARTIDA DA SUA JORNADA",
	},
	{
		"pos_ini": Vector3(0.0, 3.2, -18.5), "pos_fim": Vector3(0.0, 2.2, -15.0),
		"alvo_ini": Vector3(0.0, 1.5, -11.9), "alvo_fim": Vector3(0.0, 1.5, -11.9),
		"tempo": 3.5, "texto": "EXPLORE, APRENDA E CULTIVE O FUTURO",
	},
]

var _em_cutscene := false
var _intro_tempo := 0.0
var _intro_total := 0.0
var _intro_plano := -1
var _camera_cine: Camera3D
var _ui_layer: CanvasLayer
var _intro_barras: Array[ColorRect] = []
var _intro_texto: Label
var _intro_dica: Label
var _intro_fade: ColorRect
var _musica_cutscene: AudioStreamPlayer
var _hud_node: CanvasLayer

const ORIGENS := {
	"sede": Vector3(0, 0, 0),
	"milho": Vector3(120, 0, 0),
	"soja": Vector3(-120, 0, 0),
	"silo": Vector3(0, 0, -120),
	"solar": Vector3(0, 0, 120),
	"eolico": Vector3(-120, 0, 120),
	"galpao": Vector3(120, 0, -120),
}

const NO_CENARIO := {
	"sede": "SedeFazenda",
	"milho": "PlantacaoMilho",
	"soja": "PlantacaoSoja",
	"silo": "EstruturaSilo",
	"solar": "ParqueSolar",
	"eolico": "ParqueEolico",
	"galpao": "Galpao",
}


func _ready() -> void:
	if bool(SaveSystem.dados.get("vsync", true)):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# Som ambiente da fazenda: so toca com o jogador a pe (inicia/para em _process).
	_configurar_musica()
	_inicializar_sistema_chuva()
	_encontrar_jogador()
	# A abertura cinematografica e so da primeira entrada no mapa. Ao voltar
	# de outra cena (ex.: tutorial do drone), o jogador cai direto no controle.
	if _intro_ja_vista():
		_entrar_direto_no_jogo()
	else:
		_iniciar_cutscene()


## A abertura do mundo roda uma unica vez. Saves antigos que ja passaram pelo
## tutorial do drone tambem contam como "ja apresentados".
func _intro_ja_vista() -> bool:
	if bool(SaveSystem.dados.get("intro_mundo_vista", false)):
		return true
	if bool(SaveSystem.dados.get("tutorial_drone_visto", false)) \
			or bool(SaveSystem.dados.get("tutorial_drone_concluido", false)):
		SaveSystem.dados["intro_mundo_vista"] = true
		SaveSystem.salvar()
		return true
	return false


## Entrada sem cutscene: faz o mesmo "devolver controle" da abertura (HUD
## visivel, jogador livre, camera do veiculo ativo e mouse capturado).
func _entrar_direto_no_jogo() -> void:
	_em_cutscene = false
	_intro_tempo = 0.0
	_hud_node = get_node_or_null("HUD") as CanvasLayer
	if _hud_node != null:
		_hud_node.visible = true
	if _player_ref != null:
		_player_ref.set("bloqueado", false)
		if _player_ref.has_method("parar_cutscene"):
			_player_ref.parar_cutscene()
	_retomar_camera_ativa()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Deixa a camera do veiculo ativo em primeiro plano (jogador/drone/trator).
func _retomar_camera_ativa() -> void:
	var veiculo := str(SaveSystem.dados.get("veiculo", "jogador"))
	var grupo := "jogador"
	if veiculo == "drone":
		grupo = "drone_jogador"
	elif veiculo == "trator":
		grupo = "trator_jogador"
	var corpo := get_tree().get_first_node_in_group(grupo) as Node3D
	if corpo == null:
		return
	var cam := corpo.find_child("Camera3D", true, false) as Camera3D
	if cam != null:
		cam.make_current()


func _configurar_musica() -> void:
	_som_musica = AudioStreamPlayer.new()
	_som_musica.name = "SomMusica"
	var trilha := load("res://assets/audio/som_ambiente.mp3") as AudioStream
	# Repeticao continua (o mp3 nao vem com loop marcado no import).
	if trilha is AudioStreamMP3:
		(trilha as AudioStreamMP3).loop = true
	elif trilha is AudioStreamWAV:
		(trilha as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_som_musica.stream = trilha
	_som_musica.finished.connect(_reiniciar_musica)
	if AudioServer.get_bus_index("Musica") >= 0:
		_som_musica.bus = "Musica"
	# O som_ambiente.mp3 vem gravado MUITO baixo (pico ~-35 dBFS, RMS ~-69 dBFS),
	# por isso o reforco grande aqui. Baixado bem em relacao ao maximo (+33 dB).
	_som_musica.volume_db = 16.0
	add_child(_som_musica)


## Som ambiente so com o jogador a pe: pausa ao entrar no drone/trator e
## retoma (de onde parou) ao descer. "veiculo" no save e a fonte da verdade.
func _atualizar_som_ambiente() -> void:
	if _som_musica == null:
		return
	if _em_cutscene:
		if _som_musica.playing:
			_som_musica.stop()
		return
	var a_pe := str(SaveSystem.dados.get("veiculo", "jogador")) == "jogador"
	if a_pe and not _som_musica.playing:
		_som_musica.play()
	_som_musica.stream_paused = not a_pe


func _encontrar_jogador() -> void:
	_atualizar_alvo_chuva()
	if _player_ref == null:
		push_warning("Mundo: Nenhum jogador encontrado no grupo 'jogador'")


func _atualizar_alvo_chuva() -> void:
	var veiculo_ativo := str(SaveSystem.dados.get("veiculo", "jogador"))
	var grupo_alvo := "jogador"
	if veiculo_ativo == "drone":
		grupo_alvo = "drone_jogador"
	elif veiculo_ativo == "trator":
		grupo_alvo = "trator_jogador"

	var alvo := get_tree().get_first_node_in_group(grupo_alvo) as Node3D
	if alvo == null or not is_instance_valid(alvo):
		alvo = get_tree().get_first_node_in_group("jogador") as Node3D
	if alvo != null and alvo != _player_ref:
		_player_ref = alvo


func _reiniciar_musica() -> void:
	_som_musica.seek(0)
	_som_musica.play()
	_atualizar_som_ambiente()


func _inicializar_sistema_chuva() -> void:
	# Guardar ambiente original
	var ceu := get_node_or_null("MundoCeu") as WorldEnvironment
	if ceu and ceu.environment:
		_original_env = ceu.environment.duplicate()
	_sun = get_node_or_null("Sol") as DirectionalLight3D
	if _sun:
		_sun_day_energy = _sun.light_energy
		_sun_day_color = _sun.light_color

	# Criar sistema de particulas de chuva
	_rain_particles = GPUParticles3D.new()
	_rain_particles.name = "RainParticles"
	_rain_particles.one_shot = false
	_rain_particles.amount = 14000
	_rain_particles.lifetime = 1.2
	_rain_particles.speed_scale = 1.0
	_rain_particles.explosiveness = 0.0
	_rain_particles.preprocess = 1.0
	# Mantem todo o campo de chuva centrado no jogador ao se deslocar.
	_rain_particles.local_coords = true
	_rain_particles.visibility_aabb = AABB(Vector3(-30, -35, -30), Vector3(60, 55, 60))

	# Particulas em uma caixa larga acima do jogador, caindo quase na vertical.
	var material_chuva := ParticleProcessMaterial.new()
	material_chuva.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	material_chuva.emission_ring_axis = Vector3.UP
	material_chuva.emission_ring_radius = 28.0
	material_chuva.emission_ring_inner_radius = 0.0
	material_chuva.emission_ring_height = 2.0
	material_chuva.direction = Vector3(0.0, -1.0, 0.0)
	material_chuva.spread = 3.0
	material_chuva.initial_velocity_min = 27.0
	material_chuva.initial_velocity_max = 32.0
	material_chuva.gravity = Vector3.ZERO
	material_chuva.scale_min = 0.8
	material_chuva.scale_max = 1.2
	material_chuva.color = Color(0.65, 0.78, 1.0, 0.72)
	_rain_particles.process_material = material_chuva

	# Quad estreito e alto deixa os pingos visiveis mesmo a distancia.
	var malha_chuva := QuadMesh.new()
	malha_chuva.size = Vector2(0.006, 0.45)
	var visual_chuva := StandardMaterial3D.new()
	visual_chuva.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual_chuva.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visual_chuva.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual_chuva.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	visual_chuva.albedo_color = Color(0.65, 0.78, 1.0, 0.72)
	malha_chuva.material = visual_chuva
	_rain_particles.draw_pass_1 = malha_chuva

	# Posicionar inicialmente (sera atualizado no _process)
	var pos_inicial := Vector3(0.0, 25.0, 0.0)
	if _player_ref:
		pos_inicial = _player_ref.global_position + Vector3(0.0, 20.0, 0.0)
	_rain_particles.position = pos_inicial

	# Adicionar como filho (inicialmente desativado)
	add_child(_rain_particles)
	_rain_particles.emitting = false

	# Criar som de chuva
	_rain_sound = AudioStreamPlayer.new()
	_rain_sound.name = "RainSound"
	var audio_chuva := load("res://assets/audio/som_chuva.mp3") as AudioStream
	if audio_chuva is AudioStreamMP3:
		(audio_chuva as AudioStreamMP3).loop = true
	elif audio_chuva is AudioStreamWAV:
		(audio_chuva as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_rain_sound.stream = audio_chuva
	if AudioServer.get_bus_index("Efeitos") >= 0:
		_rain_sound.bus = "Efeitos"
	_rain_sound.volume_db = -4.0
	add_child(_rain_sound)

	# Criar timer para raios
	_lightning_timer = Timer.new()
	_lightning_timer.name = "LightningTimer"
	_lightning_timer.one_shot = false
	_lightning_timer.wait_time = _lightning_interval_min
	_lightning_timer.timeout.connect(_trigger_lightning)
	add_child(_lightning_timer)

	# Acao de entrada "chuva" ja definida em input_setup.gd (KEY_F1)
	pass


func _unhandled_input(evento: InputEvent) -> void:
	if _em_cutscene and _evento_pula(evento):
		_pular_intro()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _em_cutscene:
		_processar_cutscene(delta)
		return
	_process_input()
	_atualizar_alvo_chuva()
	_atualizar_som_ambiente()
	_atualizar_posicao_chuva(delta)


func _atualizar_posicao_chuva(_delta: float) -> void:
	if _rain_particles and _player_ref:
		# Posicionar o sistema de particulas ligeiramente acima do jogador
		_rain_particles.global_position = _player_ref.global_position + Vector3(0.0, 20.0, 0.0)


func _process_input() -> void:
	if Input.is_action_just_pressed("chuva"):
		alternar_chuva()


func alternar_chuva() -> void:
	_rain_active = not _rain_active
	if _rain_active:
		_ativar_chuva()
	else:
		_desativar_chuva()


func _ativar_chuva() -> void:
	var ceu := get_node_or_null("MundoCeu") as WorldEnvironment
	# Escurecer o ambiente
	if ceu and ceu.environment:
		var env = ceu.environment
		# Reduzir luz ambiente
		env.ambient_light_color = Color(0.3, 0.3, 0.4)
		env.ambient_light_energy = 0.2
		# Escurecer ceu de fundo
		env.background_color = Color(0.2, 0.2, 0.3)
		# Aumentar neblina ligeiramente para efeito de chuva
		env.fog_enabled = true
		env.fog_light_color = Color(0.28, 0.32, 0.42)
		env.fog_density = 0.015
	if _sun:
		_sun.light_energy = 0.12
		_sun.light_color = Color(0.42, 0.48, 0.62)

	# Ativar particulas de chuva
	if _rain_particles:
		_rain_particles.emitting = true

	# Iniciar som de chuva com entrada suave
	if _rain_sound and _rain_sound.stream:
		_rain_sound.volume_db = -24.0
		if not _rain_sound.playing:
			_rain_sound.play()
		var fade_audio := create_tween()
		fade_audio.tween_property(_rain_sound, "volume_db", -4.0, 1.2)

	# Iniciar timer de raios
	if _lightning_timer:
		_lightning_timer.start()
		_trigger_lightning()  # Primeiro raio imediato


func _desativar_chuva() -> void:
	_rain_active = false
	_lightning_generation += 1
	# Restaurar ambiente original
	var ceu := get_node_or_null("MundoCeu") as WorldEnvironment
	if ceu and _original_env:
		ceu.environment = _original_env.duplicate()

	# Desativar particulas de chuva
	if _rain_particles:
		_rain_particles.emitting = false

	# Parar som de chuva com fade-out suave
	if _rain_sound and _rain_sound.playing:
		var fade_saida := create_tween()
		fade_saida.tween_property(_rain_sound, "volume_db", -36.0, 1.0)
		fade_saida.tween_callback(func() -> void:
			if not _rain_active and _rain_sound != null and is_instance_valid(_rain_sound):
				_rain_sound.stop()
		)

	# Parar timer de raios
	if _lightning_timer:
		_lightning_timer.stop()
	if _sun:
		_sun.light_energy = _sun_day_energy
		_sun.light_color = _sun_day_color


func _trigger_lightning() -> void:
	if not _rain_active or not _sun:
		return
	_lightning_generation += 1
	var geracao_atual := _lightning_generation
	var energia_noite := _sun.light_energy
	var cor_noite := _sun.light_color
	var claridade := create_tween()
	claridade.tween_property(_sun, "light_energy", 2.6, 0.04)
	claridade.parallel().tween_property(_sun, "light_color", Color(0.82, 0.9, 1.0), 0.04)
	claridade.tween_interval(0.08)
	claridade.tween_property(_sun, "light_energy", 0.55, 0.05)
	claridade.tween_interval(0.08)
	claridade.tween_property(_sun, "light_energy", 2.2, 0.035)
	claridade.parallel().tween_property(_sun, "light_color", Color.WHITE, 0.035)
	claridade.tween_interval(0.1)
	claridade.tween_property(_sun, "light_energy", energia_noite, 0.45)
	claridade.parallel().tween_property(_sun, "light_color", cor_noite, 0.45)
	claridade.finished.connect(func() -> void:
		if geracao_atual == _lightning_generation and not _rain_active:
			_sun.light_energy = _sun_day_energy
			_sun.light_color = _sun_day_color
	)

	# Cada tempestade escolhe um intervalo diferente para o proximo raio.
	if _lightning_timer:
		_lightning_timer.wait_time = randf() * (_lightning_interval_max - _lightning_interval_min) + _lightning_interval_min


## Leva o jogador (grupo "jogador") ate a origem de um cenario.
func teleportar_para(cenario: String) -> void:
	if not ORIGENS.has(cenario):
		push_error("Mundo: cenario '%s' nao existe." % cenario)
		return
	var alvos := get_tree().get_nodes_in_group("jogador")
	if alvos.is_empty():
		push_error("Mundo: nenhum jogador na cena.")
		return
	var corpo := alvos[0] as Node3D
	var destino: Vector3 = ORIGENS[cenario] + Vector3(0, 2, 14)
	corpo.position = destino
	if corpo is CharacterBody3D:
		(corpo as CharacterBody3D).velocity = Vector3.ZERO


# ------------------------------------------------------------------
# Cutscene Cinematográfica de Abertura do Mundo
# ------------------------------------------------------------------

func _iniciar_cutscene() -> void:
	_em_cutscene = true
	_intro_tempo = 0.0
	_intro_plano = -1
	_intro_total = 0.0
	for plano in CINEMATICA:
		_intro_total += float(plano["tempo"])

	_hud_node = get_node_or_null("HUD") as CanvasLayer
	if _hud_node != null:
		_hud_node.visible = false

	# Posiciona o jogador no ponto de partida da caminhada
	if _player_ref != null:
		_player_ref.global_position = POS_INICIAL_JOGADOR
		_player_ref.set("bloqueado", true)
		if _player_ref.has_method("parar_cutscene"):
			_player_ref.parar_cutscene(POS_INICIAL_JOGADOR)
		# Orienta o modelo para o destino da caminhada
		var modelo_jogador := _player_ref.find_child("Modelo", true, false) as Node3D
		if modelo_jogador != null:
			var dir_destino := (POS_FINAL_JOGADOR - POS_INICIAL_JOGADOR)
			dir_destino.y = 0.0
			if dir_destino.length() > 0.01:
				dir_destino = dir_destino.normalized()
				modelo_jogador.rotation.y = atan2(-dir_destino.x, -dir_destino.z)


	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_montar_ui_cutscene()

	for barra in _intro_barras:
		barra.visible = true
	_intro_texto.text = ""
	_intro_texto.visible = true
	_intro_dica.visible = true
	_intro_fade.visible = false
	_intro_fade.color.a = 0.0

	_camera_cine = Camera3D.new()
	_camera_cine.name = "CameraCinematografica"
	_camera_cine.fov = 68.0
	_camera_cine.far = 450.0
	add_child(_camera_cine)
	_camera_cine.global_position = CINEMATICA[0]["pos_ini"]
	_camera_cine.look_at(CINEMATICA[0]["alvo_ini"], Vector3.UP)
	_camera_cine.make_current()

	_tocar_musica_cutscene()


func _tocar_musica_cutscene() -> void:
	_musica_cutscene = AudioStreamPlayer.new()
	_musica_cutscene.name = "MusicaCutscene"
	var trilha := load("res://assets/audio/musicas/First_Light_on_the_Rows.mp3") as AudioStream
	if trilha is AudioStreamMP3:
		(trilha as AudioStreamMP3).loop = true
	_musica_cutscene.stream = trilha
	if AudioServer.get_bus_index("Musica") >= 0:
		_musica_cutscene.bus = "Musica"
	_musica_cutscene.volume_db = -2.0
	add_child(_musica_cutscene)
	_musica_cutscene.play()


func _processar_cutscene(delta: float) -> void:
	_intro_tempo += delta

	# A partir do plano 4 (≈15s), o personagem caminha autonomamente até a sede.
	# A função agora apenas ativa o destino no jogador; o movimento acontece no _physics_process.
	if _intro_tempo >= 15.0 and _player_ref != null and _player_ref.has_method("caminhar_cutscene"):
		_player_ref.caminhar_cutscene(delta, POS_FINAL_JOGADOR)

	# Reta final: escurece e devolve o controle ao jogador
	if _intro_tempo >= _intro_total:
		_intro_fade.visible = true
		_intro_fade.color.a = clampf((_intro_tempo - _intro_total) / INTRO_ESCURECER, 0.0, 1.0)
		if _intro_fade.color.a >= 1.0:
			_devolver_controle()
		return

	var acumulado := 0.0
	for i in CINEMATICA.size():
		var plano: Dictionary = CINEMATICA[i]
		var tempo := float(plano["tempo"])
		if _intro_tempo < acumulado + tempo:
			_aplicar_plano(plano, (_intro_tempo - acumulado) / tempo, i)
			return
		acumulado += tempo


func _aplicar_plano(plano: Dictionary, t: float, i: int) -> void:
	if _camera_cine == null:
		return
	var e := smoothstep(0.0, 1.0, clampf(t, 0.0, 1.0))
	var pos := (plano["pos_ini"] as Vector3).lerp(plano["pos_fim"] as Vector3, e)
	var alvo := (plano["alvo_ini"] as Vector3).lerp(plano["alvo_fim"] as Vector3, e)
	if pos.distance_to(alvo) > 0.5:
		_camera_cine.global_position = pos
		_camera_cine.look_at(alvo, Vector3.UP)
	if _intro_plano != i:
		_intro_plano = i
		_intro_texto.text = str(plano["texto"])


func _pular_intro() -> void:
	if _player_ref != null and _player_ref.has_method("parar_cutscene"):
		_player_ref.parar_cutscene(POS_FINAL_JOGADOR)
	_intro_tempo = _intro_total


func _devolver_controle() -> void:
	_em_cutscene = false
	_intro_tempo = 0.0
	# A abertura so volta a tocar em um jogo novo (SaveSystem.apagar()).
	SaveSystem.dados["intro_mundo_vista"] = true
	SaveSystem.salvar()

	if _camera_cine != null:
		_camera_cine.queue_free()
		_camera_cine = null

	if _player_ref != null:
		_player_ref.set("bloqueado", false)
		if _player_ref.has_method("parar_cutscene"):
			_player_ref.parar_cutscene(POS_FINAL_JOGADOR)
		var cam := _player_ref.find_child("Camera3D", true, false) as Camera3D
		if cam != null:
			cam.make_current()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if _hud_node != null:
		_hud_node.visible = true

	for barra in _intro_barras:
		barra.visible = false
	if _intro_texto != null:
		_intro_texto.visible = false
	if _intro_dica != null:
		_intro_dica.visible = false

	# Clareia a visão do jogador a partir do preto
	var tw := create_tween()
	tw.tween_property(_intro_fade, "color:a", 0.0, INTRO_VOLTA)
	tw.tween_callback(Callable(_intro_fade, "hide"))

	# Fade out suave da música da cutscene e início do som ambiente
	if _musica_cutscene != null:
		var tw_mus := create_tween()
		tw_mus.tween_property(_musica_cutscene, "volume_db", -40.0, 1.4)
		tw_mus.tween_callback(func() -> void:
			if _musica_cutscene != null:
				_musica_cutscene.stop()
				_musica_cutscene.queue_free()
				_musica_cutscene = null
		)

	_atualizar_som_ambiente()


func _evento_pula(evento: InputEvent) -> bool:
	if evento is InputEventKey:
		return (evento as InputEventKey).pressed and not (evento as InputEventKey).echo
	if evento is InputEventMouseButton:
		return (evento as InputEventMouseButton).pressed
	if evento is InputEventJoypadButton:
		return (evento as InputEventJoypadButton).pressed
	if evento is InputEventScreenTouch:
		return (evento as InputEventScreenTouch).pressed
	return false


func _montar_ui_cutscene() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "CutsceneUI"
	_ui_layer.layer = 100
	add_child(_ui_layer)

	var barra_topo := ColorRect.new()
	barra_topo.name = "BarraCineTopo"
	barra_topo.color = Color(0, 0, 0, 1)
	barra_topo.anchor_right = 1.0
	barra_topo.anchor_bottom = 0.11
	barra_topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra_topo.visible = false
	_ui_layer.add_child(barra_topo)
	_intro_barras.append(barra_topo)

	var barra_baixo := ColorRect.new()
	barra_baixo.name = "BarraCineBaixo"
	barra_baixo.color = Color(0, 0, 0, 1)
	barra_baixo.anchor_top = 0.89
	barra_baixo.anchor_right = 1.0
	barra_baixo.anchor_bottom = 1.0
	barra_baixo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra_baixo.visible = false
	_ui_layer.add_child(barra_baixo)
	_intro_barras.append(barra_baixo)

	_intro_texto = Label.new()
	_intro_texto.name = "LegendaCine"
	_intro_texto.text = ""
	_intro_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro_texto.add_theme_font_size_override("font_size", 20)
	_intro_texto.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_intro_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intro_texto.anchor_top = 0.89
	_intro_texto.anchor_right = 1.0
	_intro_texto.anchor_bottom = 1.0
	_intro_texto.offset_left = 40.0
	_intro_texto.offset_right = -40.0
	_intro_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_texto.visible = false
	_ui_layer.add_child(_intro_texto)

	_intro_dica = Label.new()
	_intro_dica.name = "DicaCine"
	_intro_dica.text = "Pular: qualquer tecla, botão ou clique"
	_intro_dica.add_theme_font_size_override("font_size", 13)
	_intro_dica.add_theme_color_override("font_color", Color(1, 1, 1, 0.78))
	_intro_dica.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_intro_dica.add_theme_constant_override("outline_size", 5)
	_intro_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_intro_dica.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_intro_dica.offset_top = 20.0
	_intro_dica.offset_bottom = 44.0
	_intro_dica.offset_right = -26.0
	_intro_dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_dica.visible = false
	_ui_layer.add_child(_intro_dica)

	_intro_fade = ColorRect.new()
	_intro_fade.name = "FadeCine"
	_intro_fade.color = Color(0, 0, 0, 1)
	_intro_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_fade.visible = false
	_ui_layer.add_child(_intro_fade)
