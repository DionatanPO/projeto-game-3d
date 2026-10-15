extends Area3D
## TrocaDrone: estacao no galpao. Perto do drone a pe -> "E usa o drone".
## Pilotando e perto do corpo -> "E desce". Troca camera + fisica.
## Drone fica com colisao e visual fundidos (prefab), some junto se excluir.

const RAIO := 6.0
const HOME_DRONE := Vector3(15.5, 1.0, 3.4)

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
  await get_tree().process_frame
  await get_tree().process_frame
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

func _on_entrou(corpo: Node3D) -> void:
  if _a_pe and corpo.is_in_group("jogador"):
    _perto = true
    _prompt.text = "Pressione E para usar o drone"
    _prompt.visible = true
  elif not _a_pe and corpo.is_in_group("drone_jogador"):
    _perto = true
    _prompt.text = "Pressione E para descer do drone"
    _prompt.visible = true

func _on_saiu(corpo: Node3D) -> void:
  if corpo.is_in_group("jogador") or corpo.is_in_group("drone_jogador"):
    _perto = false
    _prompt.visible = false

func _unhandled_input(evento: InputEvent) -> void:
  if _perto and evento.is_action_pressed("interagir"):
    if _a_pe:
      _ativar_drone(true)
    else:
      _ativar_jogador(true)
    get_viewport().set_input_as_handled()

func _set_ativo(corpo: CharacterBody3D, ativo: bool) -> void:
  if corpo == null:
    return
  if corpo.is_in_group("drone_jogador") and not ativo:
    # Estacionado: mantem a fisica para ele pousar sozinho em vez de
    # ficar congelado flutuando (ligado=false desce por gravidade).
    corpo.set_physics_process(true)
  else:
    corpo.set_physics_process(ativo)
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
