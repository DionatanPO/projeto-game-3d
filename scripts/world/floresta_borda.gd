@tool
extends Node3D
## Mata de fundo em volta do limite jogavel.
## Todas as copias compartilham a malha e textura da arvore do mapa via MultiMesh.

const SEED := 42731
const TREE_SCENE := "res://assets/models/floresta.glb"

@export_range(120.0, 220.0, 1.0) var limite_mapa := 132.0
@export_range(2, 8, 1) var fileiras := 3
@export_range(12.0, 40.0, 0.5) var espacamento_fileiras := 30.0
@export_range(12.0, 40.0, 0.5) var espacamento_arvores := 30.0
@export_range(0.6, 1.6, 0.05) var escala_minima := 0.7
@export_range(0.8, 1.8, 0.05) var escala_maxima := 1.0


func _ready() -> void:
	_construir_floresta()


func _construir_floresta() -> void:
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()

	var pacote := load(TREE_SCENE) as PackedScene
	if pacote == null:
		push_error("FlorestaBorda: nao foi possivel carregar " + TREE_SCENE)
		return

	var temporario := pacote.instantiate()
	var encontrados := temporario.find_children("*", "MeshInstance3D", true, false)
	if encontrados.is_empty():
		push_error("FlorestaBorda: o modelo nao contem MeshInstance3D.")
		temporario.free()
		return

	var malhas: Array[Dictionary] = []
	for no in encontrados:
		var mesh_node := no as MeshInstance3D
		if mesh_node.mesh != null:
			malhas.append({
				"mesh": mesh_node.mesh,
				"transform": mesh_node.transform
			})
	temporario.free()
	if malhas.is_empty():
		push_error("FlorestaBorda: nao foi encontrada nenhuma malha valida.")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var transforms_por_lado: Array = [[], [], [], []]
	var gramas_por_lado: Array = [[], [], [], []]
	var posicoes_usadas: Array[Vector3] = []
	var raio_maximo_arvores := 232.0

	for fileira in range(fileiras):
		var meio_lado := limite_mapa + float(fileira) * espacamento_fileiras
		var quantidade_lado := maxi(1, ceili((meio_lado * 2.0) / espacamento_arvores))
		for lado in range(4):
			for _i in range(quantidade_lado):
				# Cada arvore ganha coordenadas independentes para quebrar o alinhamento.
				var coordenada := rng.randf_range(-meio_lado, meio_lado)
				var recuo := rng.randf_range(-espacamento_fileiras * 0.42, espacamento_fileiras * 0.42)
				var posicao := Vector3.ZERO
				match lado:
					0:
						posicao = Vector3(coordenada, 0.0, -meio_lado + recuo)
					1:
						posicao = Vector3(meio_lado - recuo, 0.0, coordenada)
					2:
						posicao = Vector3(-coordenada, 0.0, meio_lado - recuo)
					3:
						posicao = Vector3(-meio_lado + recuo, 0.0, -coordenada)

				var distancia := Vector2(posicao.x, posicao.z).length()
				if distancia > raio_maximo_arvores:
					var ajustada := Vector2(posicao.x, posicao.z).normalized() * raio_maximo_arvores
					posicao.x = ajustada.x
					posicao.z = ajustada.y
				var sobreposta := false
				for existente in posicoes_usadas:
					if Vector2(posicao.x - existente.x, posicao.z - existente.z).length() < espacamento_arvores * 0.68:
						sobreposta = true
						break
				if sobreposta:
					continue

				posicoes_usadas.append(posicao)
				var escala := rng.randf_range(escala_minima, escala_maxima)
				# Algumas arvores se destacam como exemplares bem maiores.
				if rng.randf() < 0.09:
					escala = rng.randf_range(1.1, 1.3)
				var rotacao := rng.randf_range(0.0, TAU)
				var base := Basis(Vector3.UP, rotacao).scaled(Vector3.ONE * escala)
				posicao.y = 0.0
				transforms_por_lado[lado].append({
					"transform": Transform3D(base, posicao),
					"cor": _cor_variacao_arvore(rng)
				})

				# Pequenos tufos escuros ficam no chao, sob e entre as copas.
				for _tufo in range(rng.randi_range(3, 6)):
					var angulo := rng.randf_range(0.0, TAU)
					var raio := rng.randf_range(0.45, 3.2)
					var escala_grama := rng.randf_range(0.65, 1.25)
					var pos_grama := Vector3(
						posicao.x + cos(angulo) * raio,
						0.025,
						posicao.z + sin(angulo) * raio
					)
					var base_grama := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * escala_grama)
					gramas_por_lado[lado].append(Transform3D(base_grama, pos_grama))

	for lado in range(4):
		for indice in range(malhas.size()):
			_criar_multimesh(lado, malhas[indice], transforms_por_lado[lado])
	var malha_grama := _criar_malha_grama()
	for lado in range(4):
		_criar_multimesh_grama(lado, malha_grama, gramas_por_lado[lado])
	_criar_nevoa_floresta()


func _cor_variacao_arvore(rng: RandomNumberGenerator) -> Color:
	var variacao := rng.randi_range(0, 3)
	var intensidade := rng.randf_range(0.94, 1.0)
	match variacao:
		0:
			return Color(0.90, 0.98, 0.84, 1.0) * Color(intensidade, intensidade, intensidade, 1.0)
		1:
			return Color(0.84, 0.96, 0.90, 1.0) * Color(intensidade, intensidade, intensidade, 1.0)
		2:
			return Color(0.98, 0.94, 0.82, 1.0) * Color(intensidade, intensidade, intensidade, 1.0)
		_:
			return Color(intensidade, intensidade, intensidade, 1.0)


