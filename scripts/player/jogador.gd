extends CharacterBody3D
## Jogador em terceira pessoa: camera independente (mouse/stick direito),
## movimento relativo a camera, malha gira ate o movimento. Suporta teclado
## e controle (Xbox: stick esquerdo move, direito olha, A pula, X interage,
## Y diario, LB corre).

@export var velocidade_andar := 4.5
@export var velocidade_correr := 7.0
@export var forca_pulo := 3.2
@export var sensibilidade_mouse := 0.003
@export var sensibilidade_stick := 2.8
## Segundos parado ate trocar o Idle normal pelo SadIdle (cabeca baixa).
@export var tempo_sad_idle := 3.0

@onready var rig: Node3D = $CameraRig
@onready var bracos_camera: SpringArm3D = $CameraRig/BracosCamera
@onready var modelo: Node3D = $Modelo

var gravidade: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _angulo_vertical := -0.35
var animador: AnimationPlayer
var _animacao_atual := ""
var _tempo_parado := 0.0
var _audio_passos: AudioStreamPlayer3D
var _som_passo_andar: AudioStream
var _som_passo_corrida: AudioStream
var _som_pulo: AudioStream
var _tempo_entre_passos := 0.0
## Antecipacao do pulo (s): paradinha freando o corpo antes de lancar.
const ANTECIPACAO_PULO := 0.18
const ANTECIPACAO_PULO_CORRIDA := 0.06
const ANTECIPACAO_PULO_ANDANDO := 0.10
const VELOCIDADE_MINIMA_ANDAR_PULO := 0.4
const VELOCIDADE_MINIMA_RUNNING_JUMP := 5.0
const FREIO_PULO := 60.0
## Ossos das pernas congelados no pulo + instante do agacho amostrado (s).
const PERNAS_PULO: Array[String] = ["LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg", "LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase", "LeftToe_End", "RightToe_End"]
const TEMPO_POSE_PULO := 0.8
var _pulo_preparando := 0.0
var _pulo_em_corrida := false
var _pulo_andando := false
## Tempos de crossfade (s) entre animacoes.
const BLEND_TERRA := 0.22
const BLEND_PULO_SAIDA := 0.1
const BLEND_POUSO := 0.25


func _ready() -> void:
	add_to_group("jogador")
	var pos: Variant = SaveSystem.dados.get("posicao_jogador", [-96.79012, 1.5, 0.73486805])
	if pos is Array and (pos as Array).size() == 3:
		position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	animador = modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animador != null:
		_importar_animacoes_personagem()
		_atualizar_animacao("Idle")
	_configurar_sons_passos()


func _configurar_sons_passos() -> void:
	_som_passo_andar = load("res://assets/audio/passo_andar.wav") as AudioStream
	_som_passo_corrida = load("res://assets/audio/passo_correr.wav") as AudioStream
	_som_pulo = load("res://assets/audio/passo_pulo.wav") as AudioStream
	_audio_passos = AudioStreamPlayer3D.new()
	_audio_passos.name = "AudioPassos"
	_audio_passos.max_distance = 22.0
	_audio_passos.unit_size = 5.0
	_audio_passos.volume_db = -4.0
	add_child(_audio_passos)


func _tocar_som_passo(correndo: bool) -> void:
	if _audio_passos == null:
		return
	_audio_passos.stream = _som_passo_corrida if correndo else _som_passo_andar
	if _audio_passos.stream != null:
		_audio_passos.play()


func _tocar_som_pulo() -> void:
	if _audio_passos == null or _som_pulo == null:
		return
	_audio_passos.stream = _som_pulo
	_audio_passos.play()


