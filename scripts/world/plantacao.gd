@tool
extends Node3D
## Plantacao: solo preparado retangular, 100% procedural (sem assets externos).
##
## Ao ser instanciada no mundo, varre a cena e remove a vegetacao que estiver
## dentro do retangulo, para a mata/grama do mapa nao atravessar o solo.
## A limpeza roda apenas em jogo; no editor serve para visualizar o preparo.
##
## Estrutura criada em tempo de execucao (nada e salvo no .tscn):
##   Solo      - malha do terreno preparado (leiras/sulcos + barranco lateral)
##   Colisao   - StaticBody3D com caixa alinhada ao retangulo

const PASSO_MALHA := 0.4
const ALTURA_BARRANCO := 0.35
const MARGEM_COLISAO := 0.02
const PALAVRAS_PEDRA := ["pedra", "pedrisco", "rock", "pebble", "seixo"]
const NOMES_IGNORADOS := ["nevoa", "nuvem", "fog", "cloud", "smoke", "fumaca"]

@export_group("Dimensoes")
## Largura do retangulo no eixo X local (metros).
@export_range(2.0, 200.0, 0.5) var largura := 40.0:
	set(valor):
		largura = maxf(2.0, valor)
		_reconstruir_se_pronto()

## Comprimento do retangulo no eixo Z local (metros).
@export_range(2.0, 200.0, 0.5) var comprimento := 30.0:
	set(valor):
		comprimento = maxf(2.0, valor)
		_reconstruir_se_pronto()

@export_group("Solo")
## Cor base da terra preparada.
@export var cor_solo := Color(0.34, 0.23, 0.14):
	set(valor):
		cor_solo = valor
		_reconstruir_se_pronto()

## Espacamento entre as leiras (0 desliga as leiras).
@export_range(0.0, 3.0, 0.05) var espacamento_leiras := 0.9:
	set(valor):
		espacamento_leiras = maxf(0.0, valor)
		_reconstruir_se_pronto()

## Altura das leiras em relacao ao fundo do sulco.
@export_range(0.0, 0.4, 0.01) var altura_leira := 0.06:
	set(valor):
		altura_leira = maxf(0.0, valor)
		_reconstruir_se_pronto()

## Acompanha a altura do Terreno do mapa (se existir).
@export var alinhar_ao_terreno := true

@export_group("Limpeza de vegetacao")
## Remove grama, flores, arvores, pedras e lavouras que estiverem sob o retangulo.
@export var limpar_vegetacao := true
## Tambem remove pedras e a colisao delas (evita rocha atravessando o solo).
@export var remover_pedras := true
## Margem extra (metros) ao redor do retangulo para limpar.
@export_range(0.0, 10.0, 0.1) var margem_limpeza := 1.5
## Nos/grupos que nunca devem ser removidos.
@export var grupos_ignorados := PackedStringArray([
	"jogador", "drone_jogador", "trator_jogador", "plantacao",
])
## Trechos de nome considerados vegetacao (sem diferenciar maiusculas).
@export var nomes_vegetacao := PackedStringArray([
	"grama", "grass", "flor", "flower", "samambaia", "fern", "moita", "bush",
	"arvore", "árvore", "tree", "vegetacao", "vegetação", "plant", "mato",
	"erva", "soja", "milho", "trigo", "cana", "cafe", "café", "cultivo",
	"pedra", "pedrisco", "rock", "pebble", "seixo",
])

var _solo: MeshInstance3D
var _colisao: StaticBody3D
var _textura: ImageTexture
var _altura_maxima := 0.0
var _deslocamento_solo := 0.0
var _descida_barranco := ALTURA_BARRANCO


func _ready() -> void:
	add_to_group("plantacao")
	_reconstruir()
	if not Engine.is_editor_hint() and limpar_vegetacao:
		# Espera o Terreno e a vegetacao do mundo terminarem o _ready.
		_executar_limpeza.call_deferred()


func _reconstruir_se_pronto() -> void:
	if is_inside_tree():
		_reconstruir()


func _reconstruir() -> void:
	if not is_inside_tree():
		return
	_medir_terreno()
	_garantir_nos()
	_construir_solo()
	_atualizar_colisao()
	_aplicar_ajuste()


func _garantir_nos() -> void:
	_solo = get_node_or_null("Solo") as MeshInstance3D
	if _solo == null:
		_solo = MeshInstance3D.new()
		_solo.name = "Solo"
		_solo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(_solo)
	_colisao = get_node_or_null("Colisao") as StaticBody3D
	if _colisao == null:
		_colisao = StaticBody3D.new()
		_colisao.name = "Colisao"
		add_child(_colisao)
	var forma := _colisao.get_node_or_null("Forma") as CollisionShape3D
	if forma == null:
		forma = CollisionShape3D.new()
		forma.name = "Forma"
		forma.shape = BoxShape3D.new()
		_colisao.add_child(forma)


