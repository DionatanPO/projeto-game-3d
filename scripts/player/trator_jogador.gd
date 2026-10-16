extends CharacterBody3D
## TratorJogador: trator dirigivel em terceira pessoa, reutilizavel.
## Instancie 'res://scenes/world/trator_jogador.tscn' em qualquer cenario ou
## no mundo que ele funciona sozinho (estacao de embarque embutida).
## Segue o padrao do drone (scripts/player/drone_jogador.gd + troca_drone.gd):
## perto a pe -> "E usa o trator"; dirigindo -> "E desce".
## Corpo = trator.glb; rodas = roda_trator.glb (dianteiras menores e estercam,
## traseiras maiores, todas giram conforme a velocidade).
## Sons sintetizados em codigo como o drone (motor diesel + buzina + re).

const HOME_TRATOR := Vector3(13.0, 0.7, -7.0)
const RAIO_ESTACAO := 4.5

@export var velocidade_max := 9.0
@export var velocidade_re := 3.5
@export var aceleracao := 3.5
@export var freio := 7.0
@export var taxa_guinada := 1.6
@export var angulo_max_direcao := 0.55
@export var raio_roda_dianteira := 0.6
@export var raio_roda_traseira := 0.85
@export var sensibilidade_mouse := 0.003
@export var sensibilidade_stick := 2.8

const BASE_RIG_Y := PI * 0.5

var gravidade: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var ativo := false

var _vel := 0.0
var _esterco := 0.0
var _gas := 0.0
var _jogador: CharacterBody3D
var _jogador_perto := false
var _prompt: Label3D
var _som_motor: AudioStreamPlayer3D
var _som_buzina: AudioStreamPlayer3D
var _som_re: AudioStreamPlayer3D
var _tempo_beep := 0.0
var _angulo_vertical := -0.32

@onready var rig: Node3D = $CameraRig
@onready var bracos: SpringArm3D = $CameraRig/BracosCamera
@onready var cam: Camera3D = $CameraRig/BracosCamera/Camera3D
@onready var modelo: Node3D = $Modelo
@onready var pivo_esq: Node3D = $Modelo/PivoDianteiroEsq
@onready var pivo_dir: Node3D = $Modelo/PivoDianteiroDir
@onready var eixo_de: Node3D = $Modelo/PivoDianteiroEsq/EixoDE
@onready var eixo_dd: Node3D = $Modelo/PivoDianteiroDir/EixoDD
@onready var eixo_te: Node3D = $Modelo/EixoTE
@onready var eixo_td: Node3D = $Modelo/EixoTD
@onready var estacao: Area3D = $Estacao


func _ready() -> void:
	add_to_group("trator_jogador")
	_montar_estacao()
	_som_motor = AudioStreamPlayer3D.new()
	_som_motor.name = "SomMotor"
	_som_motor.stream = _gerar_motor_diesel()
	_som_motor.max_distance = 60.0
	_som_motor.volume_db = -60.0
	if AudioServer.get_bus_index("Efeitos") >= 0:
		_som_motor.bus = "Efeitos"
	add_child(_som_motor)
	_som_buzina = AudioStreamPlayer3D.new()
	_som_buzina.name = "SomBuzina"
	_som_buzina.stream = _gerar_buzina()
	_som_buzina.max_distance = 80.0
	if AudioServer.get_bus_index("Efeitos") >= 0:
		_som_buzina.bus = "Efeitos"
	add_child(_som_buzina)
	_som_re = AudioStreamPlayer3D.new()
	_som_re.name = "SomRe"
	_som_re.stream = _gerar_beep_re()
	_som_re.max_distance = 40.0
	if AudioServer.get_bus_index("Efeitos") >= 0:
		_som_re.bus = "Efeitos"
	add_child(_som_re)
	var pos: Variant = SaveSystem.dados.get("posicao_trator", [HOME_TRATOR.x, HOME_TRATOR.y, HOME_TRATOR.z])
	if pos is Array and (pos as Array).size() == 3:
		position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	cam.current = false
	await get_tree().process_frame
	await get_tree().process_frame
	_assentar_no_chao()
	_jogador = get_tree().get_first_node_in_group("jogador") as CharacterBody3D
	if str(SaveSystem.dados.get("veiculo", "jogador")) == "trator":
		_entrar(true)


func _assentar_no_chao() -> void:
	# Save antigo ou cenario sem chao no ponto: raio para baixo e assenta;
	# sem chao, volta para HOME em vez de cair no vazio.
	var espaco := get_world_3d().direct_space_state
	var consulta := PhysicsRayQueryParameters3D.create(position + Vector3(0, 3, 0), position + Vector3(0, -80, 0))
	consulta.collision_mask = 1
	consulta.exclude = [get_rid()]
	var batida := espaco.intersect_ray(consulta)
	if batida.has("position"):
		position.y = (batida["position"] as Vector3).y + 0.15
	else:
		position = HOME_TRATOR


