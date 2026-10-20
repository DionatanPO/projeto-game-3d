extends Area3D
## Portal de entrada da fase "Descida do Pico da Nebulosa".
## Fica no cume da montanha mais alta do mundo (Pico da Nebulosa); o jogador
## chega perto e pressiona E para descer de skate pela encosta.

const CENA_FASE := "res://scenes/world/descida/descida_pico.tscn"
const CENA_LOADING := "res://scenes/ui/menus/loading.tscn"
const PICO := Vector2(-135.0, -125.0)
const ALTURA_FALLBACK := 54.71
const RAIO_INTERACAO := 6.0

var _prompt: Label3D
var _titulo: Label3D
var _luz: OmniLight3D
var _anel: MeshInstance3D
var _perto := false
var _entrando := false
var _tempo := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var altura := ALTURA_FALLBACK
	var cena_atual := get_tree().current_scene
	if cena_atual != null:
		var terreno := cena_atual.get_node_or_null("Terreno")
		if terreno != null and terreno.has_method("altura"):
			altura = float(terreno.call("altura", PICO.x, PICO.y))
	global_position = Vector3(PICO.x, altura, PICO.y)
	_montar()
	body_entered.connect(_ao_entrar_area)
	body_exited.connect(_ao_sair_area)


func _montar() -> void:
	var col := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 5.5
	col.shape = esfera
	add_child(col)

	_anel = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.9
	torus.outer_radius = 3.2
	torus.rings = 48
	torus.ring_segments = 8
	_anel.mesh = torus
	_anel.position.y = 0.10
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 1.0, 0.55, 0.78)
	mat.emission_enabled = true
	mat.emission = Color(0.24, 1.0, 0.55)
	mat.emission_energy_multiplier = 2.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_anel.material_override = mat
	add_child(_anel)

	_luz = OmniLight3D.new()
	_luz.position = Vector3(0.0, 2.6, 0.0)
	_luz.light_color = Color(0.35, 1.0, 0.62)
	_luz.light_energy = 2.4
	_luz.omni_range = 15.0
	_luz.shadow_enabled = false
	add_child(_luz)

	_titulo = Label3D.new()
	_titulo.text = "PICO DA NEBULOSA"
	_titulo.font_size = 84
	_titulo.pixel_size = 0.012
	_titulo.position = Vector3(0.0, 6.4, 0.0)
	_titulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_titulo.modulate = Color(0.90, 1.0, 0.94)
	_titulo.outline_size = 14
	_titulo.outline_modulate = Color(0.02, 0.07, 0.05, 1.0)
	add_child(_titulo)

	_prompt = Label3D.new()
	_prompt.text = "Pressione  E  para descer de skate"
	_prompt.font_size = 62
	_prompt.pixel_size = 0.010
	_prompt.position = Vector3(0.0, 5.2, 0.0)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.modulate = Color(0.58, 1.0, 0.74)
	_prompt.outline_size = 10
	_prompt.outline_modulate = Color(0.02, 0.07, 0.05, 1.0)
	_prompt.visible = false
	add_child(_prompt)


func _process(delta: float) -> void:
	_tempo += delta
	if _luz != null:
		_luz.light_energy = 2.2 + sin(_tempo * 2.0) * 0.7
	if _anel != null:
		_anel.rotate_y(delta * 0.8)
	var jogador := get_tree().get_first_node_in_group("jogador") as Node3D
	if jogador != null:
		var perto := jogador.global_position.distance_to(global_position) < RAIO_INTERACAO
		if perto != _perto:
			_perto = perto
			if _prompt != null:
				_prompt.visible = perto


func _unhandled_input(evento: InputEvent) -> void:
	if _entrando or not _perto:
		return
	var interagir := evento.is_action_pressed("interagir")
	var clique := false
	if evento is InputEventMouseButton:
		var botao := evento as InputEventMouseButton
		clique = botao.pressed and botao.button_index == MOUSE_BUTTON_LEFT \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
	if not interagir and not clique:
		return
	# Marca o evento antes de trocar de cena: change_scene_to_file libera este no
	# imediatamente e get_viewport() passaria a devolver null.
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()
	_iniciar_descida()


func _ao_entrar_area(corpo: Node) -> void:
	if corpo.is_in_group("jogador"):
		_perto = true
		if _prompt != null:
			_prompt.visible = true


func _ao_sair_area(corpo: Node) -> void:
	if corpo.is_in_group("jogador"):
		_perto = false
		if _prompt != null:
			_prompt.visible = false


func _iniciar_descida() -> void:
	if _entrando:
		return
	_entrando = true
	if _prompt != null:
		_prompt.visible = false
	SaveSystem.dados["posicao_jogador"] = [PICO.x, ALTURA_FALLBACK + 1.2, PICO.y + 6.0]
	SaveSystem.dados["veiculo"] = "jogador"
	SaveSystem.dados["intro_mundo_vista"] = true
	SaveSystem.salvar()
	Loading.proxima_cena = CENA_FASE
	Loading.titulo_carga = "Descendo o Pico da Nebulosa..."
	get_tree().change_scene_to_file(CENA_LOADING)
