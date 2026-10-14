extends CharacterBody3D
## DroneJogador: drone agricola voador em terceira pessoa.
## Usa o corpo de drone_agricola.glb + 4 helices de elice_drone.glb
## posicionadas nos motores, girando em _process (sentidos alternados).
## Controles: WASD move (relativo a camera), Espaco sobe, C/Ctrl desce,
## Shift turbo, mouse olha (clique captura, Esc solta).

@export var velocidade_voo := 8.0
@export var velocidade_turbo := 16.0
@export var velocidade_vertical := 6.0
@export var aceleracao := 6.0
@export var altura_min := 0.0
@export var altura_max := 45.0
@export var helice_base := 20.0
@export var helice_cheia := 55.0
@export var sensibilidade_mouse := 0.003
@export var sensibilidade_stick := 2.8
@export var ligado := true

var gravidade: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _spool := 1.0

@onready var rig: Node3D = $CameraRig
@onready var cam: Camera3D = $CameraRig/Camera3D
@onready var modelo: Node3D = $Modelo
@onready var spray: GPUParticles3D = $Modelo/Pulverizador

var _helices: Array[Node3D] = []
var _dirs := [1.0, -1.0, -1.0, 1.0]
var _giro := 0.0
var _acelerador := 0.35
var _som: AudioStreamPlayer3D
var _angulo_vertical := -0.275

const POSICOES := [
	Vector3(1.803, 3.05, 1.803),
	Vector3(1.803, 3.05, -1.803),
	Vector3(-1.803, 3.05, 1.803),
	Vector3(-1.803, 3.05, -1.803),
]


func _ready() -> void:
	add_to_group("drone_jogador")
	for i in range(1, 5):
		_helices.append(modelo.get_node("Helice%02d" % i) as Node3D)
	cam.position = Vector3(0.0, 4.2, 8.5)
	cam.rotation = Vector3(_angulo_vertical, 0.0, 0.0)
	var pos: Variant = SaveSystem.dados.get("posicao_drone", [0.0, 3.0, 12.0])
	if pos is Array and (pos as Array).size() == 3:
		position = Vector3(float(pos[0]), clampf(float(pos[1]), 1.0, 15.0), float(pos[2]))
	modelo.rotation.y = PI * 0.5
	_som = AudioStreamPlayer3D.new()
	_som.name = "SomMotor"
	_som.stream = _gerar_zumbido()
	_som.volume_db = -12.0
	_som.max_distance = 80.0
	add_child(_som)
	_som.play()


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_olhar(-(evento as InputEventMouseMotion).relative.x * sensibilidade_mouse, -(evento as InputEventMouseMotion).relative.y * sensibilidade_mouse)
	if evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("ligar_motor"):
		ligado = not ligado
	if not ligado:
		_descer_desligado(delta)
		return
	var entrada := Vector2(
		Input.get_axis("mover_esq", "mover_dir"),
		Input.get_axis("mover_frente", "mover_tras")
	)
	var vertical := Input.get_axis("descer", "pular")
	var turbo := Input.is_action_pressed("correr")
	var vel_max := velocidade_turbo if turbo else velocidade_voo
	var base := rig.global_transform.basis
	var direcao: Vector3 = base * Vector3(entrada.x, 0.0, entrada.y)
	direcao.y = 0.0
	var alvo := Vector3.ZERO
	if direcao.length() > 0.01:
		alvo = direcao.normalized() * vel_max * minf(entrada.length(), 1.0)
	alvo.y = vertical * velocidade_vertical
	velocity = velocity.lerp(alvo, 1.0 - exp(-aceleracao * delta))
	move_and_slide()
	position.y = clampf(position.y, altura_min, altura_max)
	if Vector2(velocity.x, velocity.z).length() > 0.5:
		var alvo_yaw := atan2(-velocity.z, velocity.x)
		modelo.rotation.y = lerp_angle(modelo.rotation.y, alvo_yaw, 1.0 - exp(-6.0 * delta))
	# A frente do modelo e +X: arfagem (pitch) e rotation.z, rolagem e rotation.x.
	modelo.rotation.z = lerpf(modelo.rotation.z, entrada.y * 0.15, 1.0 - exp(-6.0 * delta))
	modelo.rotation.x = lerpf(modelo.rotation.x, entrada.x * 0.15, 1.0 - exp(-6.0 * delta))
	SaveSystem.dados["posicao_drone"] = [position.x, position.y, position.z]


