extends Node3D
## Fase "Descida do Pico da Nebulosa".
## Encosta procedural em blocos: o skatista desce sozinho, desvia de pedras e
## troncos, e e lancado pelas rampas ate cruzar a meta na base.

const CENA_HUD := preload("res://scenes/ui/hud_descida.tscn")
const CENA_SKATISTA := preload("res://scenes/world/descida/skatista.tscn")
const CENA_RAMPA := preload("res://assets/models/rampa.glb")
const CENA_TRONCO := preload("res://assets/models/Tronco_Casca.glb")
const CENA_LOADING := "res://scenes/ui/menus/loading.tscn"
const CENA_MUNDO := "res://scenes/world/mundo.tscn"

const ARVORES: Array = [
	preload("res://assets/Stylized Nature/FBX/CommonTree_1.fbx"),
]
const FERNES: Array = [
	preload("res://assets/Stylized Nature/FBX/Fern_1.fbx"),
]
const PEDRAS: Array = [
	preload("res://assets/Stylized Nature/FBX/Rock_Medium_1.fbx"),
	preload("res://assets/Stylized Nature/FBX/Rock_Medium_2.fbx"),
]

const COMPRIMENTO_BLOCO := 28.0
const LARGURA_TOTAL := 48.0
const MEIA_PISTA := 8.0
const DISTANCIA_TOTAL := 1000.0
const INCLINACAO_GRAUS := 19.0
const ALTURA_PICO := 54.7
const VISAO_A_FRENTE := 190.0
const BLOCO_FINAL := 36
const PICO_MUNDO := Vector3(-135.0, 54.71, -119.0)
const MUSICA := "res://assets/audio/musicas/decida_insana_sem_vocal.mp3"

## Modos de camera (Y alterna): 0 = bem perto, 1 = um pouco mais longe.
const CAM_MODOS: Array[Dictionary] = [
	{"altura": 2.10, "distancia": 2.6, "alvo_y": -0.70, "alvo_frente": 5.8},
	{"altura": 2.60, "distancia": 3.9, "alvo_y": -1.10, "alvo_frente": 7.2},
]

var _jogador: CharacterBody3D
var _camera: Camera3D
var _hud: CanvasLayer
var _mat_chao: StandardMaterial3D
var _mat_madeira: StandardMaterial3D
var _forma_rampa: ConcavePolygonShape3D
var _rampas: Array[Dictionary] = []
var _mat_tronco: StandardMaterial3D
var _tex_xadrez: ImageTexture
var _mat_anel: StandardMaterial3D
var _cache_arvores: Array = []
var _cache_ferns: Array = []
var _cache_pedras: Array = []
var _blocos: Dictionary = {}
var _proximo_bloco := 0
var _bloco_antigo := 0
var _estado := "carregando"
var _tempo := 0.0
var _shake := 0.0
var _roll := 0.0
var _musica: AudioStreamPlayer
var _cam_modo := 0
var _anéis_passados := 0
var _anéis_ativos: Array[Node3D] = []


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.45, 0.62, 0.82))
	_criar_materiais()
	_carregar_cache()
	_configurar_ambiente()
	_criar_camera()
	_criar_jogador()
	_configurar_musica()
	_criar_portico_inicial()
	_criar_meta()
	_criar_marcos()
	_hud = CENA_HUD.instantiate() as CanvasLayer
	add_child(_hud)
	_hud.connect("pausa_alternada", _ao_alternar_pausa)
	_hud.connect("pediu_reiniciar", _reiniciar)
	_hud.connect("pediu_sair", _sair_para_mundo)
	_hud.call("definir_recorde", int(SaveSystem.dados.get("descida_recorde", 0)))
	# Inclui um bloco atras da linha de partida para a camera nao ver o vazio.
	for i in range(-1, 7):
		_criar_bloco(i)
		_proximo_bloco = i + 1
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_iniciar_contagem()


# ------------------------------------------------------------ montagem
func _criar_materiais() -> void:
	_mat_chao = StandardMaterial3D.new()
	_mat_chao.albedo_color = Color.WHITE
	_mat_chao.albedo_texture = _textura_pista()
	_mat_chao.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_chao.roughness = 0.95
	_mat_chao.metallic = 0.0

	_mat_madeira = StandardMaterial3D.new()
	_mat_madeira.albedo_color = Color(0.58, 0.33, 0.16)
	_mat_madeira.roughness = 0.82

	_mat_tronco = StandardMaterial3D.new()
	_mat_tronco.albedo_color = Color(0.32, 0.20, 0.11)
	_mat_tronco.roughness = 0.95

	_mat_anel = StandardMaterial3D.new()
	_mat_anel.albedo_color = Color(0.24, 1.0, 0.55)
	_mat_anel.emission_enabled = true
	_mat_anel.emission = Color(0.24, 1.0, 0.55)
	_mat_anel.emission_energy_multiplier = 2.4
	_mat_anel.roughness = 0.3
	_mat_anel.metallic = 0.6


