extends Area3D
## Placa educativa reutilizavel: mostra prompt e abre o dialogo com E.
## Configure por instancia: `conteudo_id` (chave em data/conteudos.json).

@export var conteudo_id := "solo"
@export var titulo_placa := "Placa Educativa"

@onready var prompt: Label3D = $Prompt
@onready var titulo: Label3D = $Titulo

var _jogador_perto := false


func _ready() -> void:
	titulo.text = titulo_placa
	prompt.visible = false
	body_entered.connect(_on_corpo_entrou)
	body_exited.connect(_on_corpo_saiu)


func _process(_delta: float) -> void:
	if _jogador_perto and Input.is_action_just_pressed("interagir"):
		Jogo.abrir_dialogo(conteudo_id)


func _on_corpo_entrou(corpo: Node3D) -> void:
	if corpo.is_in_group("jogador"):
		_jogador_perto = true
		prompt.visible = true


func _on_corpo_saiu(corpo: Node3D) -> void:
	if corpo.is_in_group("jogador"):
		_jogador_perto = false
		prompt.visible = false
