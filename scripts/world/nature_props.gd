extends RefCounted
class_name NatureProps
## Catálogo do pack Ultimate Stylized Nature (63 modelos FBX).
## Centraliza os caminhos para instanciar rochas/árvores/vegetação por código.

const BASE := "res://assets/models/ultimate_nature/FBX"

const ARVORES: Array[String] = [
	"BirchTree_1", "BirchTree_2", "BirchTree_3", "BirchTree_4", "BirchTree_5",
	"MapleTree_1", "MapleTree_2", "MapleTree_3", "MapleTree_4", "MapleTree_5",
	"NormalTree_1", "NormalTree_2", "NormalTree_3", "NormalTree_4", "NormalTree_5",
	"PineTree_1", "PineTree_2", "PineTree_3", "PineTree_4", "PineTree_5",
	"PalmTree_1", "PalmTree_2", "PalmTree_3", "PalmTree_4", "PalmTree_5",
	"DeadTree_1", "DeadTree_2", "DeadTree_3", "DeadTree_4", "DeadTree_5",
	"DeadTree_6", "DeadTree_7", "DeadTree_8", "DeadTree_9", "DeadTree_10",
]

const ROCHAS: Array[String] = ["Rock_1", "Rock_2", "Rock_3", "Rock_4", "Rock_5"]

const VEGETACAO: Array[String] = [
	"Bush", "Bush_Flowers", "Bush_Large", "Bush_Large_Flowers", "Bush_Small", "Bush_Small_Flowers",
	"Grass_Large", "Grass_Large_Extruded", "Grass_Small",
	"Plant_1", "Plant_2", "Plant_Flowers",
	"Flower_1", "Flower_1_Clump", "Flower_2", "Flower_2_Clump",
	"Flower_3_Clump", "Flower_4_Clump", "Flower_5_Clump",
	"Petals_1", "Petals_2", "Petals_3", "Petals_4",
]


static func caminho(nome: String) -> String:
	return "%s/%s.fbx" % [BASE, nome]


static func instanciar(nome: String) -> Node3D:
	var cena: PackedScene = load(caminho(nome)) as PackedScene
	if cena == null:
		push_error("NatureProps: modelo '%s' não encontrado em %s" % [nome, caminho(nome)])
		return null
	return cena.instantiate() as Node3D


static func todos() -> Array[String]:
	var lista: Array[String] = []
	lista.append_array(ARVORES)
	lista.append_array(ROCHAS)
	lista.append_array(VEGETACAO)
	return lista