## Textura horizontal: grama nas laterais e terra no centro da pista.
## Repete ao longo de s; o ruido e periodico em v para nao emendar.
func _textura_pista() -> ImageTexture:
	var px := 256
	var py := 256
	var img := Image.create(px, py, false, Image.FORMAT_RGB8)
	var ruido := FastNoiseLite.new()
	ruido.frequency = 0.055
	ruido.fractal_octaves = 4
	var grama := Color(0.30, 0.50, 0.20)
	var grama_clara := Color(0.37, 0.56, 0.24)
	var terra := Color(0.46, 0.33, 0.20)
	var terra_clara := Color(0.55, 0.41, 0.25)
	for j in py:
		var v := float(j) / float(py)
		var ang := TAU * v
		var nx := cos(ang) * 30.0
		var ny := sin(ang) * 30.0
		for i in px:
			var u := float(i) / float(px - 1)
			var wx := (u - 0.5) * LARGURA_TOTAL
			var n := ruido.get_noise_2d(nx + wx * 1.6, ny)
			var n01 := n * 0.5 + 0.5
			var cor := grama.lerp(grama_clara, n01)
			var borda := MEIA_PISTA + 0.6 + n * 1.1
			var no_trilho := 1.0 - smoothstep(borda - 1.4, borda + 1.4, absf(wx))
			var trilha := terra.lerp(terra_clara, n01 * 0.85)
			cor = cor.lerp(trilha, no_trilho)
			img.set_pixel(i, j, cor)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _carregar_cache() -> void:
	for cena in ARVORES:
		_cache_arvores.append(_partes_da_cena(cena))
	for cena in FERNES:
		_cache_ferns.append(_partes_da_cena(cena))
	for cena in PEDRAS:
		_cache_pedras.append(_partes_da_cena(cena))


func _partes_da_cena(cena: PackedScene) -> Array:
	var partes: Array = []
	var tmp := cena.instantiate() as Node
	if tmp == null:
		return partes
	for no in tmp.find_children("*", "MeshInstance3D", true, false):
		var mi := no as MeshInstance3D
		if mi != null and mi.mesh != null:
			partes.append({"mesh": mi.mesh, "transform": mi.transform})
	tmp.free()
	return partes


func _configurar_musica() -> void:
	_musica = AudioStreamPlayer.new()
	_musica.name = "MusicaDescida"
	var trilha := load(MUSICA) as AudioStream
	if trilha == null:
		return
	if trilha is AudioStreamMP3:
		(trilha as AudioStreamMP3).loop = true
	elif trilha is AudioStreamWAV:
		(trilha as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_musica.stream = trilha
	_musica.finished.connect(_reiniciar_musica)
	if AudioServer.get_bus_index("Musica") >= 0:
		_musica.bus = "Musica"
	_musica.volume_db = -3.0
	add_child(_musica)
	_musica.play()


func _reiniciar_musica() -> void:
	if _musica != null:
		_musica.play()


func _configurar_ambiente() -> void:
	var ceu_mat := ProceduralSkyMaterial.new()
	ceu_mat.sky_top_color = Color(0.20, 0.42, 0.68)
	ceu_mat.sky_horizon_color = Color(0.76, 0.84, 0.94)
	ceu_mat.sky_curve = 0.12
	ceu_mat.ground_bottom_color = Color(0.30, 0.36, 0.42)
	ceu_mat.ground_horizon_color = Color(0.78, 0.86, 0.94)
	var ceu := Sky.new()
	ceu.sky_material = ceu_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = ceu
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.ambient_light_color = Color(0.72, 0.80, 0.92)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.76, 0.84, 0.94)
	env.fog_light_energy = 1.0
	env.fog_density = 1.0
	# Neblina mais fechada: esconde o horizonte e da a sensacao de que a
	# linha de chegada ainda esta muito longe (ela so surge perto do fim).
	env.fog_depth_begin = 45.0
	env.fog_depth_end = 280.0
	env.fog_sky_affect = 0.9
	var mundo_env := WorldEnvironment.new()
	mundo_env.environment = env
	add_child(mundo_env)

	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-46.0, 38.0, 0.0)
	sol.light_color = Color(1.0, 0.96, 0.88)
	sol.light_energy = 1.25
	sol.shadow_enabled = true
	sol.shadow_bias = 0.08
	sol.shadow_normal_bias = 2.0
	sol.directional_shadow_max_distance = 120.0
	add_child(sol)

	var preenchimento := DirectionalLight3D.new()
	preenchimento.rotation_degrees = Vector3(-18.0, -140.0, 0.0)
	preenchimento.light_color = Color(0.58, 0.70, 0.92)
	preenchimento.light_energy = 0.32
	preenchimento.shadow_enabled = false
	add_child(preenchimento)