## Mede o terreno sob a area. O solo fica no ponto mais alto (nunca afunda)
## e o barranco lateral desce ate abaixo do ponto mais baixo (nunca flutua).
func _medir_terreno() -> void:
	_deslocamento_solo = 0.0
	_descida_barranco = ALTURA_BARRANCO
	if not alinhar_ao_terreno:
		return
	var terreno := _achar_terreno()
	if terreno == null or not terreno.has_method("altura"):
		return
	var maior := -INF
	var menor := INF
	const AMOSTRAS := 7
	for iz in AMOSTRAS:
		for ix in AMOSTRAS:
			var fx := float(ix) / float(AMOSTRAS - 1) - 0.5
			var fz := float(iz) / float(AMOSTRAS - 1) - 0.5
			var ponto := to_global(Vector3(fx * largura, 0.0, fz * comprimento))
			var altura_terreno := float(terreno.call("altura", ponto.x, ponto.z))
			maior = maxf(maior, altura_terreno)
			menor = minf(menor, altura_terreno)
	if maior > -INF:
		_deslocamento_solo = (maior + 0.01) - global_position.y
		_descida_barranco = maxf(ALTURA_BARRANCO, maior - menor + 0.4)


func _achar_terreno() -> Node:
	var raiz := get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root
	return raiz.find_child("Terreno", true, false)


func _aplicar_ajuste() -> void:
	_solo.position.y = _deslocamento_solo
	_colisao.position.y = _deslocamento_solo


# ------------------------------------------------------------------
# Malha do solo
# ------------------------------------------------------------------

func _construir_solo() -> void:
	var nx := maxi(2, int(round(largura / PASSO_MALHA)))
	var nz := maxi(2, int(round(comprimento / PASSO_MALHA)))
	var meia_largura := largura * 0.5
	var meio_comprimento := comprimento * 0.5
	var passo_x := largura / float(nx)
	var passo_z := comprimento / float(nz)
	var verts := PackedVector3Array()
	var normais := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cores := PackedColorArray()
	var indices := PackedInt32Array()
	var n := (nx + 1) * (nz + 1)
	verts.resize(n)
	normais.resize(n)
	uvs.resize(n)
	cores.resize(n)
	_altura_maxima = -INF
	for j in nz + 1:
		for i in nx + 1:
			var x := -meia_largura + float(i) * passo_x
			var z := -meio_comprimento + float(j) * passo_z
			var y := _altura_solo(x, z)
			_altura_maxima = maxf(_altura_maxima, y)
			var k := j * (nx + 1) + i
			verts[k] = Vector3(x, y, z)
			normais[k] = _normal_solo(x, z)
			uvs[k] = Vector2(float(i) / float(nx), float(j) / float(nz))
			cores[k] = _cor_solo(x, z, y)
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			indices.append_array([a, b, d, a, d, c])
	# Barranco lateral: fecha o bloco de terra e esconde o chao original.
	var bordas := [
		{"indices": _indices_borda(nx, nz, 0), "normal": Vector3(0.0, 0.0, -1.0)},
		{"indices": _indices_borda(nx, nz, 1), "normal": Vector3(1.0, 0.0, 0.0)},
		{"indices": _indices_borda(nx, nz, 2), "normal": Vector3(0.0, 0.0, 1.0)},
		{"indices": _indices_borda(nx, nz, 3), "normal": Vector3(-1.0, 0.0, 0.0)},
	]
	var cor_barranco := cor_solo.darkened(0.28)
	for borda in bordas:
		var lista: PackedInt32Array = borda["indices"]
		var normal_borda: Vector3 = borda["normal"]
		var base := verts.size()
		for topo in lista:
			var ponto := verts[topo]
			verts.append(Vector3(ponto.x, -_descida_barranco, ponto.z))
			normais.append(normal_borda)
			uvs.append(uvs[topo])
			cores.append(cor_barranco)
		for k in lista.size() - 1:
			var ta := lista[k]
			var tb := lista[k + 1]
			var ba := base + k
			var bb := base + k + 1
			indices.append_array([ta, tb, bb, ta, bb, ba])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normais
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cores
	arrays[Mesh.ARRAY_INDEX] = indices
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_solo.mesh = malha
	_solo.material_override = _criar_material()


