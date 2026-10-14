extends CharacterBody3D
## Jogador em terceira pessoa: camera independente (mouse/stick direito),
## movimento relativo a camera, malha gira ate o movimento. Suporta teclado
## e controle (Xbox: stick esquerdo move, direito olha, A pula, X interage,
## Y diario, LB corre).

@export var velocidade_andar := 4.5
@export var velocidade_correr := 7.0
@export var forca_pulo := 4.5
@export var sensibilidade_mouse := 0.003
@export var sensibilidade_stick := 2.8

@onready var rig: Node3D = $CameraRig
@onready var bracos_camera: SpringArm3D = $CameraRig/BracosCamera
@onready var modelo: Node3D = $Modelo

var gravidade: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _angulo_vertical := -0.35


func _ready() -> void:
    add_to_group("jogador")
    var pos: Variant = SaveSystem.dados.get("posicao_jogador", [-96.79012, 1.5, 0.73486805])
    if pos is Array and (pos as Array).size() == 3:
        position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))


func _unhandled_input(evento: InputEvent) -> void:
    if evento is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        _olhar(-(evento as InputEventMouseMotion).relative.x * sensibilidade_mouse, -(evento as InputEventMouseMotion).relative.y * sensibilidade_mouse)
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
    var base := rig.global_transform.basis
    var direcao: Vector3 = base * Vector3(entrada.x, 0.0, entrada.y)
    direcao.y = 0.0
    if direcao.length() > 0.01:
        direcao = direcao.normalized()
        var alvo_yaw := atan2(-direcao.x, -direcao.z)
        modelo.rotation.y = lerp_angle(modelo.rotation.y, alvo_yaw, 1.0 - exp(-10.0 * delta))
    velocity.x = direcao.x * vel
    velocity.z = direcao.z * vel
    move_and_slide()
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