func _criar_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "CameraDescida"
	_camera.fov = 65.0
	_camera.near = 0.12
	_camera.far = 650.0
	_camera.current = true
	add_child(_camera)


func _criar_jogador() -> void:
	_jogador = CENA_SKATISTA.instantiate() as CharacterBody3D
	_jogador.name = "Skatista"
	add_child(_jogador)
	_jogador.global_position = Vector3(0.0, altura_pista(2.0, 0.0) + 0.7, -2.0)
	_jogador.set("funcao_altura", Callable(self, "altura_pista"))
	_jogador.connect("bateu", _ao_bater)
	_camera.global_position = _jogador.global_position + Vector3(0.0, 2.1, 2.6)
	_camera.look_at(_jogador.global_position + Vector3(0.0, -0.7, -5.8), Vector3.UP)


func _iniciar_contagem() -> void:
	_estado = "contagem"
	var passos: Array[String] = ["3", "2", "1", "VAI!"]
	for passo in passos:
		_hud.call("mostrar_contagem", passo)
		await get_tree().create_timer(0.72, false).timeout
		if not is_inside_tree():
			return
	_hud.call("esconder_contagem")
	if _jogador == null:
		return
	_jogador.set("ativo", true)
	_estado = "correndo"
	_tempo = 0.0


# ------------------------------------------------------------ terreno
## Altura da encosta (mundo): desce linearmente + ondulacoes + banks laterais.
func altura_pista(s: float, x: float) -> float:
	var base := ALTURA_PICO - s * tan(deg_to_rad(INCLINACAO_GRAUS))
	var onda := sin(s * 0.045) * 0.70 + sin(s * 0.017 + 2.4) * 1.05
	var banco := smoothstep(MEIA_PISTA, MEIA_PISTA + 13.0, absf(x)) * 6.0
	var ruga := _ruido(x * 0.35, s * 0.33) * 0.22 * smoothstep(2.0, 7.0, absf(x))
	return base + onda + banco + ruga


func _criar_bloco(indice: int) -> void:
	if _blocos.has(indice):
		return
	var raiz := Node3D.new()
	raiz.name = "Bloco_%03d" % indice
	var s0 := float(indice) * COMPRIMENTO_BLOCO
	var colunas := 25
	var linhas := 9
	var passo_x := LARGURA_TOTAL / float(colunas - 1)
	var passo_s := COMPRIMENTO_BLOCO / float(linhas - 1)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in linhas - 1:
		for i in colunas - 1:
			var xa := -LARGURA_TOTAL * 0.5 + float(i) * passo_x
			var xb := xa + passo_x
			var sa := s0 + float(j) * passo_s
			var sb := sa + passo_s
			_vertice(st, xa, sa)
			_vertice(st, xa, sb)
			_vertice(st, xb, sa)
			_vertice(st, xb, sa)
			_vertice(st, xa, sb)
			_vertice(st, xb, sb)
	st.generate_normals()
	var malha := st.commit() as ArrayMesh

	var mi := MeshInstance3D.new()
	mi.name = "Chao"
	mi.mesh = malha
	mi.material_override = _mat_chao
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(mi)

	var corpo := StaticBody3D.new()
	corpo.name = "ColisaoChao"
	var col := CollisionShape3D.new()
	col.shape = malha.create_trimesh_shape()
	corpo.add_child(col)
	raiz.add_child(corpo)

	_decorar_bloco(raiz, indice, s0)
	_popular_bloco(raiz, indice, s0)
	add_child(raiz)
	_blocos[indice] = raiz


func _vertice(st: SurfaceTool, x: float, s: float) -> void:
	var y := altura_pista(s, x)
	st.set_uv(Vector2(x / LARGURA_TOTAL + 0.5, s / 16.0))
	st.add_vertex(Vector3(x, y, -s))