func _montar_estacao() -> void:
	estacao.collision_layer = 0
	estacao.collision_mask = 1
	var col := CollisionShape3D.new()
	col.name = "Raio"
	var esf := SphereShape3D.new()
	esf.radius = RAIO_ESTACAO
	col.shape = esf
	estacao.add_child(col)
	_prompt = Label3D.new()
	_prompt.name = "Aviso"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.position = Vector3(0, 3.6, 0)
	_prompt.font_size = 64
	_prompt.text = "Pressione E para usar o trator"
	_prompt.visible = false
	add_child(_prompt)
	estacao.body_entered.connect(_on_corpo_entrou)
	estacao.body_exited.connect(_on_corpo_saiu)


func _on_corpo_entrou(corpo: Node3D) -> void:
	if ativo or _jogador_perto:
		return
	if corpo.is_in_group("jogador"):
		_jogador = corpo as CharacterBody3D
		_jogador_perto = true
		_prompt.text = "Pressione E para usar o trator"
		_prompt.visible = true


func _on_corpo_saiu(corpo: Node3D) -> void:
	if corpo.is_in_group("jogador"):
		_jogador_perto = false
		_prompt.visible = false


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion and ativo and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_olhar(-(evento as InputEventMouseMotion).relative.x * sensibilidade_mouse, -(evento as InputEventMouseMotion).relative.y * sensibilidade_mouse)
	if evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed:
		if ativo and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if evento.is_action_pressed("interagir"):
		if ativo:
			_sair()
			get_viewport().set_input_as_handled()
		elif _jogador != null and _jogador.visible and global_position.distance_to(_jogador.global_position) < RAIO_ESTACAO + 2.0:
			_entrar(false)
			get_viewport().set_input_as_handled()
	if ativo and evento.is_action_pressed("buzinar"):
		if not _som_buzina.playing:
			_som_buzina.play()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravidade * delta
	elif velocity.y < 0.0:
		velocity.y = -0.5
	if ativo:
		_gas = Input.get_axis("mover_tras", "mover_frente")
		var comando_dir := Input.get_axis("mover_dir", "mover_esq")
		_esterco = lerpf(_esterco, comando_dir, 1.0 - exp(-8.0 * delta))
		var alvo := 0.0
		if _gas > 0.05:
			alvo = _gas * velocidade_max
		elif _gas < -0.05:
			alvo = _gas * velocidade_re
		var taxa := aceleracao if absf(alvo) > absf(_vel) else freio
		_vel = move_toward(_vel, alvo, taxa * delta)
		if absf(_vel) > 0.05:
			rotate_y(_esterco * taxa_guinada * clampf(absf(_vel) / 3.0, 0.0, 1.0) * signf(_vel) * delta)
		var frente := -global_transform.basis.x
		frente.y = 0.0
		frente = frente.normalized()
		velocity.x = frente.x * _vel
		velocity.z = frente.z * _vel
		SaveSystem.dados["posicao_trator"] = [position.x, position.y, position.z]
	else:
		_vel = move_toward(_vel, 0.0, freio * delta)
		_esterco = lerpf(_esterco, 0.0, 1.0 - exp(-6.0 * delta))
		velocity.x = move_toward(velocity.x, 0.0, freio * delta)
		velocity.z = move_toward(velocity.z, 0.0, freio * delta)
		_sincronizar_proximidade()
	move_and_slide()


## Redundancia por distancia: mostra o prompt mesmo se o sinal da Area falhar.
func _sincronizar_proximidade() -> void:
	if ativo:
		return
	if _jogador == null or not is_instance_valid(_jogador):
		_jogador = get_tree().get_first_node_in_group("jogador") as CharacterBody3D
	if _jogador == null or not _jogador.visible:
		_prompt.visible = false
		return
	if _jogador_perto:
		return
	if global_position.distance_to(_jogador.global_position) < RAIO_ESTACAO + 2.0:
		_on_corpo_entrou(_jogador)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not ativo and _jogador != null and is_instance_valid(_jogador):
		_prompt.text = "Pressione E para usar o trator (%.1f m)" % global_position.distance_to(_jogador.global_position)
		if _jogador.visible:
			var perto := global_position.distance_to(_jogador.global_position) < RAIO_ESTACAO + 2.0
			if perto and not _jogador_perto:
				_on_corpo_entrou(_jogador)
			elif not perto and _jogador_perto and estacao.get_overlapping_bodies().is_empty():
				_jogador_perto = false
				_prompt.visible = false
	if not ativo:
		return
	_olhar_stick(delta)
	# Direcao: dianteiras estercam, todas giram conforme a velocidade.
	pivo_esq.rotation.y = _esterco * angulo_max_direcao
	pivo_dir.rotation.y = _esterco * angulo_max_direcao
	eixo_de.rotate_z(_vel / raio_roda_dianteira * delta)
	eixo_dd.rotate_z(_vel / raio_roda_dianteira * delta)
	eixo_te.rotate_z(_vel / raio_roda_traseira * delta)
	eixo_td.rotate_z(_vel / raio_roda_traseira * delta)
	# Motor diesel acompanha o esforco.
	var eff := clampf(absf(_vel) / velocidade_max * 0.7 + absf(_gas) * 0.3, 0.0, 1.0)
	if not _som_motor.playing:
		_som_motor.play()
	_som_motor.pitch_scale = 0.75 + 0.9 * eff
	_som_motor.volume_db = lerpf(-18.0, -6.0, eff)
	# Beep de marcha a re.
	if _vel < -0.5:
		_tempo_beep -= delta
		if _tempo_beep <= 0.0:
			_som_re.play()
			_tempo_beep = 0.7
	else:
		_tempo_beep = 0.0


