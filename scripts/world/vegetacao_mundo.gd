extends Node3D
## VegetacaoMundo: espalha Plant_1..Plant_4 por todo o mapa usando poucos MultiMeshes.

const PACKS := [
	preload("res://assets/models/Plant_1.fbx"),
	preload("res://assets/models/Plant_2.fbx"),
	preload("res://assets/models/Plant_3.fbx"),
	preload("res://assets/models/Plant_4.fbx"),
]

const GRUPOS := 36
const POR_GRUPO := 10
const RAIO_GRUPO := 9.0
const ESC_MIN := 1.0
const ESC_MAX := 1.7
const SEED := 777
const LIMITE := 121.5

# [x, z, raio] a manter limpo (cenarios + estrada + galpao)
const EXCLUIR := [
	[0.0, 0.0, 55.0], [108.0, 0.0, 55.0], [-108.0, 0.0, 55.0],
	[0.0, -108.0, 55.0], [0.0, 108.0, 55.0], [-108.0, 108.0, 55.0],
	[108.0, -108.0, 55.0], [0.0, 12.6, 55.0],
	[-90.0, 0.7, 12.0], [-72.0, 0.7, 12.0], [-54.0, 0.7, 12.0],
	[-36.0, 0.7, 12.0], [-18.0, 0.7, 12.0], [-4.5, 0.7, 12.0],
	[-5.8, -53.6, 22.0],
]

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for pi in PACKS.size():
		var dados := _extrair_malha(PACKS[pi])
		if dados.is_empty():
			push_error("VegetacaoMundo: malha Plant_%d nao encontrada." % (pi + 1))
			continue
		var lista: Array[Transform3D] = []
		var grupos_ok := 0
		var tent := 0
		while grupos_ok < GRUPOS and tent < GRUPOS * 40:
			tent += 1
			var cx := rng.randf_range(-LIMITE, LIMITE)
			var cz := rng.randf_range(-LIMITE, LIMITE)
			if _excluido(cx, cz):
				continue
			grupos_ok += 1
			for _k in POR_GRUPO:
				var x := cx + rng.randf_range(-RAIO_GRUPO, RAIO_GRUPO)
				var z := cz + rng.randf_range(-RAIO_GRUPO, RAIO_GRUPO)
				if _excluido(x, z):
					continue
				var s := rng.randf_range(ESC_MIN, ESC_MAX)
				var base := Transform3D(
					Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * s),
					Vector3(x, _altura(x, z) - 0.05, z)
				)
				var t: Transform3D = base * (dados["transform"] as Transform3D)
				lista.append(t)
		print("VEGETACAO_Plant_", pi + 1, "=", lista.size())
		_multi(dados["mesh"], lista)

func _excluido(x: float, z: float) -> bool:
	for e in EXCLUIR:
		var dx := x - float(e[0])
		var dz := z - float(e[1])
		if dx * dx + dz * dz < float(e[2]) * float(e[2]):
			return true
	return false

func _altura(x: float, z: float) -> float:
	var t := get_parent().get_node_or_null("Terreno") as StaticBody3D
	if t != null and t.has_method("altura"):
		return float(t.call("altura", x, z))
	return 0.0

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
	const TAMANHO_LOTE := 100.0
	var lotes: Dictionary = {}
	for transform in lista:
		var celula := Vector2i(
			clampi(floori((transform.origin.x + 150.0) / TAMANHO_LOTE), 0, 2),
			clampi(floori((transform.origin.z + 150.0) / TAMANHO_LOTE), 0, 2)
		)
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
		var origem := Vector3(-150.0 + celula.x * TAMANHO_LOTE, -20.0, -150.0 + celula.y * TAMANHO_LOTE)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "VegetacaoLote_%d_%d" % [celula.x, celula.y]
		mmi.multimesh = mm
		mmi.custom_aabb = AABB(origem - Vector3(12.0, 0.0, 12.0), Vector3(TAMANHO_LOTE + 24.0, 50.0, TAMANHO_LOTE + 24.0))
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
