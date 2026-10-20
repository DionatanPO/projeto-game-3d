extends CharacterBody3D
## Skatista da descida do Pico da Nebulosa.
## Desce sozinho pela encosta, desvia com A/D, pula com Espaco e e lancado
## pelas rampas. A animacao de skate (Mixamo) vem do Skateboarding.fbx.

signal bateu
signal pulou

@export var aceleracao := 6.5
@export var velocidade_max := 27.0
@export var velocidade_min := 6.0
@export var forca_pulo := 2.8
@export var forca_rampa := 10.8
@export var lateral_max := 7.0
@export var lateral_aceleracao := 26.0
@export var gravidade := 30.0
@export var limite_lateral := 10.0

const GIRO_BASE := PI
const CENA_MODELO := preload("res://assets/models/Skateboarding.fbx")
const CENA_PRANCHA := preload("res://assets/models/PranchaNeve.glb")

var velocidade := 7.0
var ativo := false
var distancia := 0.0
var tombos := 0

var funcao_altura := Callable()

var _lateral := 0.0
var _contato_solo := false
var _invulneravel := 0.0
var _no_ar := false
var _tempo_no_ar := 0.0
var _pose_ar := false
var _modelo: Node3D
var _animador: AnimationPlayer
var _finalizando := false
# Interpolacao visual entre passos de fisica (o jogo renderiza acima de 60 Hz).
var _pos_antes := Vector3.ZERO
var _pos_depois := Vector3.ZERO
var _fisica_iniciada := false


func _ready() -> void:
	add_to_group("skatista")
	var col := get_node_or_null("Colisao") as CollisionShape3D
	if col != null and col.shape == null:
		var capsula := CapsuleShape3D.new()
		capsula.radius = 0.36
		capsula.height = 1.76
		col.shape = capsula
	_montar_modelo()
	_montar_prancha()
	collision_layer = 1
	collision_mask = 1
	floor_max_angle = deg_to_rad(60.0)
	floor_snap_length = 0.7


## Instancia o personagem e troca o clip unico por uma versao em loop, sem o
## root motion do quadril (senao o modelo desliza e volta a cada ciclo).
func _montar_modelo() -> void:
	_modelo = Node3D.new()
	_modelo.name = "Modelo"
	_modelo.rotation.y = GIRO_BASE
	add_child(_modelo)
	var inst := CENA_MODELO.instantiate() as Node3D
	inst.name = "Skate"
	# O FBX tem a origem no quadril; sobe para os pes ficarem na prancha.
	inst.position = Vector3(0.0, 0.84, 0.0)
	_modelo.add_child(inst)
	_animador = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _animador == null:
		return
	var lib := _animador.get_animation_library("")
	if lib == null or not lib.has_animation("mixamo_com"):
		return
	var clip := lib.get_animation("mixamo_com").duplicate() as Animation
	for i in range(clip.get_track_count() - 1, -1, -1):
		if "Hips" in String(clip.track_get_path(i)) \
				and typeof(clip.track_get_key_value(i, 0)) == TYPE_VECTOR3:
			clip.remove_track(i)
	clip.loop_mode = Animation.LOOP_LINEAR
	lib.add_animation("skate", clip)
	_animador.play("skate")


## Prancha de madeira real importada do Blender (substitui a versao temporaria
## montada em codigo com BoxMesh).
func _montar_prancha() -> void:
	var prancha := CENA_PRANCHA.instantiate() as Node3D
	prancha.name = "Prancha"
	prancha.position = Vector3(0.0, 0.035, 0.0)
	# A ponta da prancha deve apontar na direcao da descida (-Z)
	prancha.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	_modelo.add_child(prancha)


func _process(_delta: float) -> void:
	if _modelo == null:
		return
	# Ajusta so a posicao LOCAL: usar global_position aqui reconstruia a base
	# do no e a rotacao do modelo saia girando ao estercar.
	_modelo.position = posicao_visual() - global_position


## Posicao do modelo suavizada entre o passo de fisica anterior e o atual. A
## fisica roda a 60 Hz; se o monitor estiver a 75/144 Hz o corpo "pula" em
## degraus e o boneco treme. Isso anima o visual na taxa de renderizacao.
func posicao_visual() -> Vector3:
	if not _fisica_iniciada:
		return global_position
	var f := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	return _pos_antes.lerp(_pos_depois, f)