## Motor desligado: sem comando, gravidade puxa ate pousar e o modelo nivela.
func _descer_desligado(delta: float) -> void:
	velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-3.0 * delta))
	velocity.z = lerpf(velocity.z, 0.0, 1.0 - exp(-3.0 * delta))
	velocity.y -= gravidade * delta
	move_and_slide()
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	position.y = clampf(position.y, 0.0, altura_max)
	modelo.rotation.x = lerpf(modelo.rotation.x, 0.0, 1.0 - exp(-4.0 * delta))
	modelo.rotation.z = lerpf(modelo.rotation.z, 0.0, 1.0 - exp(-4.0 * delta))


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_olhar_stick(delta)
	spray.emitting = ligado and Input.is_action_pressed("pulverizar")
	var acelerador := clampf(0.35 + 0.65 * clampf(Vector2(velocity.x, velocity.z).length() / velocidade_turbo + velocity.y / velocidade_vertical, -1.0, 1.0), 0.0, 1.0)
	_acelerador = acelerador
	# Spool do motor: sobe/desce suave ao ligar/desligar.
	_spool = move_toward(_spool, 1.0 if ligado else 0.0, delta * 0.7)
	if ligado and not _som.playing:
		_som.play()
	elif not ligado and _spool <= 0.02 and _som.playing:
		_som.stop()
	_giro = lerpf(_giro, _spool * lerpf(helice_base, helice_cheia, acelerador), 1.0 - exp(-3.0 * delta))
	for i in _helices.size():
		_helices[i].rotate_y(_dirs[i] * _giro * delta)
	if _som != null and _som.playing:
		var eff := _acelerador * _spool
		_som.pitch_scale = 0.5 + 0.7 * eff
		_som.volume_db = lerpf(-30.0, -8.0, eff)


func _olhar(dx: float, dy: float) -> void:
	rig.rotate_y(dx)
	_angulo_vertical = clampf(_angulo_vertical + dy, -1.1, 0.5)
	cam.rotation.x = _angulo_vertical


func _olhar_stick(delta: float) -> void:
	var joy := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if joy.length() < 0.2:
		return
	_olhar(-joy.x * sensibilidade_stick * delta, -joy.y * sensibilidade_stick * delta * 0.75)


## Sintetiza 1 s de zumbido de motor (loop perfeito: todas as
## frequencias sao inteiras em Hz) e devolve como WAV em 16 bits.
func _gerar_zumbido() -> AudioStreamWAV:
	var taxa := 22050
	var n := taxa
	var dados := PackedByteArray()
	dados.resize(n * 2)
	# Passa-altas duplo (12 dB/oitava) em ~280 Hz: corta o grave do motor.
	var rc := 1.0 / (TAU * 280.0)
	var dt := 1.0 / float(taxa)
	var a := rc / (rc + dt)
	var y1_ant := 0.0
	var x_ant := 0.0
	var y2_ant := 0.0
	var y1_ant2 := 0.0
	for i in n:
		var t := float(i) / float(taxa)
		# Fundamental 78 -> 104 Hz; presenca aguda em 2-4 kHz.
		var base := 0.20 * _serra(104.0, t) + 0.28 * _serra(208.0, t) + 0.24 * _serra(312.0, t) + 0.14 * _serra(2080.0, t) + 0.10 * _serra(3120.0, t) + 0.06 * _serra(4160.0, t)
		var pas := 0.70 + 0.30 * sin(TAU * 29.0 * t)
		var ar := 0.025 * (sin(TAU * 1567.0 * t) + 0.6 * sin(TAU * 2093.0 * t))
		var x := clampf(base * pas * 0.8 + ar, -1.0, 1.0)
		var y1 := a * (y1_ant + x - x_ant)
		var y2 := a * (y2_ant + y1 - y1_ant2)
		y1_ant = y1
		x_ant = x
		y2_ant = y2
		y1_ant2 = y1
		dados.encode_s16(i * 2, int(clampf(y2 * 1.5, -1.0, 1.0) * 32760.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = taxa
	wav.stereo = false
	wav.data = dados
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav


func _serra(freq: float, t: float) -> float:
	return fmod(freq * t, 1.0) * 2.0 - 1.0