func _decorar_bloco(raiz: Node3D, indice: int, s0: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = indice * 7919 + 17
	for lado: float in [-1.0, 1.0]:
		# Floresta densa de CommonTree_1 acompanhando as margens da pista.
		var bases: Array[Transform3D] = []
		for _k in 14:
			var s := s0 + rng.randf_range(0.5, COMPRIMENTO_BLOCO - 0.5)
			var x := lado * rng.randf_range(10.5, 23.5)
			var y := altura_pista(s, x) - 0.35
			var esc := rng.randf_range(0.75, 1.55)
			var alt := esc * rng.randf_range(0.95, 1.15)
			var base := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(esc, alt, esc))
			bases.append(Transform3D(base, Vector3(x, y, -s)))
		_espalhar_partes(raiz, _cache_arvores[0], bases, "Arvores")

		# Vegetacao rasteira (Fern_1) ladeando a trilha e entre as arvores.
		var fernes: Array[Transform3D] = []
		for _k in 18:
			var s := s0 + rng.randf_range(0.5, COMPRIMENTO_BLOCO - 0.5)
			var x := lado * rng.randf_range(8.8, 20.5)
			var y := altura_pista(s, x) - 0.05
			var esc := rng.randf_range(0.55, 1.15)
			var base := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * esc)
			fernes.append(Transform3D(base, Vector3(x, y, -s)))
		_espalhar_partes(raiz, _cache_ferns[0], fernes, "Vegetacao", false)

		var pedras: Array[Transform3D] = []
		for _k in 4:
			var s := s0 + rng.randf_range(0.5, COMPRIMENTO_BLOCO - 0.5)
			var x := lado * rng.randf_range(9.5, 17.0)
			var y := altura_pista(s, x) - 0.25
			var esc := rng.randf_range(0.7, 1.8)
			var base := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * esc)
			pedras.append(Transform3D(base, Vector3(x, y, -s)))
		var tipo_pedra := rng.randi_range(0, _cache_pedras.size() - 1)
		_espalhar_partes(raiz, _cache_pedras[tipo_pedra], pedras, "Pedras")


func _espalhar_partes(raiz: Node3D, partes: Array, transformadas: Array[Transform3D], nome: String, sombra: bool = true) -> void:
	if partes.is_empty() or transformadas.is_empty():
		return
	for parte in partes:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = parte["mesh"]
		mm.instance_count = transformadas.size()
		var t_parte: Transform3D = parte["transform"]
		for i in transformadas.size():
			mm.set_instance_transform(i, transformadas[i] * t_parte)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = nome
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sombra else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 270.0 if sombra else 150.0
		mmi.visibility_range_end_margin = 45.0
		raiz.add_child(mmi)


func _popular_bloco(raiz: Node3D, indice: int, s0: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = indice * 92821 + 7
	var s_rampa := -1.0
	if indice >= 3 and indice % 2 == 0:
		s_rampa = s0 + rng.randf_range(8.0, 19.0)
		_criar_rampa(raiz, s_rampa, rng.randf_range(-4.6, 4.6))
	if indice < 2:
		return
	var qtd := rng.randi_range(1, 3)
	for _i in qtd:
		var s := s0 + rng.randf_range(3.0, COMPRIMENTO_BLOCO - 3.0)
		if s_rampa > 0.0 and absf(s - s_rampa) < 5.5:
			continue
		var x := rng.randf_range(-6.4, 6.4)
		if rng.randf() < 0.62:
			_criar_pedra_obstaculo(raiz, s, x, rng)
		else:
			_criar_tronco(raiz, s, x, rng)


func _criar_pedra_obstaculo(raiz: Node3D, s: float, x: float, rng: RandomNumberGenerator) -> void:
	var partes := _cache_pedras[rng.randi_range(0, _cache_pedras.size() - 1)] as Array
	if partes.is_empty():
		return
	var parte: Dictionary = partes[0]
	var esc := rng.randf_range(0.9, 1.6)
	var y := altura_pista(s, x)
	var mi := MeshInstance3D.new()
	mi.mesh = parte["mesh"]
	var base := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * esc)
	mi.transform = Transform3D(base, Vector3(x, y - 0.22 * esc, -s)) * (parte["transform"] as Transform3D)
	raiz.add_child(mi)

	var area := Area3D.new()
	area.position = Vector3(x, y + 0.5 * esc, -s)
	var col := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 0.72 * esc
	col.shape = esfera
	area.add_child(col)
	area.body_entered.connect(_ao_tocar_obstaculo)
	raiz.add_child(area)