func _physics_process(delta: float) -> void:
	_pos_antes = global_position
	_fisica_iniciada = true
	if not ativo:
		_desacelerar(delta)
		_pos_depois = global_position
		return
	if _invulneravel > 0.0:
		_invulneravel -= delta
	if _finalizando:
		_desacelerar(delta)
		_pos_depois = global_position
		return

	var no_chao := is_on_floor() or _contato_solo
	if no_chao:
		# Encosta abaixo: acelera um pouco mais que no plano.
		velocidade += aceleracao * 0.85 * delta
		_no_ar = false
		_tempo_no_ar = 0.0
	else:
		velocidade -= aceleracao * 0.10 * delta
	velocidade = clampf(velocidade, 0.0, velocidade_max)

	var entrada := Input.get_axis("mover_esq", "mover_dir")
	_lateral = move_toward(_lateral, entrada * lateral_max, lateral_aceleracao * delta)

	if no_chao and Input.is_action_just_pressed("pular"):
		velocity.y = forca_pulo
		_no_ar = true
		_tempo_no_ar = 0.0
		pulou.emit()

	velocity.x = _lateral
	velocity.z = -velocidade
	if no_chao and velocity.y <= 0.0:
		velocity.y = -2.0
	else:
		velocity.y -= gravidade * delta
	velocity.y = maxf(velocity.y, -55.0)

	move_and_slide()
	_seguir_relevo()

	if absf(global_position.x) > limite_lateral:
		global_position.x = clampf(global_position.x, -limite_lateral, limite_lateral)
		_lateral = clampf(_lateral, -2.5, 2.5)
		velocidade = maxf(velocidade - 7.0 * delta, 0.0)

	if not is_on_floor() and not _contato_solo:
		_tempo_no_ar += delta
	distancia = maxf(distancia, -global_position.z)
	_atualizar_visual(delta)
	_pos_depois = global_position


## Mantem o skatista colado no relevo analitico da pista. Isso evita depender
## apenas do trimesh do chao (que pode falhar em rampas/velocidades altas).
func _seguir_relevo() -> void:
	if not funcao_altura.is_valid():
		return
	var chao := float(funcao_altura.call(-global_position.z, global_position.x))
	var alvo := chao + 0.08
	# As rampas ficam acima do relevo analitico. Enquanto o skatista estiver
	# apoiado numa delas, o trilho do chao nao pode puxa-lo para baixo: era
	# isso que travava o corpo na entrada da rampa.
	var na_rampa := _tocando_rampa()
	var colou := false
	if global_position.y < alvo:
		global_position.y = alvo
		if velocity.y < 0.0:
			velocity.y = 0.0
		colou = true
	elif not na_rampa and _contato_solo and velocity.y <= 0.0 and global_position.y < alvo + 0.55:
		global_position.y = alvo
		colou = true
	_contato_solo = colou or (na_rampa and is_on_floor())
	if _contato_solo:
		_no_ar = false


## Verdadeiro quando o ultimo move_and_slide encostou no corpo de uma rampa.
func _tocando_rampa() -> bool:
	for i in get_slide_collision_count():
		var alvo := get_slide_collision(i).get_collider()
		if alvo is Node and (alvo as Node).is_in_group("rampa"):
			return true
	return false


func _desacelerar(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 34.0 * delta)
	if not is_on_floor():
		velocity.y -= gravidade * delta
	else:
		velocity.y = -2.0
	move_and_slide()
	_seguir_relevo()
	if _animador != null:
		if _finalizando:
			_animador.speed_scale = lerpf(_animador.speed_scale, 0.7, 1.0 - exp(-6.0 * delta))
		else:
			# Contagem regressiva: o skatista espera parado e a animacao de
			# skate so comeca a rodar quando a descida realmente inicia.
			_animador.speed_scale = 0.0


func _atualizar_visual(delta: float) -> void:
	var alvo_roll := -_lateral * 0.045
	_modelo.rotation.z = lerpf(_modelo.rotation.z, alvo_roll, 1.0 - exp(-9.0 * delta))
	var alvo_yaw := GIRO_BASE + _lateral * 0.02
	_modelo.rotation.y = lerpf(_modelo.rotation.y, alvo_yaw, 1.0 - exp(-7.0 * delta))
	if _animador != null:
		# No ar o skatista nao "pedala": segura a pose inicial ate encostar
		# de novo no chao (o pe de impulso no ar ficava esquisito).
		if _tempo_no_ar > 0.15:
			if not _pose_ar:
				_pose_ar = true
				_animador.speed_scale = 0.0
				_animador.seek(0.0, true)
		else:
			_pose_ar = false
			_animador.speed_scale = clampf(0.8 + velocidade / 32.0, 0.8, 1.75)
	# No ar, inclina levemente o corpo para tras (sensacao de voo). Usa o mesmo
	# criterio do voo real: is_on_floor() fica falso no relevo analitico e
	# deixava o boneco inclinado para tras o tempo todo.
	var alvo_pitch := -0.10 if _tempo_no_ar > 0.15 else 0.0
	_modelo.rotation.x = lerpf(_modelo.rotation.x, alvo_pitch, 1.0 - exp(-6.0 * delta))


func lateral_atual() -> float:
	return _lateral


func leve_tombo() -> void:
	if _invulneravel > 0.0 or not ativo:
		return
	_invulneravel = 1.15
	tombos += 1
	velocidade *= 0.42
	_lateral = -_lateral * 0.35
	velocity.y = maxf(velocity.y, 2.0)
	bateu.emit()


func impulsionar(forca: float) -> void:
	if not ativo:
		return
	velocity.y = maxf(velocity.y, forca)
	velocidade = minf(velocidade + 2.5, velocidade_max + 2.0)
	_no_ar = true
	_tempo_no_ar = 0.0
	pulou.emit()


func finalizar() -> void:
	_finalizando = true
	ativo = false


func reposicionar(posicao: Vector3, nova_velocidade: float) -> void:
	global_position = posicao
	_pos_antes = posicao
	_pos_depois = posicao
	velocity = Vector3.ZERO
	velocidade = nova_velocidade
	_lateral = 0.0
	_invulneravel = 1.0
