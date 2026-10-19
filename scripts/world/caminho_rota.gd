@tool
class_name CaminhoRota
extends Node3D
## CaminhoRota: estrada continua gerada a partir de marcadores (Marker3D).
##
## Estrutura da cena:
##   CaminhoRota
##     Ponto1 (Marker3D)
##     Ponto2 (Marker3D)
##     Ponto3 (Marker3D)
##
## Arraste os marcadores no editor para desenhar o tracado. A estrada e
## regenerada sozinha, segue o relevo do Terreno, usa a mesma terra da
## sede/eolica e remove a vegetacao ao longo de toda a faixa (uma vez so).

const TERRA := Color(0.44, 0.32, 0.21)
const SEMENTE := 20240
## Mesma escala do granulado usado pelo terreno (160 repeticoes em 420 m).
const ESCALA_TEXTURA := 160.0 / 420.0
const PALAVRAS_PEDRA := ["pedra", "pedrisco", "rock", "pebble", "seixo"]
## Perfil transversal: mais vertices perto das bordas para o degrade.
const PERFIL := [-1.0, -0.9, -0.75, -0.55, -0.3, 0.0, 0.3, 0.55, 0.75, 0.9, 1.0]

static var _material_cache: StandardMaterial3D

@export_group("Formato")
## Largura total da estrada (metros).
@export_range(1.0, 30.0, 0.1) var largura := 5.0:
	set(v):
		largura = maxf(v, 0.2)
		_agendar_regerar()
## Largura do degrade das bordas (metros). 0 = borda nitida.
@export_range(0.0, 4.0, 0.05) var borda_suave := 1.2:
	set(v):
		borda_suave = maxf(v, 0.0)
		_agendar_regerar()
## Altura acima do terreno para evitar z-fighting.
@export_range(0.0, 0.5, 0.01) var altura_offset := 0.065:
	set(v):
		altura_offset = maxf(v, 0.0)
		_agendar_regerar()
## Quanto os cantos sao suavizados (0 = reto, 1 = bem curvo).
@export_range(0.0, 1.0, 0.01) var suavidade := 0.8:
	set(v):
		suavidade = clampf(v, 0.0, 1.0)
		_agendar_regerar()
## Espacamento entre secoes da malha (metros).
@export_range(0.2, 3.0, 0.05) var resolucao := 0.6:
	set(v):
		resolucao = maxf(v, 0.2)
		_agendar_regerar()

@export_group("Aparencia")
## Cor base da terra (a mesma usada pelo terreno).
@export var cor_terra := TERRA:
	set(v):
		cor_terra = v
		_agendar_regerar()

@export_group("Limpeza de vegetacao")
## Remove grama, flores, arvores, pedras e lavouras sob a estrada.
@export var limpar_vegetacao := true
## Tambem remove pedras e a colisao delas.
@export var remover_pedras := true
## Margem extra (metros) ao redor da estrada para limpar.
@export_range(0.0, 3.0, 0.05) var margem_limpeza := 0.3
## Nos/grupos que nunca devem ser removidos.
@export var grupos_ignorados := PackedStringArray([
	"jogador", "drone_jogador", "trator_jogador", "plantacao", "caminho", "caminho_rota",
])
## Trechos de nome considerados vegetacao (sem diferenciar maiusculas).
@export var nomes_vegetacao := PackedStringArray([
	"grama", "grass", "flor", "flower", "samambaia", "fern", "moita", "bush",
	"arvore", "árvore", "tree", "vegetacao", "vegetação", "plant", "mato",
	"erva", "soja", "milho", "trigo", "cana", "cafe", "café", "cultivo",
	"pedra", "pedrisco", "rock", "pebble", "seixo",
])

## Botao no inspetor para adicionar mais um ponto no fim da rota.
@export_tool_button("Adicionar ponto", "Add") var acao_adicionar = _adicionar_ponto

var _terreno: Node = null
var _polilinha := PackedVector2Array()
var _regerar_agendado := false
var _ultima_assinatura := PackedVector3Array()
var _ultimo_check := 0


