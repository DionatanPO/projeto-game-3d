@tool
class_name Caminho
extends Node3D
## Caminho: remendo de terra batida em retangulo de cantos arredondados.
## Gera a propria malha seguindo o relevo do Terreno, com a mesma cor e textura
## do chao de terra da sede/eolica, e remove a vegetacao por baixo.
##
## Encaixe varias pecas (duplique e rotacione) para formar a estrada.

const TERRA := Color(0.44, 0.32, 0.21)
const SEMENTE := 20240
## Mesma escala do granulado usado pelo terreno (160 repeticoes em 420 m).
const ESCALA_TEXTURA := 160.0 / 420.0
const PALAVRAS_PEDRA := ["pedra", "pedrisco", "rock", "pebble", "seixo"]

static var _material_cache: StandardMaterial3D

@export_group("Formato")
## Largura (eixo X local), em metros.
@export_range(1.0, 40.0, 0.1) var largura := 6.0:
	set(v):
		largura = maxf(v, 0.2)
		_agendar_regerar()
## Comprimento (eixo Z local), em metros. E o sentido da estrada.
@export_range(1.0, 60.0, 0.1) var comprimento := 8.0:
	set(v):
		comprimento = maxf(v, 0.2)
		_agendar_regerar()
## Raio dos cantos arredondados, em metros.
@export_range(0.0, 20.0, 0.1) var raio_cantos := 2.5:
	set(v):
		raio_cantos = maxf(v, 0.0)
		_agendar_regerar()
## Largura da transicao transparente para fora da estrada (metros).
## Valores entre 1.0 e 2.5 costumam funcionar bem para caminhos rurais.
@export_range(0.0, 5.0, 0.05) var borda_suave := 1.8:
	set(v):
		borda_suave = maxf(v, 0.0)
		_agendar_regerar()
## Altura acima do terreno para evitar z-fighting.
@export_range(0.0, 0.5, 0.01) var altura_offset := 0.06:
	set(v):
		altura_offset = maxf(v, 0.0)
		_agendar_regerar()

@export_group("Aparencia")
## Cor base da terra (a mesma usada pelo terreno).
@export var cor_terra := TERRA:
	set(v):
		cor_terra = v
		_agendar_regerar()
## Irregularidade visual das laterais, em metros. Use 0 para bordas regulares.
@export_range(0.0, 0.6, 0.01) var irregularidade_borda := 0.12:
	set(v):
		irregularidade_borda = maxf(v, 0.0)
		_agendar_regerar()

@export_group("Limpeza de vegetacao")
## Remove grama, flores, arvores, pedras e lavouras que estiverem sob a peca.
@export var limpar_vegetacao := true
## Tambem remove pedras e a colisao delas.
@export var remover_pedras := true
## Margem extra (metros) ao redor da peca para limpar.
@export_range(0.0, 3.0, 0.05) var margem_limpeza := 0.2
## Nos/grupos que nunca devem ser removidos.
@export var grupos_ignorados := PackedStringArray([
	"jogador", "drone_jogador", "trator_jogador", "plantacao", "caminho",
])
## Trechos de nome considerados vegetacao (sem diferenciar maiusculas).
@export var nomes_vegetacao := PackedStringArray([
	"grama", "grass", "flor", "flower", "samambaia", "fern", "moita", "bush",
	"arvore", "árvore", "tree", "vegetacao", "vegetação", "plant", "mato",
	"erva", "soja", "milho", "trigo", "cana", "cafe", "café", "cultivo",
	"pedra", "pedrisco", "rock", "pebble", "seixo",
])

var _terreno: Node = null
var _regerar_agendado := false


func _ready() -> void:
	add_to_group("caminho")
	set_notify_transform(true)
	_terreno = _achar_terreno()
	_gerar_malha()
	if not Engine.is_editor_hint() and limpar_vegetacao:
		_executar_limpeza.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_agendar_regerar()


## Pode ser chamado manualmente depois de gerar vegetacao em tempo real.
func limpar_vegetacao_agora() -> void:
	_executar_limpeza()


func _agendar_regerar() -> void:
	if not is_inside_tree() or _regerar_agendado:
		return
	_regerar_agendado = true
	_regerar.call_deferred()


func _regerar() -> void:
	_regerar_agendado = false
	if not is_inside_tree():
		return
	if _terreno == null:
		_terreno = _achar_terreno()
	_gerar_malha()


func _achar_terreno() -> Node:
	var raiz: Node = null
	if Engine.is_editor_hint():
		raiz = get_tree().edited_scene_root
	else:
		raiz = get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root
	return _procurar_terreno(raiz)


func _procurar_terreno(no: Node) -> Node:
	if no.has_method("altura"):
		return no
	for filho in no.get_children():
		var achado := _procurar_terreno(filho)
		if achado != null:
			return achado
	return null


