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
	_atualizar_som_ambiente()
	_inicializar_sistema_chuva()
	_encontrar_jogador()


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
	# Nota: Voce precisaria adicionar um arquivo de audio de chuva aqui
	# Por enquanto, vamos deixar comentado pois nao temos o audio
	# _rain_sound.stream = load("res://assets/audio/chuva_loop.wav")
	# _rain_sound.stream = preload("res://assets/audio/chuva_loop.wav")  # Se existir
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


func _process(delta: float) -> void:
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

	# Iniciar som de chuva (se tiver audio)
	# if _rain_sound.stream:
	#	 _rain_sound.play()

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

	# Parar som de chuva
	if _rain_sound and _rain_sound.playing:
		_rain_sound.stop()

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