func _criar_tronco(raiz: Node3D, s: float, x: float, rng: RandomNumberGenerator) -> void:
	var y := altura_pista(s, x)
	var modelo := CENA_TRONCO.instantiate() as Node3D
	modelo.name = "Tronco"
	var escala := rng.randf_range(0.7, 1.1)
	modelo.scale = Vector3(escala, escala, escala)
	modelo.position = Vector3(x, y + 0.55, -s)
	modelo.rotation_degrees = Vector3(0.0, rng.randf_range(0.0, 360.0), 0.0)
	raiz.add_child(modelo)

	var area := Area3D.new()
	area.position = Vector3(x, y + 0.42, -s)
	var col := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	var comp := 4.5 * escala
	caixa.size = Vector3(comp, 0.9, 0.9)
	col.shape = caixa
	area.add_child(col)
	area.body_entered.connect(_ao_tocar_obstaculo)
	raiz.add_child(area)


func _criar_rampa(raiz: Node3D, s: float, x: float) -> void:
	var comprimento := 7.0
	var largura := 4.6
	# O skatista vem de s menor e desce para s maior: a entrada (s_frente) fica
	# rente ao chao e a saida (s_tras) forma o lip que impulsiona.
	var s_frente := s - comprimento * 0.5
	var s_tras := s + comprimento * 0.5
	var y_frente := altura_pista(s_frente, x) + 0.06
	var y_tras := altura_pista(s_tras, x) + 0.06
	var y_lip := y_tras + 1.55
	var z_tras := -s_tras
	var z_frente := -s_frente
	var meia := largura * 0.5
	var pontos: Array[Vector3] = [
		Vector3(x - meia, y_frente, z_frente),
		Vector3(x + meia, y_frente, z_frente),
		Vector3(x - meia, y_lip, z_tras),
		Vector3(x + meia, y_lip, z_tras),
		Vector3(x - meia, y_tras, z_tras),
		Vector3(x + meia, y_tras, z_tras),
	]

	# Visual: modelo de rampa de terra (otimizado no Blender).
	# A inclinacao acompanha o declive local da pista (as ondas mudam o angulo
	# de um trecho para outro) e a entrada fica enterrada, escondendo a borda.
	var angulo := atan2(y_frente - y_tras, comprimento)
	var topo_frente := Vector3(0.0, -0.35 * 0.435, 5.0 * 0.70)
	var desloc := topo_frente.rotated(Vector3.RIGHT, -angulo)
	var modelo := CENA_RAMPA.instantiate() as Node3D
	modelo.name = "Rampa"
	modelo.scale = Vector3(0.92, 0.435, 0.70)
	modelo.rotation = Vector3(-angulo, 0.0, 0.0)
	modelo.position = Vector3(x, y_frente - 0.45 - desloc.y, -s)
	raiz.add_child(modelo)

	# Altura real do lip depois de enterrar o modelo (o gatilho acompanha).
	var topo_tras := Vector3(0.0, 3.2925 * 0.435, -5.0 * 0.70)
	var desloc_tras := topo_tras.rotated(Vector3.RIGHT, -angulo)
	var y_lip_visual := modelo.position.y + desloc_tras.y

	if _forma_rampa == null:
		var amostra := CENA_RAMPA.instantiate()
		var malha := _achar_malha(amostra)
		if malha != null and malha.mesh != null:
			_forma_rampa = _forma_sem_pedras(malha.mesh)
		amostra.queue_free()

	var corpo := StaticBody3D.new()
	corpo.name = "ColisaoRampa"
	corpo.add_to_group("rampa")
	corpo.transform = modelo.transform
	var col := CollisionShape3D.new()
	if _forma_rampa != null:
		col.shape = _forma_rampa
	else:
		var forma := ConvexPolygonShape3D.new()
		forma.points = PackedVector3Array(pontos)
		col.shape = forma
	corpo.add_child(col)
	raiz.add_child(corpo)

	var area := Area3D.new()
	area.position = Vector3(x, y_lip_visual + 0.55, z_tras - 0.25)
	var col_area := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(largura, 1.6, 1.6)
	col_area.shape = caixa
	area.add_child(col_area)
	area.body_entered.connect(_ao_tocar_rampa)
	raiz.add_child(area)

	# Anel circular no topo da rampa (lip) para o skatista passar por dentro.
	var anel := _criar_anel_rampa(x, y_lip_visual, z_tras, largura, angulo)
	raiz.add_child(anel)
	_anéis_ativos.append(anel)


