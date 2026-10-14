extends Node3D
## Mundo: cena agregadora. Instancia os 4 cenarios, cada um na sua origem
## no mundo (ver CENARIOS.md). Modele cada cenario no seu arquivo; aqui
## nada de conteudo, so posicionamento + luz/ceu compartilhados.

const ORIGENS := {
	"sede": Vector3(0, 0, 0),
	"milho": Vector3(120, 0, 0),
	"soja": Vector3(-120, 0, 0),
	"silo": Vector3(0, 0, -120),
	"solar": Vector3(0, 0, 120),
	"eolico": Vector3(-120, 0, 120),
	"galpao": Vector3(120, 0, -120),
}

const NO_CENARIO := {
	"sede": "SedeFazenda",
	"milho": "PlantacaoMilho",
	"soja": "PlantacaoSoja",
	"silo": "EstruturaSilo",
	"solar": "ParqueSolar",
	"eolico": "ParqueEolico",
	"galpao": "Galpao",
}


func _ready() -> void:
	pass


## Leva o jogador (grupo "jogador") ate a origem de um cenario.
func teleportar_para(cenario: String) -> void:
	if not ORIGENS.has(cenario):
		push_error("Mundo: cenario '%s' nao existe." % cenario)
		return
	var alvos := get_tree().get_nodes_in_group("jogador")
	if alvos.is_empty():
		push_error("Mundo: nenhum jogador na cena.")
		return
	var corpo := alvos[0] as Node3D
	var destino: Vector3 = ORIGENS[cenario] + Vector3(0, 2, 14)
	corpo.position = destino
	if corpo is CharacterBody3D:
		(corpo as CharacterBody3D).velocity = Vector3.ZERO
