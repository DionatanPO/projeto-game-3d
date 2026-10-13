extends CharacterBody3D
## Jogador em terceira pessoa: WASD relativo a camera, pulo, corrida, mouse.

@export var velocidade_andar := 4.5
@export var velocidade_correr := 7.0
@export var forca_pulo := 4.5
@export var sensibilidade_mouse := 0.003

@onready var bracos_camera: SpringArm3D = $BracosCamera

var gravidade: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _angulo_vertical := -0.35


func _ready() -> void:
	add_to_group("jogador")
	var pos: Variant = SaveSystem.dados.get("posicao_jogador", [0.0, 1.0, 14.0])
	if pos is Array and (pos as Array).size() == 3:
		position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-(evento as InputEventMouseMotion).relative.x * sensibilidade_mouse)
		_angulo_vertical = clampf(_angulo_vertical - (evento as InputEventMouseMotion).relative.y * sensibilidade_mouse, -1.2, 0.6)
		bracos_camera.rotation.x = _angulo_vertical
	if evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravidade * delta
	if Input.is_action_just_pressed("pular") and is_on_floor():
		velocity.y = forca_pulo
	var entrada := Vector2(
		Input.get_axis("mover_esq", "mover_dir"),
		Input.get_axis("mover_frente", "mover_tras")
	)
	var vel := velocidade_correr if Input.is_action_pressed("correr") else velocidade_andar
	var direcao: Vector3 = transform.basis * Vector3(entrada.x, 0.0, entrada.y)
	direcao.y = 0.0
	if direcao.length() > 0.01:
		direcao = direcao.normalized()
		# Gira o corpo na direcao do movimento (tank suave).
		var alvo_yaw := atan2(-direcao.x, -direcao.z)
		rotation.y = lerp_angle(rotation.y, alvo_yaw, 1.0 - exp(-10.0 * delta))
	velocity.x = direcao.x * vel
	velocity.z = direcao.z * vel
	move_and_slide()
	SaveSystem.dados["posicao_jogador"] = [position.x, position.y, position.z]


func _process(_delta: float) -> void:
	# Esc (ui_cancel) libera o mouse sem pausar o jogo.
	if Input.is_action_just_pressed("ui_cancel") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