## Cria um anel circular luminoso no topo da rampa, alinhado com o declive.
func _criar_anel_rampa(x: float, y_lip: float, z_tras: float, largura: float, angulo: float) -> Node3D:
	var grupo := Node3D.new()
	grupo.name = "AnelRampa"
	grupo.position = Vector3(x, y_lip + 0.35, z_tras)
	grupo.rotation = Vector3(-angulo, 0.0, 0.0)

	var anel := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.1
	torus.outer_radius = 1.5
	torus.rings = 32
	torus.ring_segments = 16
	anel.mesh = torus
	anel.material_override = _mat_anel
	anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	grupo.add_child(anel)

	# Area de deteccao: o skatista deve passar pelo centro do anel.
	var area := Area3D.new()
	area.name = "AreaAnel"
	var col := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 1.4
	col.shape = esfera
	area.add_child(col)
	area.body_entered.connect(_ao_passar_anel)
	grupo.add_child(area)

	return grupo


## Detecta quando o skatista passa por dentro de um anel de rampa.
func _ao_passar_anel(area: Area3D, corpo: Node) -> void:
	if not corpo.is_in_group("skatista"):
		return
	var grupo := area.get_parent()
	if grupo == null:
		return
	# Remove o anel ja passado para nao contar de novo.
	var idx := _anéis_ativos.find(grupo)
	if idx >= 0:
		_anéis_ativos.remove_at(idx)
	grupo.queue_free()
	_anéis_passados += 1
	_hud.call("flash_anel", _anéis_passados)
	_shake = 0.6


## Gera a colisao apenas com o corpo da rampa: as pedrinhas decorativas sao
## ilhas separadas da malha e faziam o skatista travar em algumas rampas.
func _forma_sem_pedras(malha: Mesh) -> ConcavePolygonShape3D:
	var arr := malha.surface_get_arrays(0)
	var vertices: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var indices := PackedInt32Array()
	if arr[Mesh.ARRAY_INDEX] != null:
		indices = arr[Mesh.ARRAY_INDEX]
	else:
		for i in vertices.size():
			indices.append(i)
	var pai: Array[int] = []
	pai.resize(vertices.size())
	for i in pai.size():
		pai[i] = i
	for t in int(indices.size() / 3.0):
		var a := indices[t * 3]
		var b := indices[t * 3 + 1]
		var c := indices[t * 3 + 2]
		var ra := _raiz(pai, a)
		var rb := _raiz(pai, b)
		if ra != rb:
			pai[rb] = ra
		if _raiz(pai, a) != _raiz(pai, c):
			pai[_raiz(pai, c)] = _raiz(pai, a)
	var tamanhos: Array[int] = []
	tamanhos.resize(vertices.size())
	for i in vertices.size():
		tamanhos[_raiz(pai, i)] += 1
	var maior := 0
	for i in tamanhos.size():
		if tamanhos[i] > tamanhos[maior]:
			maior = i
	var faces := PackedVector3Array()
	for t in int(indices.size() / 3.0):
		var a := indices[t * 3]
		if _raiz(pai, a) != maior:
			continue
		faces.append(vertices[a])
		faces.append(vertices[indices[t * 3 + 1]])
		faces.append(vertices[indices[t * 3 + 2]])
	var forma := ConcavePolygonShape3D.new()
	forma.set_faces(faces)
	return forma


func _raiz(pai: Array[int], i: int) -> int:
	while pai[i] != i:
		pai[i] = pai[pai[i]]
		i = pai[i]
	return i


func _achar_malha(no: Node) -> MeshInstance3D:
	if no is MeshInstance3D and (no as MeshInstance3D).mesh != null:
		return no as MeshInstance3D
	for filho in no.get_children():
		var achado := _achar_malha(filho)
		if achado != null:
			return achado
	return null


func _criar_portico_inicial() -> void:
	_criar_arco(Vector3(0.0, altura_pista(18.0, 0.0), -18.0), "PICO DA NEBULOSA")


func _criar_meta() -> void:
	var s := DISTANCIA_TOTAL
	var y := altura_pista(s, 0.0)
	for lado: float in [-1.0, 1.0]:
		var poste := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.65, 8.0, 0.65)
		poste.mesh = m
		poste.material_override = _mat_madeira
		poste.position = Vector3(lado * 9.2, y + 4.0, -s)
		add_child(poste)
	var faixa := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(19.0, 1.8, 0.28)
	faixa.mesh = fm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _textura_xadrez()
	mat.roughness = 0.85
	faixa.material_override = mat
	faixa.position = Vector3(0.0, y + 7.3, -s)
	add_child(faixa)
	var placa := Label3D.new()
	placa.text = "META"
	placa.font_size = 140
	placa.pixel_size = 0.009
	placa.position = Vector3(0.0, y + 5.4, -s + 0.4)
	placa.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	placa.modulate = Color(1, 1, 1, 0.95)
	placa.outline_size = 12
	placa.outline_modulate = Color(0.02, 0.10, 0.04, 1.0)
	add_child(placa)