## Junta as clips Mixamo (cada FBX tem 1 anim "mixamo_com") no AnimationPlayer
## do modelo base (idle.fbx): SadIdle <- idle.fbx (cabeca baixa),
## Idle <- stop.fbx (parado normal), Walk <- andando.fbx,
## Run <- correndo.fbx, Jump <- Jump_stop.fbx,
## WalkJump <- pulando.fbx, RunJump <- running_jump.fbx. Os esqueletos sao identicos
## (65 bones mixamorig_*), entao as tracks "Skeleton3D:..." sao reutilizaveis.
func _importar_animacoes_personagem() -> void:
	if animador == null:
		return
	var lib: AnimationLibrary = animador.get_animation_library("")
	if lib == null:
		push_warning("[Jogador] AnimationLibrary padrao nao encontrada.")
		return
	if animador.has_animation("mixamo_com") and not animador.has_animation("SadIdle"):
		var base_anim: Animation = animador.get_animation("mixamo_com")
		var sad: Animation = base_anim.duplicate()
		_remover_root_motion(sad)
		lib.add_animation("SadIdle", sad)
	if animador.has_animation("mixamo_com"):
		lib.remove_animation("mixamo_com")
	var mapa := {
		"Idle": "res://assets/models/personagem/stop.fbx",
		"Walk": "res://assets/models/personagem/andando.fbx",
		"Run": "res://assets/models/personagem/correndo.fbx",
		"Jump": "res://assets/models/personagem/Jump_stop.fbx",
		"WalkJump": "res://assets/models/personagem/pulando.fbx",
		"RunJump": "res://assets/models/personagem/running_jump.fbx",
	}
	for nome in mapa.keys():
		if animador.has_animation(nome):
			continue
		var caminho: String = mapa[nome]
		if not ResourceLoader.exists(caminho):
			push_warning("[Jogador] Animacao ausente: %s" % caminho)
			continue
		var ps: PackedScene = load(caminho) as PackedScene
		if ps == null:
			push_warning("[Jogador] Falha ao carregar: %s" % caminho)
			continue
		var inst: Node = ps.instantiate()
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var nome_clip := "mixamo_com"
		if ap != null and not ap.has_animation(nome_clip):
			var lista := ap.get_animation_list()
			if lista.size() > 0:
				nome_clip = String(lista[0])
		if ap != null and ap.has_animation(nome_clip):
			var clip: Animation = ap.get_animation(nome_clip).duplicate()
			_remover_root_motion(clip)
			lib.add_animation(nome, clip)
		else:
			push_warning("[Jogador] Sem animacao em: %s" % caminho)
		inst.queue_free()


## Remove o "root motion" do Mixamo: a track de POSICAO do quadril desloca o
## corpo inteiro (deriva para frente no Walk/Run, flutua no Jump). O movimento
## real vem do CharacterBody (velocity), entao o quadril fica congelado na
## pose de descanso e so a rotacao dele anima. Pernas/bracos seguem normais.
func _remover_root_motion(clip: Animation) -> void:
	for i in range(clip.get_track_count() - 1, -1, -1):
		if not ("Hips" in String(clip.track_get_path(i))):
			continue
		if clip.track_get_key_count(i) == 0:
			continue
		# Tracks de POSICAO/ESCALA guardam Vector3; a de ROTACAO guarda
		# Quaternion e deve ser mantida (inclinacao do tronco etc).
		if typeof(clip.track_get_key_value(i, 0)) == TYPE_VECTOR3:
			clip.remove_track(i)


## Congela as pernas do pulo na pose de agacho: o clip do Mixamo alterna as
## pernas (parece "andar no ar"). Amostra a rotacao de cada osso da perna no
## instante do agacho e troca as tracks por pose estatica. Bracos/tronco
## continuam animados.
func _congelar_pernas_no_pulo(clip: Animation) -> void:
	for i in range(clip.get_track_count() - 1, -1, -1):
		var caminho := String(clip.track_get_path(i))
		var e_perna := false
		for osso in PERNAS_PULO:
			if caminho.ends_with(osso):
				e_perna = true
				break
		if not e_perna:
			continue
		if clip.track_get_key_count(i) == 0:
			continue
		if typeof(clip.track_get_key_value(i, 0)) != TYPE_QUATERNION:
			continue
		var pose: Quaternion = clip.rotation_track_interpolate(i, TEMPO_POSE_PULO)
		while clip.track_get_key_count(i) > 0:
			clip.track_remove_key(i, 0)
		clip.track_insert_key(i, 0.0, pose)


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_olhar(-(evento as InputEventMouseMotion).relative.x * sensibilidade_mouse, -(evento as InputEventMouseMotion).relative.y * sensibilidade_mouse)
	if evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var no_chao := is_on_floor()
	if not no_chao:
		velocity.y -= gravidade * delta
		_pulo_preparando = 0.0
	if Input.is_action_just_pressed("pular") and no_chao and _pulo_preparando <= 0.0:
		var velocidade_horizontal := Vector2(velocity.x, velocity.z).length()
		_pulo_em_corrida = velocidade_horizontal >= VELOCIDADE_MINIMA_RUNNING_JUMP
		_pulo_andando = velocidade_horizontal >= VELOCIDADE_MINIMA_ANDAR_PULO and not _pulo_em_corrida
		if _pulo_em_corrida:
			_pulo_preparando = ANTECIPACAO_PULO_CORRIDA
		elif _pulo_andando:
			_pulo_preparando = ANTECIPACAO_PULO_ANDANDO
		else:
			_pulo_preparando = ANTECIPACAO_PULO
	if _pulo_preparando > 0.0 and no_chao:
		_pulo_preparando -= delta
		# Nos saltos andando/correndo, preserva o embalo.
		# No salto parado, freia o corpo durante a antecipacao.
		if not _pulo_em_corrida and not _pulo_andando:
			velocity.x = move_toward(velocity.x, 0.0, FREIO_PULO * delta)
			velocity.z = move_toward(velocity.z, 0.0, FREIO_PULO * delta)
		velocity.y = 0.0
		if _pulo_preparando <= 0.0:
			velocity.y = forca_pulo
			_tocar_som_pulo()
	var entrada := Vector2(
		Input.get_axis("mover_esq", "mover_dir"),
		Input.get_axis("mover_frente", "mover_tras")
	)
	var vel := velocidade_correr if Input.is_action_pressed("correr") else velocidade_andar
	var base := rig.global_transform.basis
	var direcao: Vector3 = base * Vector3(entrada.x, 0.0, entrada.y)
	direcao.y = 0.0
	if direcao.length() > 0.01:
		direcao = direcao.normalized()
		var alvo_yaw := atan2(-direcao.x, -direcao.z)
		modelo.rotation.y = lerp_angle(modelo.rotation.y, alvo_yaw, 1.0 - exp(-10.0 * delta))
	if _pulo_preparando <= 0.0:
		velocity.x = direcao.x * vel
		velocity.z = direcao.z * vel
	move_and_slide()
	no_chao = is_on_floor()
	var em_movimento := entrada.length() > 0.01
	if no_chao and em_movimento:
		var intervalo_passo := 0.31 if Input.is_action_pressed("correr") else 0.48
		_tempo_entre_passos += delta
		if _tempo_entre_passos >= intervalo_passo:
			_tocar_som_passo(Input.is_action_pressed("correr"))
			_tempo_entre_passos = 0.0
	else:
		_tempo_entre_passos = 0.0
	if no_chao and not em_movimento:
		_tempo_parado += delta
	else:
		_tempo_parado = 0.0
	var animacao_movimento := "Run" if Input.is_action_pressed("correr") else "Walk"
	var animacao_alvo := "RunJump" if _pulo_em_corrida else ("WalkJump" if _pulo_andando else "Jump")
	if no_chao and _pulo_preparando <= 0.0:
		if em_movimento:
			animacao_alvo = animacao_movimento
		elif _tempo_parado >= tempo_sad_idle and _tem_animacao("SadIdle"):
			animacao_alvo = "SadIdle"
		else:
			animacao_alvo = "Idle"
	_atualizar_animacao(animacao_alvo)
	SaveSystem.dados["posicao_jogador"] = [position.x, position.y, position.z]


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_olhar_stick(delta)