## Percorre o contorno no sentido horario, comecando no canto (-x, -z).
func _indices_borda(nx: int, nz: int, lado: int) -> PackedInt32Array:
	var lista := PackedInt32Array()
	match lado:
		0:
			for i in nx + 1:
				lista.append(i)
		1:
			for j in nz + 1:
				lista.append(j * (nx + 1) + nx)
		2:
			for i in range(nx, -1, -1):
				lista.append(nz * (nx + 1) + i)
		3:
			for j in range(nz, -1, -1):
				lista.append(j * (nx + 1))
	return lista


func _altura_solo(x: float, z: float) -> float:
	var altura := 0.025
	if espacamento_leiras > 0.001:
		var perfil := 0.5 + 0.5 * cos(TAU * x / espacamento_leiras)
		altura += pow(perfil, 1.35) * altura_leira
	altura += _ruido(x * 0.55 + 11.0, z * 0.55 - 7.0) * 0.012
	# Pequena borda levantada, como terra arada nas margens.
	var distancia_borda := minf(
		largura * 0.5 - absf(x),
		comprimento * 0.5 - absf(z)
	)
	altura += (1.0 - smoothstep(0.0, 0.45, maxf(distancia_borda, 0.0))) * 0.035
	return altura


func _normal_solo(x: float, z: float) -> Vector3:
	var e := 0.06
	var dx := _altura_solo(x + e, z) - _altura_solo(x - e, z)
	var dz := _altura_solo(x, z + e) - _altura_solo(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


func _cor_solo(x: float, z: float, _y: float) -> Color:
	var perfil := 0.5
	if espacamento_leiras > 0.001:
		perfil = 0.5 + 0.5 * cos(TAU * x / espacamento_leiras)
	var brilho := lerpf(0.78, 1.10, perfil)
	brilho += _ruido(x * 0.85 + 31.0, z * 0.85 - 19.0) * 0.07
	brilho = clampf(brilho, 0.55, 1.2)
	return Color(
		cor_solo.r * brilho,
		cor_solo.g * brilho,
		cor_solo.b * brilho,
		1.0
	)


func _criar_material() -> StandardMaterial3D:
	if _textura == null:
		_textura = _criar_textura()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _textura
	material.uv1_scale = Vector3(largura / 4.0, comprimento / 4.0, 1.0)
	material.roughness = 1.0
	material.metallic = 0.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


## Granulado de terra gerado em codigo, 128x128, em tons de cinza.
func _criar_textura() -> ImageTexture:
	var tamanho := 128
	var img := Image.create(tamanho, tamanho, false, Image.FORMAT_RGB8)
	for y in tamanho:
		for x in tamanho:
			var macro := _ruido(float(x) * 0.10, float(y) * 0.10) * 0.5 + 0.5
			var fino := _ruido(float(x) * 0.85 + 40.0, float(y) * 0.85 - 17.0) * 0.5 + 0.5
			var torrao := 1.0 if _hash(x * 7 + 3, y * 7 - 5) > 0.985 else 0.0
			var v := 0.80 + macro * 0.13 + (fino - 0.5) * 0.14 + torrao * 0.12
			v = clampf(v, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	return ImageTexture.create_from_image(img)


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


# ------------------------------------------------------------------
# Colisao
# ------------------------------------------------------------------

func _atualizar_colisao() -> void:
	var forma := _colisao.get_node("Forma") as CollisionShape3D
	var caixa := forma.shape as BoxShape3D
	if caixa == null:
		caixa = BoxShape3D.new()
		forma.shape = caixa
	var altura_bloco := _altura_maxima + _descida_barranco + MARGEM_COLISAO
	caixa.size = Vector3(largura, altura_bloco, comprimento)
	# Topo da caixa coincide com o ponto mais alto das leiras.
	forma.position = Vector3(0.0, _altura_maxima - altura_bloco * 0.5 - MARGEM_COLISAO, 0.0)


# ------------------------------------------------------------------
# Limpeza da vegetacao existente no mundo
# ------------------------------------------------------------------

## Pode ser chamado manualmente depois de gerar vegetacao em tempo real.
func limpar_vegetacao_agora() -> void:
	_executar_limpeza()


func _executar_limpeza() -> void:
	if not limpar_vegetacao:
		return
	var raiz := get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root
	_varrer(raiz)


func _varrer(no: Node) -> void:
	if no == self or is_ancestor_of(no):
		return
	if _ignorado(no):
		return
	if no is MultiMeshInstance3D and _eh_vegetacao(no):
		_filtrar_multimesh(no as MultiMeshInstance3D)
	elif no is MeshInstance3D and _eh_vegetacao(no):
		if _dentro_da_area((no as MeshInstance3D).global_position):
			no.queue_free()
			return
	elif no is CollisionShape3D and remover_pedras:
		if _colisao_de_pedra_dentro(no as CollisionShape3D):
			no.queue_free()
			return
	elif no is Node3D and _eh_vegetacao(no) \
			and _dentro_da_area((no as Node3D).global_position) \
			and _subarvore_pequena(no):
		# Instancias de arvore/planta (com colisao propria) somem inteiras.
		no.queue_free()
		return
	for filho in no.get_children():
		_varrer(filho)


## Evita apagar um container grande demais (ex.: VegetacaoMundo) por engano.
func _subarvore_pequena(no: Node) -> bool:
	# Inclui a origem do proprio no: sem isso, filhos distantes nao contariam
	# no tamanho (o AABB de uma malha nao guarda a distancia ate o pai).
	var caixa := AABB((no as Node3D).global_position, Vector3.ZERO)
	var achou := false
	for filho in no.find_children("*", "VisualInstance3D", true, false):
		var visual := filho as VisualInstance3D
		if visual == null or visual is MultiMeshInstance3D:
			continue
		var limites := visual.global_transform * visual.get_aabb()
		caixa = caixa.merge(limites)
		achou = true
	if not achou:
		return false
	var tamanho := caixa.size
	return maxf(tamanho.x, maxf(tamanho.y, tamanho.z)) <= 20.0


func _ignorado(no: Node) -> bool:
	for grupo in grupos_ignorados:
		if no.is_in_group(grupo):
			return true
	return false


func _eh_vegetacao(no: Node) -> bool:
	var nome := no.name.to_lower()
	# Nevoeiro/nuvens usam "flor" no nome (NevoaFloresta) e nao sao vegetacao.
	for ignorado in NOMES_IGNORADOS:
		if nome.contains(ignorado):
			return false
	if no.is_in_group("vegetacao") or no.is_in_group("vegetation"):
		return true
	for palavra in nomes_vegetacao:
		if palavra.is_empty():
			continue
		var chave := palavra.to_lower()
		if not remover_pedras and _eh_palavra_pedra(chave):
			continue
		if nome.contains(chave):
			return true
	return false


func _eh_palavra_pedra(palavra: String) -> bool:
	for pedra in PALAVRAS_PEDRA:
		if palavra.contains(pedra):
			return true
	return false


func _colisao_de_pedra_dentro(forma: CollisionShape3D) -> bool:
	if not _dentro_da_area(forma.global_position):
		return false
	var pai := forma.get_parent()
	if pai == null:
		return false
	var nome := pai.name.to_lower()
	for pedra in PALAVRAS_PEDRA:
		if nome.contains(pedra):
			return true
	return false


func _dentro_da_area(posicao_global: Vector3) -> bool:
	var local := to_local(posicao_global)
	var meia_largura := largura * 0.5 + margem_limpeza
	var meio_comprimento := comprimento * 0.5 + margem_limpeza
	return absf(local.x) <= meia_largura and absf(local.z) <= meio_comprimento


## Remove apenas as instancias do MultiMesh que caem dentro do retangulo,
## preservando a vegetacao do lado de fora.
func _filtrar_multimesh(instancia: MultiMeshInstance3D) -> void:
	var original := instancia.multimesh
	if original == null or original.instance_count <= 0:
		return
	if original.transform_format != MultiMesh.TRANSFORM_3D:
		return
	var transformadas: Array[Transform3D] = []
	var cores: Array[Color] = []
	var dados: Array[Color] = []
	var usa_cores := original.use_colors
	var usa_dados := original.use_custom_data
	for i in original.instance_count:
		var transformada := original.get_instance_transform(i)
		var posicao_mundo := instancia.global_transform * transformada.origin
		if _dentro_da_area(posicao_mundo):
			continue
		transformadas.append(transformada)
		if usa_cores:
			cores.append(original.get_instance_color(i))
		if usa_dados:
			dados.append(original.get_instance_custom_data(i))
	if transformadas.size() == original.instance_count:
		return
	if transformadas.is_empty():
		instancia.visible = false
		return
	var nova := MultiMesh.new()
	nova.transform_format = MultiMesh.TRANSFORM_3D
	nova.mesh = original.mesh
	nova.use_colors = usa_cores
	nova.use_custom_data = usa_dados
	nova.custom_aabb = original.custom_aabb
	nova.instance_count = transformadas.size()
	for i in transformadas.size():
		nova.set_instance_transform(i, transformadas[i])
		if usa_cores:
			nova.set_instance_color(i, cores[i])
		if usa_dados:
			nova.set_instance_custom_data(i, dados[i])
	instancia.multimesh = nova