func _criar_arco(pos: Vector3, texto: String) -> void:
	for lado: float in [-1.0, 1.0]:
		var poste := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.55, 7.0, 0.55)
		poste.mesh = m
		poste.material_override = _mat_madeira
		poste.position = pos + Vector3(lado * 9.0, 3.5, 0.0)
		add_child(poste)
	var faixa := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(18.4, 1.2, 0.22)
	faixa.mesh = fm
	faixa.material_override = _mat_madeira
	faixa.position = pos + Vector3(0.0, 6.4, 0.0)
	add_child(faixa)
	var placa := Label3D.new()
	placa.text = texto
	placa.font_size = 96
	placa.pixel_size = 0.009
	placa.position = pos + Vector3(0.0, 5.5, 0.2)
	placa.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	placa.modulate = Color(0.92, 0.99, 0.95, 1.0)
	placa.outline_size = 10
	placa.outline_modulate = Color(0.02, 0.08, 0.05, 1.0)
	add_child(placa)


func _criar_marcos() -> void:
	var d := 200
	while d < int(DISTANCIA_TOTAL):
		var s := float(d)
		var l := Label3D.new()
		l.text = "%d m" % d
		l.font_size = 96
		l.pixel_size = 0.010
		l.position = Vector3(11.8, altura_pista(s, 11.8) + 2.0, -s)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.modulate = Color(0.86, 0.96, 0.90, 0.92)
		l.outline_size = 8
		l.outline_modulate = Color(0.02, 0.08, 0.05, 0.9)
		add_child(l)
		d += 200


func _textura_xadrez() -> ImageTexture:
	if _tex_xadrez != null:
		return _tex_xadrez
	var img := Image.create(64, 16, false, Image.FORMAT_RGB8)
	for y in 16:
		for x in 64:
			var casa := int(x / 8.0) + int(y / 8.0)
			var cor := Color(0.06, 0.07, 0.07) if casa % 2 == 0 else Color(0.95, 0.96, 0.97)
			img.set_pixel(x, y, cor)
	_tex_xadrez = ImageTexture.create_from_image(img)
	return _tex_xadrez


# ------------------------------------------------------------ fluxo
func _process(delta: float) -> void:
	_garantir_blocos()
	_atualizar_camera(delta)
	# Gira os aneis das rampas para efeito visual.
	for anel in _anéis_ativos:
		if anel != null and anel.is_inside_tree():
			anel.rotate_y(delta * 1.5)
	if _estado == "correndo" and _jogador != null:
		_tempo += delta
		var s := maxf(0.0, -_jogador.global_position.z)
		var kmh := float(_jogador.get("velocidade")) * 3.6
		_hud.call("atualizar", s, kmh, _tempo, s / DISTANCIA_TOTAL)
		var chao := altura_pista(s, _jogador.global_position.x)
		if _jogador.global_position.y < chao - 1.2:
			_jogador.call("reposicionar", Vector3(_jogador.global_position.x, chao + 0.2, _jogador.global_position.z), maxf(float(_jogador.get("velocidade")), 6.0))
		if s >= DISTANCIA_TOTAL:
			_vencer()
	_limpar_blocos()


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("camera"):
		_cam_modo = (_cam_modo + 1) % CAM_MODOS.size()
		get_viewport().set_input_as_handled()


func _atualizar_camera(delta: float) -> void:
	if _jogador == null:
		return
	_shake = move_toward(_shake, 0.0, delta * 2.6)
	var lateral := float(_jogador.call("lateral_atual"))
	var modo: Dictionary = CAM_MODOS[_cam_modo]
	var altura := float(modo.get("altura", 2.0))
	var distancia := float(modo.get("distancia", 3.6))
	var alvo_y := float(modo.get("alvo_y", 1.0))
	var alvo_frente := float(modo.get("alvo_frente", 7.0))
	# Usa a posicao visual suavizada (a fisica roda a 60 Hz): se a camera
	# seguisse o corpo cru, a diferenca entre os dois apareceria como tremida.
	var pos_jogador: Vector3 = _jogador.call("posicao_visual")
	var desejada := pos_jogador + Vector3(lateral * 0.08, altura, distancia)
	var chao_cam := altura_pista(maxf(0.0, -desejada.z), desejada.x) + 0.8
	desejada.y = maxf(desejada.y, chao_cam)
	_camera.global_position = _camera.global_position.lerp(desejada, 1.0 - exp(-22.0 * delta))
	var alvo := pos_jogador + Vector3(lateral * 0.15, alvo_y, -alvo_frente)
	if _shake > 0.001:
		alvo += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake
	_camera.look_at(alvo, Vector3.UP)
	_roll = lerpf(_roll, -lateral * 0.006, 1.0 - exp(-5.0 * delta))
	_camera.rotate_object_local(Vector3(0.0, 0.0, 1.0), _roll)
	var vel := float(_jogador.get("velocidade"))
	var alvo_fov := 68.0 + clampf((vel - 8.0) / 20.0, 0.0, 1.0) * 9.0
	_camera.fov = lerpf(_camera.fov, alvo_fov, 1.0 - exp(-3.0 * delta))


