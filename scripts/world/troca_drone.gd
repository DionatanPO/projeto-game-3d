extends Area3D
## TrocaDrone: estacao no galpao. Perto do drone a pe -> "E usa o drone".
## Pilotando e perto do corpo -> "E desce". Troca camera + fisica.
## Drone fica com colisao e visual fundidos (prefab), some junto se excluir.

const RAIO := 6.0
const RAIO_PERTO := 9.0
const HOME_DRONE := Vector3(7.2, 1.0, 1.0)

var _prompt: Label3D
var _jogador: CharacterBody3D
var _drone: CharacterBody3D
var _a_pe := true
var _perto := false

func _ready() -> void:
	var col := CollisionShape3D.new()
	col.name = "Raio"
	var esf := SphereShape3D.new()
	esf.radius = RAIO
	col.shape = esf
	add_child(col)
	_prompt = Label3D.new()
	_prompt.name = "Aviso"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.position = Vector3(0, 3.2, 0)
	_prompt.font_size = 64
	_prompt.text = "Pressione E para usar o drone"
	_prompt.visible = false
	add_child(_prompt)
	body_entered.connect(_on_entrou)
	body_exited.connect(_on_saiu)
	_jogador = get_tree().get_first_node_in_group("jogador") as CharacterBody3D
	_drone = get_tree().get_first_node_in_group("drone_jogador") as CharacterBody3D
	if _drone != null and _drone.position.length() < 0.5:
		_drone.position = HOME_DRONE
	var v: String = str(SaveSystem.dados.get("veiculo", "jogador"))
	if v == "drone" and _jogador != null and _drone != null:
		_ativar_drone(false)
	elif v == "trator":
		# Trator ativo: a estacao dele (embutida na cena) assume; aqui so
		# garantimos que jogador e drone fiquem desligados.
		_set_ativo(_jogador, false)
		_set_ativo(_drone, false)
	else:
		_ativar_jogador(false)
	# Aguarda a broadphase antes de sincronizar corpos ja dentro da Area.
	for i in 4:
		await get_tree().physics_frame
	# Areas nao emitem body_entered para corpos que ja estavam dentro
	# no carregamento: sincroniza manualmente apos o boot.
	for corpo in get_overlapping_bodies():
		_on_entrou(corpo)

## Distancia real ate o drone. A Area da estacao fica fixa na origem e o drone
## voa, entao quem decide o "perto" a pe e a distancia ate o drone.
## Obs.: a Area tambem detecta o terreno e a sede (StaticBody3D), entao
## get_overlapping_bodies() nunca fica vazio e NAO serve como criterio aqui.
func _drone_ao_alcance() -> bool:
	if _drone == null or not is_instance_valid(_drone):
		return false
	if _jogador == null or not is_instance_valid(_jogador):
		return false
	return (_drone as Node3D).global_position.distance_to(_jogador.global_position) < RAIO_PERTO


func _on_entrou(corpo: Node3D) -> void:
	if _a_pe and corpo.is_in_group("jogador"):
		# A Area tambem acusa terreno/sede: so vale se o drone estiver perto.
		if not _drone_ao_alcance():
			return
		_perto = true
		_prompt.text = "E pegar o drone  •  T tutorial"
		_prompt.visible = true
	elif not _a_pe and corpo.is_in_group("drone_jogador"):
		_perto = true
		_prompt.text = "Pressione E para descer do drone"
		_prompt.visible = true

func _on_saiu(corpo: Node3D) -> void:
	# So limpa se o corpo relevante saiu mesmo: a pe importa o jogador,
	# voando importa o drone. A reconferencia ignora pares exit/enter
	# espurios do boot (o corpo continua sobreposto na Area).
	var saida_jogador := _a_pe and corpo.is_in_group("jogador")
	var saida_drone := not _a_pe and corpo.is_in_group("drone_jogador")
	if not saida_jogador and not saida_drone:
		return
	for outro in get_overlapping_bodies():
		if outro == corpo:
			continue
		if saida_jogador and outro.is_in_group("jogador"):
			return
		if saida_drone and outro.is_in_group("drone_jogador"):
			return
	_perto = false
	_prompt.visible = false


