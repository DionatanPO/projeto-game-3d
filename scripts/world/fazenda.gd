extends Node3D
## Fazenda: cena do mundo. Gera as fileiras de plantas por codigo
## (malhas e materiais compartilhados = menos memoria, PCs moderados).

const FILEIRAS: Array = [
	{"x": -12.0, "cultura": "soja", "cor": Color(0.30, 0.62, 0.28)},
	{"x": 0.0, "cultura": "milho", "cor": Color(0.45, 0.66, 0.25)},
	{"x": 12.0, "cultura": "pousio", "cor": Color(0.42, 0.30, 0.18)},
]

const PLANTAS_POR_FILEIRA := 8
const ESPACAMENTO := 2.2
const Z_INICIAL := -7.7


func _ready() -> void:
	_criar_fileiras()


func _criar_fileiras() -> void:
	var malha_planta := SphereMesh.new()
	malha_planta.radius = 0.28
	malha_planta.height = 0.7
	for f: Dictionary in FILEIRAS:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = f["cor"]
		mat.roughness = 0.9
		for i: int in PLANTAS_POR_FILEIRA:
			var planta := MeshInstance3D.new()
			planta.mesh = malha_planta
			planta.set_surface_override_material(0, mat)
			planta.position = Vector3(float(f["x"]), 0.45, Z_INICIAL + float(i) * ESPACAMENTO)
			add_child(planta)
