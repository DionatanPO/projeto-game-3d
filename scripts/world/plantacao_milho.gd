extends Node3D
## PlantacaoMilho: gera pes de milho procedurais sobre o solo arado.
## 4 MultiMeshes (caule, 2 folhas, espiga) = milhares de plantas com
## poucas chamadas de desenho. Semente fixa = layout deterministico.

const X0 := 2.0
const X1 := 40.0
const PASSO_F := 1.5
const Z0 := -20.0
const Z1 := 4.0
const PASSO_P := 1.5
const SEED := 42
const BASE_Y := 0.1


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var plantas: Array = []
	var x := X0
	while x <= X1:
		var z := Z0
		while z <= Z1:
			plantas.append({
				"pos": Vector3(x + rng.randf_range(-0.25, 0.25), BASE_Y, z + rng.randf_range(-0.25, 0.25)),
				"s": rng.randf_range(0.9, 1.2),
				"yaw": rng.randf_range(0.0, TAU),
			})
			z += PASSO_P
		x += PASSO_F
	print("MILHO_PES=", plantas.size())
	var mat_caule := _mat(Color(0.25, 0.5, 0.15))
	var mat_folha := _mat(Color(0.35, 0.62, 0.2))
	var mat_espiga := _mat(Color(0.75, 0.7, 0.25))
	var caule := CylinderMesh.new()
	caule.top_radius = 0.03
	caule.bottom_radius = 0.05
	caule.height = 1.6
	caule.radial_segments = 6
	var folha := BoxMesh.new()
	folha.size = Vector3(0.8, 0.03, 0.2)
	var espiga := SphereMesh.new()
	espiga.radius = 0.12
	espiga.height = 0.3
	espiga.radial_segments = 8
	espiga.rings = 4
	var t_caules: Array[Transform3D] = []
	var t_folha1: Array[Transform3D] = []
	var t_folha2: Array[Transform3D] = []
	var t_espigas: Array[Transform3D] = []
	for p in plantas:
		var s: float = p["s"]
		var base := Transform3D(Basis(Vector3.UP, p["yaw"]).scaled(Vector3(s, s, s)), p["pos"])
		t_caules.append(base * Transform3D(Basis(), Vector3(0, 0.8, 0)))
		t_folha1.append(base * Transform3D(Basis(Vector3.UP, 0.5), Vector3(0, 0.7, 0)))
		t_folha2.append(base * Transform3D(Basis(Vector3.UP, 2.2), Vector3(0, 1.1, 0)))
		t_espigas.append(base * Transform3D(Basis(), Vector3(0.15, 1.0, 0)))
	_multi(caule, mat_caule, t_caules)
	_multi(folha, mat_folha, t_folha1)
	_multi(folha, mat_folha, t_folha2)
	_multi(espiga, mat_espiga, t_espigas)


func _mat(cor: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = 0.9
	return m


func _multi(malha: Mesh, mat: Material, lista: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = malha
	mm.instance_count = lista.size()
	for i in lista.size():
		mm.set_instance_transform(i, lista[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