func _garantir_blocos() -> void:
	if _jogador == null:
		return
	var s := maxf(0.0, -_jogador.global_position.z)
	var limite := s + VISAO_A_FRENTE
	var gerados := 0
	while _proximo_bloco <= BLOCO_FINAL \
			and float(_proximo_bloco) * COMPRIMENTO_BLOCO <= limite \
			and gerados < 2:
		_criar_bloco(_proximo_bloco)
		_proximo_bloco += 1
		gerados += 1


func _limpar_blocos() -> void:
	if _jogador == null:
		return
	var atual := int(maxf(0.0, -_jogador.global_position.z) / COMPRIMENTO_BLOCO)
	while _bloco_antigo < atual - 2:
		if _blocos.has(_bloco_antigo):
			var no: Node3D = _blocos[_bloco_antigo]
			no.queue_free()
			_blocos.erase(_bloco_antigo)
		_bloco_antigo += 1


func _ao_tocar_obstaculo(corpo: Node) -> void:
	if corpo.is_in_group("skatista"):
		corpo.call("leve_tombo")


func _ao_tocar_rampa(corpo: Node) -> void:
	if corpo.is_in_group("skatista"):
		corpo.call("impulsionar", 11.2)


func _ao_bater() -> void:
	_shake = 0.9
	_hud.call("flash_dano")


func _ao_alternar_pausa(pausado: bool) -> void:
	get_tree().paused = pausado


func _reiniciar() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()


func _sair_para_mundo() -> void:
	get_tree().paused = false
	SaveSystem.dados["posicao_jogador"] = [PICO_MUNDO.x, PICO_MUNDO.y + 1.2, PICO_MUNDO.z]
	SaveSystem.dados["veiculo"] = "jogador"
	SaveSystem.dados["intro_mundo_vista"] = true
	SaveSystem.salvar()
	Loading.proxima_cena = CENA_MUNDO
	Loading.titulo_carga = "Voltando ao Pico da Nebulosa..."
	get_tree().change_scene_to_file(CENA_LOADING)


func _vencer() -> void:
	if _estado == "vitoria" or _jogador == null:
		return
	_estado = "vitoria"
	_jogador.call("finalizar")
	var dist := float(_jogador.get("distancia"))
	var tombos := int(_jogador.get("tombos"))
	var recorde_ant := int(SaveSystem.dados.get("descida_recorde", 0))
	var novo := int(dist) > recorde_ant
	if novo:
		SaveSystem.dados["descida_recorde"] = int(dist)
	var primeira := not bool(SaveSystem.dados.get("descida_concluida", false))
	SaveSystem.dados["descida_concluida"] = true
	SaveSystem.salvar()
	var xp := 150 if primeira else 40
	XPManager.add_xp(xp)
	_hud.call("definir_recorde", maxi(recorde_ant, int(dist)))
	_hud.call("abrir_fim", dist, _tempo, tombos, xp, novo)


# ------------------------------------------------------------ ruido
func _ruido(x: float, z: float) -> float:
	var xi := floori(x)
	var zi := floori(z)
	var xf := x - float(xi)
	var zf := z - float(zi)
	var u := xf * xf * (3.0 - 2.0 * xf)
	var v := zf * zf * (3.0 - 2.0 * zf)
	var a := _hash(xi, zi)
	var b := _hash(xi + 1, zi)
	var c := _hash(xi, zi + 1)
	var d := _hash(xi + 1, zi + 1)
	return (lerpf(lerpf(a, b, u), lerpf(c, d, u), v) - 0.5) * 2.0


func _hash(x: int, z: int) -> float:
	var n := x * 374761393 + z * 668265263 + 20240 * 1442695041
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65535.0
