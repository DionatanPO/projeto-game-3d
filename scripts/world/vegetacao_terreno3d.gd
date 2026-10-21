extends Node3D
## Gerador de gramado para o Terrain3D.
##
## Cria instâncias de grama (MultiMeshInstance3D) distribuídas sobre o terreno,
## usando a função de altura do Terrain3D pai para posicionar cada folha no nível
## correto. Funciona no renderizador GL Compatibility (ao contrário do exemplo
## de partículas do addon, que depende de particle trails).
##
## Adicione este nó como filho do seu nó Terrain3D.

## Espaçamento médio entre as gramas (m). Menor = mais denso.
@export_range(0.5, 8.0, 0.5) var espacamento := 2.0

## Lado da área quadrada de gramado, centrada na origem (m).
@export_range(64.0, 1024.0, 32.0) var area := 384.0

## Altura mínima e máxima de cada grama (m).
@export_range(0.05, 1.0, 0.05) var altura_min := 0.12
@export_range(0.1, 2.0, 0.05) var altura_max := 0.28

## Cor base da grama.
@export var cor_grama: Color = Color(0.35, 0.65, 0.30, 1.0)

## Se verdadeiro, adiciona um pequeno jitter aleatório na posição de cada grama.
@export var jitter := true

## Semente para a distribuição aleatória (reprodutível).
@export_range(0, 10000, 1) var semente := 42

## Se a grama deve projetar sombras.
@export var projetar_sombras := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


var _multimesh: MultiMeshInstance3D


func _ready() -> void:
	var terreno: Terrain3D = get_parent() as Terrain3D
	if not terreno:
		push_error("VegetacaoTerreno3D deve ser filho de um nó Terrain3D.")
		return
	if not terreno.data:
		push_error("Terrain3D não possui dados carregados.")
		return

	_multimesh = MultiMeshInstance3D.new()
	_multimesh.name = "Gramado"
	_multimesh.multimesh = _criar_multimesh()
	add_child(_multimesh, true)

	_gerar_gramado(terreno)

	# Ajusta as cores da grama para combinar com o terreno
	_ajustar_cores_grama(terreno)


func _criar_multimesh() -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true

	# Malha simples de grama: duas placas cruzadas (forma de +), dupla-face.
	var malha := _criar_malha_grama()
	mm.mesh = malha

	return mm


func _criar_malha_grama() -> ArrayMesh:
	var w := 0.06   # largura da folha
	var h := 0.30   # altura da folha (será ajustada por instância via escala)

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	# Placa 1: plano XY (normal Z)
	verts.append(Vector3(-w, 0.0, 0.0))
	verts.append(Vector3(w, 0.0, 0.0))
	verts.append(Vector3(-w, h, 0.0))
	verts.append(Vector3(w, h, 0.0))
	norms.append(Vector3.FORWARD)
	norms.append(Vector3.FORWARD)
	norms.append(Vector3.FORWARD)
	norms.append(Vector3.FORWARD)
	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(1, 0))
	uvs.append(Vector2(0, 1))
	uvs.append(Vector2(1, 1))
	indices.append_array([0, 1, 2, 1, 3, 2])

	# Placa 2: plano ZY rotacionada 90° (normal X)
	verts.append(Vector3(0.0, 0.0, -w))
	verts.append(Vector3(0.0, 0.0, w))
	verts.append(Vector3(0.0, h, -w))
	verts.append(Vector3(0.0, h, w))
	norms.append(Vector3.LEFT)
	norms.append(Vector3.LEFT)
	norms.append(Vector3.LEFT)
	norms.append(Vector3.LEFT)
	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(1, 0))
	uvs.append(Vector2(0, 1))
	uvs.append(Vector2(1, 1))
	indices.append_array([4, 5, 6, 5, 7, 6])

	var arrays := []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	arrays[ArrayMesh.ARRAY_VERTEX] = verts
	arrays[ArrayMesh.ARRAY_NORMAL] = norms
	arrays[ArrayMesh.ARRAY_TEX_UV] = uvs
	arrays[ArrayMesh.ARRAY_INDEX] = indices

	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am


func _gerar_gramado(terreno: Terrain3D) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = semente

	var mm := _multimesh.multimesh

	# Calcula quantas instâncias cabem na área.
	var passo := espacamento
	var meio := area * 0.5
	var colunas := ceilf(area / passo) + 1
	var total := colunas * colunas
	mm.instance_count = total

	var idx := 0
	var escala := altura_max - altura_min

	for i in colunas:
		for j in colunas:
			var x := -meio + float(i) * passo
			var z := -meio + float(j) * passo

			if jitter:
				x += random.randf_range(-passo * 0.35, passo * 0.35)
				z += random.randf_range(-passo * 0.35, passo * 0.35)

			var h: float = terreno.data.get_height(Vector3(x, 0.0, z))
			if is_nan(h):
				continue

			var escala_altura := altura_min + random.randf() * escala
			var rot_y := random.randf_range(0.0, TAU)

			var t := Transform3D(Basis(Vector3.UP, rot_y), Vector3(x, h, z))
			t = t.scaled(Vector3(1.0, escala_altura, 1.0))

			mm.set_instance_transform(idx, t)
			mm.set_instance_color(idx, cor_grama)
			idx += 1

	# Ajusta o count real (pode haver menos por causa de nan nas bordas).
	mm.instance_count = idx

	_multimesh.multimesh = mm
	_multimesh.cast_shadow = projetar_sombras

	print("VegetacaoTerreno3D: %d gramas geradas em area %.0fx%.0f m" % [idx, area, area])


func _ajustar_cores_grama(terreno: Terrain3D) -> void:
	var data := terreno.data
	if not data:
		return

	# Tamanho do terreno (mismo valor de export do nó Terrain3D)
	var tamanho_terreno := 420.0
	var grid_size := data.map_width
	var cores_terreno := data.colors

	# Se o mapa de cores não tem dados, sai
	if cores_terreno.size() == 0 or grid_size <= 0:
		return

	# Para cada instância de grama
	var mm := _multimesh.multimesh
	var count := mm.instance_count

	# Centro do terreno no mundo (o terreno está centrado em 0,0)
	var centro := tamanho_terreno / 2.0

	for i in count:
		# Pega a transform da instância
		var transform := mm.get_instance_transform(i)
		var pos_mundo := transform.origin

		# Normaliza posição para -0.5 a +0.5 range, depois para 0 a 1
		# O terreno está centrado em origem, então:
		var x_rel := pos_mundo.x + centro
		var z_rel := pos_mundo.z + centro

		# Converte para coords de grid (0 a grid_size-1)
		var grid_x := clamp(int(round((x_rel / tamanho_terreno) * (grid_size - 1))), 0, grid_size - 1)
		var grid_z := clamp(int(round((z_rel / tamanho_terreno) * (grid_size - 1))), 0, grid_size - 1)

		# Índice no array de cores (row-major: z * width + x)
		var idx_cor := grid_z * grid_size + grid_x

		# Protege contra índice inválido e aplica cor do terreno
		if idx_cor >= 0 and idx_cor < cores_terreno.size():
			var cor_terreno := cores_terreno[idx_cor]
			mm.set_instance_color(i, cor_terreno)
