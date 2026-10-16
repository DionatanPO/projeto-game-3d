extends Node3D
## Pe de soja em grade; os lotes espaciais permitem culling por trecho.

const PACK := preload("res://assets/models/Plant_1.fbx")
const X0 := -16.0
const X1 := 25.0
const PASSO_F := 2.2
const Z0 := -24.0
const Z1 := 8.0
const PASSO_P := 2.2
const SEED := 43
const BASE_Y := 0.0

func _ready() -> void:
	_apagar_sombra_solo()
	var dados := _extrair_malha(PACK)
	if dados.is_empty():
		push_error("PlantacaoSoja: malha da soja nao encontrada.")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var lista: Array[Transform3D] = []
	var x := X0
	while x <= X1:
		var z := Z0
		while z <= Z1:
			var pos := Vector3(x + rng.randf_range(-0.25, 0.25), BASE_Y, z + rng.randf_range(-0.25, 0.25))
			var s := rng.randf_range(0.55, 0.70)
			var base := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * s), pos)
			lista.append(base * (dados["transform"] as Transform3D))
			z += PASSO_P
		x += PASSO_F
	print("SOJA=", lista.size())
	_multi(dados["mesh"], lista)

func _apagar_sombra_solo() -> void:
	for f in get_children():
		if "Solo" in f.name:
			for mi in f.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _extrair_malha(pack: PackedScene) -> Dictionary:
	var tmp := pack.instantiate() as Node
	var achados := tmp.find_children("*", "MeshInstance3D", true, false)
	var dados := {}
	if achados.size() > 0:
		var instancia := achados[0] as MeshInstance3D
		dados = {"mesh": instancia.mesh, "transform": instancia.transform}
	tmp.free()
	return dados

func _multi(malha: Mesh, lista: Array[Transform3D]) -> void:
	if lista.is_empty():
		return
	const LARGURA_LOTE := 24.0
	const PROFUNDIDADE_LOTE := 16.0
	var lotes: Dictionary = {}
	for transform in lista:
		var celula := Vector2i(floori(transform.origin.x / LARGURA_LOTE), floori(transform.origin.z / PROFUNDIDADE_LOTE))
		if not lotes.has(celula):
			lotes[celula] = []
		lotes[celula].append(transform)
	for celula in lotes:
		var transforms: Array = lotes[celula]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = malha
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "SojaMultiMesh_%d_%d" % [celula.x, celula.y]
		mmi.multimesh = mm
		mmi.custom_aabb = AABB(
			Vector3(celula.x * LARGURA_LOTE - 3.0, -3.0, celula.y * PROFUNDIDADE_LOTE - 3.0),
			Vector3(LARGURA_LOTE + 6.0, 16.0, PROFUNDIDADE_LOTE + 6.0)
		)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