func _criar_malha_grama() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normais := PackedVector3Array()
	var indices := PackedInt32Array()
	var quantidade_laminas := 7
	for lamina in range(quantidade_laminas):
		var angulo := TAU * float(lamina) / float(quantidade_laminas)
		var lateral := Vector3(cos(angulo), 0.0, -sin(angulo)) * 0.18
		var direcao := Vector3(sin(angulo), 0.0, cos(angulo))
		var altura := 0.34 + float(lamina % 3) * 0.07
		var base := Vector3.ZERO
		var ponta_esquerda := base - lateral
		var ponta_direita := base + lateral
		var ponta := direcao * 0.20 + Vector3.UP * altura
		var normal := (ponta_esquerda - base).cross(ponta - base).normalized()
		var primeiro := vertices.size()
		vertices.append(ponta_esquerda)
		vertices.append(ponta_direita)
		vertices.append(ponta)
		normais.append(normal)
		normais.append(normal)
		normais.append(normal)
		indices.append(primeiro)
		indices.append(primeiro + 1)
		indices.append(primeiro + 2)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normais
	arrays[Mesh.ARRAY_INDEX] = indices
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.46, 0.14, 1.0)
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.metallic = 0.0
	malha.surface_set_material(0, material)
	return malha


func _criar_multimesh_grama(lado: int, malha: Mesh, lista: Array) -> void:
	if malha == null or lista.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = malha
	multimesh.instance_count = lista.size()
	for i in range(lista.size()):
		multimesh.set_instance_transform(i, lista[i])
	var instancia := MultiMeshInstance3D.new()
	instancia.name = "TufosGramaMultiMesh%d" % lado
	instancia.multimesh = multimesh
	instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instancia)


func _criar_nevoa_floresta() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec4 cor_nevoa : source_color = vec4(0.78, 0.85, 0.88, 0.08);
void fragment() {
	float fade_vertical = smoothstep(0.0, 0.32, UV.y) * (1.0 - smoothstep(0.68, 1.0, UV.y));
	float variacao = 0.94 + 0.06 * sin(UV.x * 36.0 + UV.y * 5.0);
	ALBEDO = cor_nevoa.rgb;
	ALPHA = cor_nevoa.a * fade_vertical * variacao;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var raio := limite_mapa + float(fileiras - 1) * espacamento_fileiras + 8.0
	var largura := raio * 2.0
	var lados := [
		[Vector3(0.0, 22.0, -raio), 0.0],
		[Vector3(raio, 22.0, 0.0), PI * 0.5],
		[Vector3(0.0, 22.0, raio), 0.0],
		[Vector3(-raio, 22.0, 0.0), PI * 0.5],
	]
	for indice in range(lados.size()):
		var plano := QuadMesh.new()
		plano.size = Vector2(largura, 44.0)
		var faixa := MeshInstance3D.new()
		faixa.name = "NevoaFloresta%d" % indice
		faixa.mesh = plano
		faixa.material_override = material
		faixa.position = lados[indice][0]
		faixa.rotation.y = lados[indice][1]
		faixa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(faixa)


func _criar_multimesh(indice: int, dados: Dictionary, lista: Array) -> void:
	var malha := dados["mesh"] as Mesh
	if malha == null or lista.is_empty():
		return

	var transform_malha := dados["transform"] as Transform3D
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = malha
	multimesh.instance_count = lista.size()
	for i in range(lista.size()):
		var item: Dictionary = lista[i]
		multimesh.set_instance_transform(i, item["transform"] * transform_malha)
		multimesh.set_instance_color(i, item["cor"])

	var instancia := MultiMeshInstance3D.new()
	instancia.name = "ArvoresMultiMesh%d" % indice
	instancia.multimesh = multimesh
	var shader_nevoa_arvores := Shader.new()
	shader_nevoa_arvores.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec4 cor_nevoa_arvores : source_color = vec4(0.78, 0.85, 0.88, 0.14);
void fragment() {
	ALBEDO = cor_nevoa_arvores.rgb;
	ALPHA = cor_nevoa_arvores.a;
}
"""
	var sobreposicao_nevoa := ShaderMaterial.new()
	sobreposicao_nevoa.shader = shader_nevoa_arvores
	instancia.material_overlay = sobreposicao_nevoa
	var raio_interno := limite_mapa
	var raio_externo := limite_mapa + float(fileiras - 1) * espacamento_fileiras
	var margem := 15.0
	var largura_lateral := raio_externo - raio_interno + margem * 2.0
	var altura_limite := 20.0
	match indice:
		0:
			instancia.custom_aabb = AABB(Vector3(-raio_externo - margem, -2.0, -raio_externo - margem), Vector3((raio_externo + margem) * 2.0, altura_limite, largura_lateral))
		1:
			instancia.custom_aabb = AABB(Vector3(raio_interno - margem, -2.0, -raio_externo - margem), Vector3(largura_lateral, altura_limite, (raio_externo + margem) * 2.0))
		2:
			instancia.custom_aabb = AABB(Vector3(-raio_externo - margem, -2.0, raio_interno - margem), Vector3((raio_externo + margem) * 2.0, altura_limite, largura_lateral))
		3:
			instancia.custom_aabb = AABB(Vector3(-raio_externo - margem, -2.0, -raio_externo - margem), Vector3(largura_lateral, altura_limite, (raio_externo + margem) * 2.0))
	instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instancia)
