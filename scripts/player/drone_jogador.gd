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
@export var altura_min := 0.8
@export var altura_max := 45.0
@export var helice_base := 20.0
@export var helice_cheia := 55.0
@export var sensibilidade_mouse := 0.003
@export var sensibilidade_stick := 2.8

@onready var rig: Node3D = $CameraRig
@onready var cam: Camera3D = $CameraRig/Camera3D
@onready var modelo: Node3D = $Modelo

var _helices: Array[Node3D] = []
var _dirs := [1.0, -1.0, -1.0, 1.0]
var _giro := 0.0
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
		position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	modelo.rotation.y = PI * 0.5


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_olhar(-(evento as InputEventMouseMotion).relative.x * sensibilidade_mouse, -(evento as InputEventMouseMotion).relative.y * sensibilidade_mouse)
	if evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
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


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_olhar_stick(delta)
	var acelerador := clampf(0.35 + 0.65 * clampf(Vector2(velocity.x, velocity.z).length() / velocidade_turbo + absf(velocity.y) / velocidade_vertical, 0.0, 1.0), 0.0, 1.0)
	_giro = lerpf(helice_base, helice_cheia, acelerador)
	for i in _helices.size():
		_helices[i].rotate_y(_dirs[i] * _giro * delta)


func _olhar(dx: float, dy: float) -> void:
	rig.rotate_y(dx)
	_angulo_vertical = clampf(_angulo_vertical + dy, -1.1, 0.5)
	cam.rotation.x = _angulo_vertical


func _olhar_stick(delta: float) -> void:
	var joy := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if joy.length() < 0.2:
		return
	_olhar(-joy.x * sensibilidade_stick * delta, -joy.y * sensibilidade_stick * delta * 0.75)