func _olhar(dx: float, dy: float) -> void:
	rig.rotate_y(dx)
	_angulo_vertical = clampf(_angulo_vertical + dy, -1.1, 0.5)
	bracos.rotation.x = _angulo_vertical


func _olhar_stick(delta: float) -> void:
	var joy := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if joy.length() < 0.2:
		return
	_olhar(-joy.x * sensibilidade_stick * delta, -joy.y * sensibilidade_stick * delta * 0.75)


func _set_jogador(ativo_jogador: bool) -> void:
	if _jogador == null:
		_jogador = get_tree().get_first_node_in_group("jogador") as CharacterBody3D
	if _jogador == null:
		return
	_jogador.set_physics_process(ativo_jogador)
	_jogador.set_process_unhandled_input(ativo_jogador)
	_jogador.visible = ativo_jogador
	var cam_j := _jogador.get_node_or_null("CameraRig/BracosCamera/Camera3D") as Camera3D
	if cam_j != null:
		cam_j.current = ativo_jogador
	var col := _jogador.get_node_or_null("Colisao") as CollisionShape3D
	if col != null:
		(col as CollisionShape3D).set_deferred("disabled", not ativo_jogador)


func _entrar(silencioso: bool) -> void:
	_set_jogador(false)
	ativo = true
	rig.rotation.y = BASE_RIG_Y
	cam.current = true
	_prompt.visible = false
	_jogador_perto = false
	if not silencioso:
		SaveSystem.dados["veiculo"] = "trator"
		SaveSystem.salvar()


func _sair() -> void:
	if _jogador == null:
		_jogador = get_tree().get_first_node_in_group("jogador") as CharacterBody3D
	if _jogador != null:
		_jogador.position = global_position + global_transform.basis.z * 2.8 + Vector3(0, 1.0, 0)
		_jogador.velocity = Vector3.ZERO
	_set_jogador(true)
	ativo = false
	_vel = 0.0
	cam.current = false
	if _som_motor.playing:
		_som_motor.stop()
	SaveSystem.dados["veiculo"] = "jogador"
	SaveSystem.salvar()


## Diesel 4 tempos: serra grave 55 Hz + harmonicos, pulsacao de 13 Hz e
## ruido de escape. Loop perfeito de 1 s (frequencias inteiras em Hz).
func _gerar_motor_diesel() -> AudioStreamWAV:
	var taxa := 22050
	var n := taxa
	var dados := PackedByteArray()
	dados.resize(n * 2)
	for i in n:
		var t := float(i) / float(taxa)
		var base := 0.34 * _serra(55.0, t) + 0.24 * _serra(110.0, t) + 0.14 * _serra(165.0, t) + 0.10 * _serra(220.0, t)
		var pulso := 0.65 + 0.35 * sin(TAU * 26.0 * t)
		var ar := 0.05 * (sin(TAU * 1244.0 * t) + 0.5 * sin(TAU * 1866.0 * t))
		var x := clampf(base * pulso * 0.7 + ar, -1.0, 1.0)
		dados.encode_s16(i * 2, int(x * 32760.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = taxa
	wav.stereo = false
	wav.data = dados
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav


## Buzina: bip curto e agudo (0.25 s, serras em 880 + 1174 Hz).
func _gerar_buzina() -> AudioStreamWAV:
	var taxa := 22050
	var n := int(taxa * 0.25)
	var dados := PackedByteArray()
	dados.resize(n * 2)
	for i in n:
		var f := float(i) / float(n)
		var t := float(i) / float(taxa)
		var env := minf(f * 12.0, 1.0) * minf((1.0 - f) * 8.0, 1.0)
		var x := (0.4 * _serra(880.0, t) + 0.4 * _serra(1174.0, t)) * env * 0.6
		dados.encode_s16(i * 2, int(clampf(x, -1.0, 1.0) * 32760.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = taxa
	wav.stereo = false
	wav.data = dados
	return wav


## Beep de re: seno 880 Hz com 0.25 s e bordas suavizadas.
func _gerar_beep_re() -> AudioStreamWAV:
	var taxa := 22050
	var n := int(taxa * 0.25)
	var dados := PackedByteArray()
	dados.resize(n * 2)
	for i in n:
		var f := float(i) / float(n)
		var env := minf(f * 10.0, 1.0) * minf((1.0 - f) * 10.0, 1.0)
		var x := sin(TAU * 880.0 * float(i) / float(taxa)) * env * 0.5
		dados.encode_s16(i * 2, int(x * 32760.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = taxa
	wav.stereo = false
	wav.data = dados
	return wav


func _serra(freq: float, t: float) -> float:
	return fmod(freq * t, 1.0) * 2.0 - 1.0