func _altura(x: float, z: float) -> float:
	if _terreno != null:
		var g := (_terreno as Node3D).global_position
		return float(_terreno.call("altura", x - g.x, z - g.z)) + g.y
	return 0.0


func _normal_terreno(x: float, z: float) -> Vector3:
	var e := 0.45
	var dx := _altura(x + e, z) - _altura(x - e, z)
	var dz := _altura(x, z + e) - _altura(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


## Distancia assinada ate o retangulo arredondado local (negativa = dentro).
func _dist_arredondada(x: float, z: float) -> float:
	var hx := maxf(largura, 0.2) * 0.5
	var hz := maxf(comprimento, 0.2) * 0.5
	var r := clampf(raio_cantos, 0.0, minf(hx, hz))
	var qx := absf(x) - (hx - r)
	var qz := absf(z) - (hz - r)
	var fora := Vector2(maxf(qx, 0.0), maxf(qz, 0.0)).length()
	var dentro := minf(maxf(qx, qz), 0.0)
	return fora + dentro - r


func _gerar_malha() -> void:
	var hx := maxf(largura, 0.2) * 0.5
	var hz := maxf(comprimento, 0.2) * 0.5
	var r := clampf(raio_cantos, 0.0, minf(hx, hz))
	var ax := hx - r
	var az := hz - r
	var arco := (PI * 0.5) * r
	var perimetro := 2.0 * az + 2.0 * arco + 2.0 * ax + 2.0 * arco + 2.0 * az + 2.0 * arco + 2.0 * ax + 2.0 * arco
	var n_borda := clampi(ceili(perimetro / 0.45), 24, 256)
	var borda := _borda_arredondada(hx, hz, r, n_borda)
	var aneis := 12
	var desloc := _jitter_altura()
	# A malha passa um pouco da borda real da estrada. Essa faixa extra
	# permite que o alpha desapareca sobre o terreno, sem terminar abruptamente.
	var escala_externa := 1.0 + borda_suave / maxf(minf(hx, hz), 0.1)
	var verts := PackedVector3Array()
	var normais := PackedVector3Array()
	var cores := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	# Centro.
	var centro := to_global(Vector3.ZERO)
	var cy := _altura(centro.x, centro.z) + altura_offset + desloc
	verts.append(Vector3(centro.x, cy, centro.z))
	normais.append(_normal_terreno(centro.x, centro.z))
	cores.append(_cor_vertice(centro.x, centro.z, cy - altura_offset, -minf(hx, hz)))
	uvs.append(Vector2(centro.x, centro.z) * ESCALA_TEXTURA)
	# Aneis do centro para a borda.
	for i in aneis:
		var u := float(i) / float(aneis - 1)
		var t := lerpf(0.08, escala_externa, 1.0 - pow(1.0 - u, 1.7))
		for p in borda:
			var local := p * t
			var w := to_global(Vector3(local.x, 0.0, local.y))
			var y := _altura(w.x, w.z) + altura_offset + desloc
			verts.append(Vector3(w.x, y, w.z))
			normais.append(_normal_terreno(w.x, w.z))
			cores.append(_cor_vertice(w.x, w.z, y - altura_offset, _dist_arredondada(local.x, local.y)))
			uvs.append(Vector2(w.x, w.z) * ESCALA_TEXTURA)
	# Leque do centro para o primeiro anel.
	for k in n_borda:
		idx.append_array([0, 1 + k, 1 + (k + 1) % n_borda])
	# Quads entre os aneis.
	for anel in aneis - 1:
		var base_a := 1 + anel * n_borda
		var base_b := base_a + n_borda
		for k in n_borda:
			var k2 := (k + 1) % n_borda
			var a := base_a + k
			var b := base_a + k2
			var c := base_b + k
			var d := base_b + k2
			idx.append_array([a, c, b, b, c, d])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normais
	arr[Mesh.ARRAY_COLOR] = cores
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := get_node_or_null("Piso") as MeshInstance3D
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "Piso"
		add_child(mi)
	mi.top_level = true
	mi.global_transform = Transform3D.IDENTITY
	mi.mesh = malha
	mi.material_override = _obter_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Pequeno deslocamento por posicao para duas pecas sobrepostas nao brigarem.
func _jitter_altura() -> float:
	var g := global_position
	var n := sin(g.x * 12.9898 + g.z * 78.233) * 43758.5453
	return fposmod(n, 1.0) * 0.004


func _cor_vertice(x: float, z: float, _h: float, dist: float) -> Color:
	# A opacidade fica cheia dentro da estrada e desaparece gradualmente
	# na faixa externa, deixando o terreno aparecer por baixo.
	var variacao := _ruido(x * 1.35 + 13.7, z * 1.35 - 8.2) * irregularidade_borda
	var dist_borda := dist + variacao
	var f := 1.0
	if borda_suave > 0.001:
		f = 1.0 - smoothstep(0.0, borda_suave, dist_borda)
	else:
		f = 1.0 if dist_borda <= 0.0 else 0.0
	var cor := cor_terra
	# Variacao sutil de tons para quebrar o aspecto uniforme da terra.
	var macro := _ruido(x * 0.32, z * 0.32) * 0.5 + 0.5
	var fino := _ruido(x * 1.7 + 40.0, z * 1.7 - 17.0) * 0.5 + 0.5
	cor = cor.lerp(cor_terra.darkened(0.10), macro * 0.20)
	cor = cor.lerp(cor_terra.lightened(0.06), fino * 0.08)
	cor.a = clampf(f, 0.0, 1.0)
	return cor


## Pontos da borda do retangulo arredondado, em ordem e espacados no perimetro.
func _borda_arredondada(hx: float, hz: float, r: float, n: int) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var ax := hx - r
	var az := hz - r
	var arco := (PI * 0.5) * r
	var perimetro := 4.0 * (ax + az + arco)
	if perimetro <= 0.0001:
		return pts
	for i in n:
		pts.append(_ponto_perimetro(float(i) * perimetro / float(n), hx, hz, r, ax, az, arco))
	return pts


func _ponto_perimetro(d: float, hx: float, hz: float, r: float, ax: float, az: float, arco: float) -> Vector2:
	var l1 := 2.0 * az
	var l2 := 2.0 * ax
	if l1 > 0.0:
		if d <= l1:
			return Vector2(hx, -az + d)
		d -= l1
	if arco > 0.0:
		if d <= arco:
			var a := d / r
			return Vector2(ax + cos(a) * r, az + sin(a) * r)
		d -= arco
	if l2 > 0.0:
		if d <= l2:
			return Vector2(ax - d, hz)
		d -= l2
	if arco > 0.0:
		if d <= arco:
			var a := PI * 0.5 + d / r
			return Vector2(-ax + cos(a) * r, az + sin(a) * r)
		d -= arco
	if l1 > 0.0:
		if d <= l1:
			return Vector2(-hx, az - d)
		d -= l1
	if arco > 0.0:
		if d <= arco:
			var a := PI + d / r
			return Vector2(-ax + cos(a) * r, -az + sin(a) * r)
		d -= arco
	if l2 > 0.0:
		if d <= l2:
			return Vector2(-ax + d, -hz)
		d -= l2
	if arco > 0.0:
		var a := PI * 1.5 + clampf(d / r, 0.0, PI * 0.5)
		return Vector2(ax + cos(a) * r, -az + sin(a) * r)
	return Vector2(hx, -az)


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
	elif (
		no is Node3D
		and _eh_vegetacao(no)
		and _dentro_da_area((no as Node3D).global_position)
		and _subarvore_pequena(no)
	):
		# Instancias de arvore/planta (com colisao propria) somem inteiras.
		no.queue_free()
		return
	for filho in no.get_children():
		_varrer(filho)


func _dentro_da_area(pos_global: Vector3) -> bool:
	var local := to_local(pos_global)
	return _dist_arredondada(local.x, local.z) <= margem_limpeza


## Evita apagar um container grande demais (ex.: VegetacaoMundo) por engano.
func _subarvore_pequena(no: Node) -> bool:
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
	if no.is_in_group("vegetacao") or no.is_in_group("vegetation"):
		return true
	var nome := no.name.to_lower()
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


## Remove apenas as instancias do MultiMesh que caem dentro da peca,
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


static func _obter_material() -> StandardMaterial3D:
	if _material_cache != null:
		return _material_cache
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _criar_granulado()
	mat.roughness = 0.95
	mat.roughness_texture = mat.albedo_texture
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material_cache = mat
	return mat


static func _criar_granulado() -> ImageTexture:
	var tam := 256
	var img := Image.create(tam, tam, false, Image.FORMAT_RGB8)
	for y in tam:
		for x in tam:
			var macro := _ruido(float(x) * 0.12, float(y) * 0.12) * 0.5 + 0.5
			var fino := _ruido(float(x) * 0.9 + 40.0, float(y) * 0.9 - 17.0) * 0.5 + 0.5
			var v := clampf(0.82 + macro * 0.10 + (fino - 0.5) * 0.12, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	return ImageTexture.create_from_image(img)


static func _ruido(x: float, z: float) -> float:
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


static func _hash(x: int, z: int) -> float:
	var n := x * 374761393 + z * 668265263 + SEMENTE * 1442695041
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65535.0