func _olhar(dx: float, dy: float) -> void:
	rig.rotate_y(dx)
	_angulo_vertical = clampf(_angulo_vertical + dy, -1.2, 0.6)
	bracos_camera.rotation.x = _angulo_vertical


func _olhar_stick(delta: float) -> void:
	var joy := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if joy.length() < 0.2:
		return
	_olhar(-joy.x * sensibilidade_stick * delta, -joy.y * sensibilidade_stick * delta * 0.75)


func _tem_animacao(nome: String) -> bool:
	return animador != null and animador.has_animation(nome)


func _atualizar_animacao(nome: String) -> void:
	if animador == null:
		return
	# Match exato primeiro: evita "SadIdle" capturar o pedido de "Idle".
	var chave := ""
	if animador.has_animation(nome):
		chave = nome
	else:
		for candidata in animador.get_animation_list():
			if String(candidata).to_lower().ends_with(nome.to_lower()):
				chave = candidata
				break
	if chave == "":
		return
	var animacao := animador.get_animation(chave)
	if nome == "Walk" or nome == "Run":
		animacao.loop_mode = Animation.LOOP_LINEAR
	elif nome == "Idle" or nome == "SadIdle":
		# Ping-pong no parado: vai e volta sem "salto" de emenda do loop.
		animacao.loop_mode = Animation.LOOP_PINGPONG
	else:
		animacao.loop_mode = Animation.LOOP_NONE
	var trocar := _animacao_atual != chave
	var repetir_pulo := (nome == "Jump" or nome == "WalkJump" or nome == "RunJump") and not animador.is_playing()
	if trocar or repetir_pulo:
		var blend := BLEND_TERRA
		if nome == "Jump" or nome == "WalkJump" or nome == "RunJump":
			blend = BLEND_PULO_SAIDA
		elif _animacao_atual == "Jump" or _animacao_atual == "WalkJump" or _animacao_atual == "RunJump":
			blend = BLEND_POUSO
		# Alternar Walk<->Run preserva a fase da passada em vez de
		# recomecar o ciclo (evita o "solavanco" ao segurar o correr).
		var manter_fase := (chave == "Walk" or chave == "Run") and (_animacao_atual == "Walk" or _animacao_atual == "Run")
		var fase := 0.0
		if manter_fase and animador.is_playing():
			var antiga := animador.get_animation(_animacao_atual)
			if antiga != null and antiga.length > 0.0 and animacao.length > 0.0:
				fase = fposmod(animador.get_current_animation_position() / antiga.length, 1.0)
		animador.play(chave, blend)
		if manter_fase:
			animador.seek(fase * animacao.length, true)
		_animacao_atual = chave