func _ready() -> void:
	add_to_group("caminho_rota")
	set_notify_transform(true)
	_terreno = _achar_terreno()
	_gerar_malha()
	_ultima_assinatura = _pontos_globais()
	if not Engine.is_editor_hint() and limpar_vegetacao:
		_executar_limpeza.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_agendar_regerar()


func _process(_delta: float) -> void:
	# No editor, detecta quando um marcador foi arrastado.
	if not Engine.is_editor_hint():
		return
	var agora := Time.get_ticks_msec()
	if agora - _ultimo_check < 80:
		return
	_ultimo_check = agora
	var pontos := _pontos_globais()
	if pontos != _ultima_assinatura:
		_ultima_assinatura = pontos
		_agendar_regerar()


## Regera a estrada imediatamente (util para script/animacao).
func regerar_agora() -> void:
	_gerar_malha()


## Repete a limpeza depois de gerar vegetacao em tempo real.
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


func _marcadores() -> Array[Node3D]:
	var lista: Array[Node3D] = []
	for filho in get_children():
		if filho is Marker3D:
			lista.append(filho as Node3D)
	return lista


func _pontos_globais() -> PackedVector3Array:
	var pontos := PackedVector3Array()
	for filho in get_children():
		if filho is Marker3D:
			pontos.append((filho as Node3D).global_position)
	return pontos


func _adicionar_ponto() -> void:
	if not Engine.is_editor_hint():
		return
	var marcadores := _marcadores()
	var novo := Marker3D.new()
	novo.name = "Ponto%d" % (marcadores.size() + 1)
	novo.gizmo_extents = 0.5
	if marcadores.size() >= 2:
		var ult := marcadores[marcadores.size() - 1].position
		var penult := marcadores[marcadores.size() - 2].position
		var dir := ult - penult
		if dir.length() < 0.01:
			dir = Vector3(0.0, 0.0, 10.0)
		novo.position = ult + dir.normalized() * 10.0
	elif marcadores.size() == 1:
		novo.position = marcadores[0].position + Vector3(0.0, 0.0, 10.0)
	else:
		novo.position = Vector3.ZERO
	add_child(novo)
	var raiz := get_tree().edited_scene_root
	if raiz != null:
		novo.owner = raiz
	_agendar_regerar()


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


func _jitter_altura() -> float:
	var g := global_position
	var n := sin(g.x * 12.9898 + g.z * 78.233) * 43758.5453
	return fposmod(n, 1.0) * 0.004


## Amostra o caminho suave entre os marcadores (coordenadas de mundo).
func _amostrar(pontos: PackedVector3Array) -> PackedVector3Array:
	var amostras := PackedVector3Array()
	if pontos.size() < 2:
		return amostras
	if pontos.size() == 2:
		var passos := maxi(2, ceili(pontos[0].distance_to(pontos[1]) / resolucao))
		for j in passos + 1:
			var t := float(j) / float(passos)
			amostras.append(pontos[0].lerp(pontos[1], t))
		return amostras
	var suav := clampf(suavidade, 0.0, 1.0)
	for i in pontos.size() - 1:
		var p1 := pontos[i]
		var p2 := pontos[i + 1]
		if p1.distance_to(p2) < 0.01:
			continue
		var p0 := pontos[maxi(i - 1, 0)]
		var p3 := pontos[mini(i + 2, pontos.size() - 1)]
		if i == 0:
			p0 = p1 - (p2 - p1)
		if i + 2 > pontos.size() - 1:
			p3 = p2 + (p2 - p1)
		var m1 := (p2 - p0) * 0.5 * suav
		var m2 := (p3 - p1) * 0.5 * suav
		var passos := maxi(2, ceili(p1.distance_to(p2) / resolucao))
		for j in passos:
			var t := float(j) / float(passos)
			amostras.append(_cardinal(p1, p2, m1, m2, t) if suav > 0.01 else p1.lerp(p2, t))
	amostras.append(pontos[pontos.size() - 1])
	return amostras


