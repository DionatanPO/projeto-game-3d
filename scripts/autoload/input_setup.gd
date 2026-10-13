extends Node
## Autoload `InputSetup`: garante as acoes de entrada do projeto base.
## Se as acoes ja existirem (definidas no editor), nada e alterado.

const ACOES: Dictionary = {
	"mover_frente": [KEY_W, KEY_UP],
	"mover_tras": [KEY_S, KEY_DOWN],
	"mover_esq": [KEY_A, KEY_LEFT],
	"mover_dir": [KEY_D, KEY_RIGHT],
	"pular": [KEY_SPACE],
	"correr": [KEY_SHIFT],
	"interagir": [KEY_E],
	"diario": [KEY_TAB],
}


func _ready() -> void:
	for acao: String in ACOES.keys():
		if InputMap.has_action(acao):
			continue
		InputMap.add_action(acao, 0.2)
		for tecla: Key in ACOES[acao]:
			var evento := InputEventKey.new()
			evento.physical_keycode = tecla
			InputMap.action_add_event(acao, evento)