## Redundancia por distancia: garante o embarque mesmo se o sinal
## da Area falhar (ex.: teleportes, mudanca de pai/rotacao da estacao).
func _physics_process(_delta: float) -> void:
	if _jogador == null or not is_instance_valid(_jogador):
		_jogador = get_tree().get_first_node_in_group("jogador") as CharacterBody3D
	if _drone == null or not is_instance_valid(_drone):
		_drone = get_tree().get_first_node_in_group("drone_jogador") as CharacterBody3D
	if _a_pe and is_instance_valid(_jogador) and is_instance_valid(_drone) and _jogador.visible:
		if _drone_ao_alcance():
			if not _perto:
				_on_entrou(_jogador)
		elif _perto:
			# Andou pra longe do drone: nao da mais para embarcar. Precisa ser
			# por distancia: a Area pega terreno/sede e nunca fica vazia.
			_perto = false
			_prompt.visible = false


## O aviso fica grudado no drone (que se move); nao na estacao fixa.
## Voando: E sempre desce; texto so aparece parado (sem texto em voo).
func _process(_delta: float) -> void:
	if _prompt == null or not is_instance_valid(_drone):
		return
	_prompt.global_position = _drone.global_position + Vector3(0, 3.2, 0)
	if not _a_pe:
		_perto = true
		_prompt.visible = (_drone as CharacterBody3D).velocity.length() < 1.5


func _trator_mais_perto() -> bool:
	if _jogador == null or not is_instance_valid(_jogador) or _drone == null:
		return false
	var t := get_tree().get_first_node_in_group("trator_jogador") as Node3D
	if t == null:
		return false
	var d_drone := (_drone as Node3D).global_position.distance_to(_jogador.global_position)
	var d_trator := t.global_position.distance_to(_jogador.global_position)
	return d_trator < 6.5 and d_trator < d_drone


func _unhandled_input(evento: InputEvent) -> void:
	if not _perto:
		return
	var abrir_tutorial := _a_pe and evento.is_action_pressed("tutorial_drone")
	var interagir_drone := evento.is_action_pressed("interagir")
	if not abrir_tutorial and not interagir_drone:
		return

	if abrir_tutorial:
		# change_scene_to_file() tira a cena atual da arvore na hora (Godot 4.2+),
		# entao o input tem de ser marcado como tratado ANTES da troca: depois
		# dela get_viewport() e null.
		get_viewport().set_input_as_handled()
		_ir_tutorial()
		return
	if _a_pe:
		if _jogador == null or not _jogador.visible:
			return
		if _trator_mais_perto():
			return
		_ativar_drone(true)
	else:
		_ativar_jogador(true)
	get_viewport().set_input_as_handled()

## Abre o treino. A conclusao e registrada somente ao vencer.
func _ir_tutorial() -> void:
	get_tree().change_scene_to_file("res://scenes/world/tutorial_drone.tscn")



func _set_ativo(corpo: CharacterBody3D, ativo: bool) -> void:
	if corpo == null:
		return
	if corpo.is_in_group("drone_jogador") and not ativo:
		# Estacionado: mantem a fisica para ele pousar sozinho em vez de
		# ficar congelado flutuando (ligado=false desce por gravidade).
		corpo.set_physics_process(true)
	else:
		corpo.set_physics_process(ativo)
		if not corpo.is_in_group("drone_jogador"):
			corpo.visible = ativo
	corpo.set_process_unhandled_input(ativo)
	var cam := corpo.get_node_or_null("CameraRig/BracosCamera/Camera3D") as Camera3D
	if cam == null:
		cam = corpo.get_node_or_null("CameraRig/Camera3D") as Camera3D
	if cam != null:
		cam.current = ativo
	var col := corpo.get_node_or_null("Colisao") as CollisionShape3D
	if col != null:
		(col as CollisionShape3D).set_deferred("disabled", not ativo)
	if corpo.is_in_group("drone_jogador"):
		corpo.set("ligado", ativo)
		if not ativo:
			corpo.velocity = Vector3.ZERO

func _ativar_drone(salvar: bool) -> void:
	if _jogador == null or _drone == null:
		return
	_a_pe = false
	_set_ativo(_jogador, false)
	_set_ativo(_drone, true)
	_prompt.text = "Pressione E para descer do drone"
	if salvar:
		SaveSystem.dados["veiculo"] = "drone"
		SaveSystem.salvar()

func _ativar_jogador(salvar: bool) -> void:
	if _jogador == null or _drone == null:
		return
	# desce o jogador ao lado do drone pousado
	if salvar and _drone != null:
		_jogador.position = _drone.position + Vector3(2.0, 1.0, 0.0)
		_jogador.velocity = Vector3.ZERO
	_a_pe = true
	_set_ativo(_drone, false)
	_set_ativo(_jogador, true)
	_prompt.text = "Pressione E para usar o drone"
	if salvar:
		SaveSystem.dados["veiculo"] = "jogador"
		SaveSystem.salvar()