func _cardinal(p1: Vector3, p2: Vector3, m1: Vector3, m2: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return (
		(2.0 * t3 - 3.0 * t2 + 1.0) * p1
		+ (t3 - 2.0 * t2 + t) * m1
		+ (-2.0 * t3 + 3.0 * t2) * p2
		+ (t3 - t2) * m2
	)


func _gerar_malha() -> void:
	var pontos := _pontos_globais()
	_polilinha = PackedVector2Array()
	if pontos.size() < 2 or largura <= 0.01:
		_ocultar_piso()
		return
	var amostras := _amostrar(pontos)
	if amostras.size() < 2:
		_ocultar_piso()
		return
	var dists := PackedFloat32Array()
	dists.resize(amostras.size())
	var total := 0.0
	dists[0] = 0.0
	_polilinha.append(Vector2(amostras[0].x, amostras[0].z))
	for i in range(1, amostras.size()):
		total += amostras[i - 1].distance_to(amostras[i])
		dists[i] = total
		_polilinha.append(Vector2(amostras[i].x, amostras[i].z))
	if total <= 0.01:
		_ocultar_piso()
		return
	var half := largura * 0.5
	var suave := clampf(borda_suave, 0.001, half * 0.95)
	var desloc := _jitter_altura()
	var faixas := PERFIL.size()
	var verts := PackedVector3Array()
	var normais := PackedVector3Array()
	var cores := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in amostras.size():
		var p := amostras[i]
		var ant := amostras[maxi(i - 1, 0)]
		var prox := amostras[mini(i + 1, amostras.size() - 1)]
		var dir := Vector2(prox.x - ant.x, prox.z - ant.z)
		if dir.length() < 0.001:
			dir = Vector2(0.0, 1.0)
		dir = dir.normalized()
		var normal := Vector2(-dir.y, dir.x)
		var alpha_lon := smoothstep(0.0, suave, minf(dists[i], total - dists[i]))
		for k in faixas:
			var off := float(PERFIL[k])
			var wx := p.x + normal.x * off * half
			var wz := p.z + normal.y * off * half
			var y := _altura(wx, wz) + altura_offset + desloc
			var alpha_lat := smoothstep(0.0, suave, half * (1.0 - absf(off)))
			var cor := cor_terra
			var n := _ruido(wx * 0.8, wz * 0.8) * 0.5 + 0.5
			cor = cor.lerp(cor_terra.darkened(0.06), n * 0.18)
			cor.a = alpha_lat * alpha_lon
			verts.append(Vector3(wx, y, wz))
			normais.append(_normal_terreno(wx, wz))
			cores.append(cor)
			uvs.append(Vector2(wx, wz) * ESCALA_TEXTURA)
	for i in amostras.size() - 1:
		for k in faixas - 1:
			var a := i * faixas + k
			var b := a + 1
			var c := a + faixas
			var d := c + 1
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
	mi.visible = true


func _ocultar_piso() -> void:
	var mi := get_node_or_null("Piso") as MeshInstance3D
	if mi != null:
		mi.mesh = null
		mi.visible = false


func _executar_limpeza() -> void:
	if not limpar_vegetacao:
		return
	if _polilinha.size() < 2:
		_gerar_malha()
	if _polilinha.size() < 2:
		return
	var raiz := get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root
	_varrer(raiz)


func _dentro_da_area(pos_global: Vector3) -> bool:
	return _dist_polilinha(pos_global.x, pos_global.z) <= largura * 0.5 + margem_limpeza


func _dist_polilinha(x: float, z: float) -> float:
	if _polilinha.size() < 2:
		return INF
	var p := Vector2(x, z)
	var melhor := INF
	for i in _polilinha.size() - 1:
		melhor = minf(melhor, _dist_segmento(p, _polilinha[i], _polilinha[i + 1]))
	return melhor


func _dist_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var den := ab.length_squared()
	if den <= 0.000001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / den, 0.0, 1.0)
	return p.distance_to(a + ab * t)


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


## Remove apenas as instancias do MultiMesh que caem dentro da estrada,
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
