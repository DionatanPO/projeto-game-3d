extends CanvasLayer
## HUD: objetivo atual, progresso, dialogo educativo e diario de descobertas.
## Pausa o mundo enquanto o dialogo esta aberto.

@onready var objetivo: Label = $Topo/Objetivo
@onready var descobertas_label: Label = $Topo/Descobertas
@onready var dialogo: PanelContainer = $Dialogo
@onready var dialogo_titulo: Label = $Dialogo/VBox/DialogoTitulo
@onready var dialogo_texto: Label = $Dialogo/VBox/DialogoTexto
@onready var dialogo_fonte: Label = $Dialogo/VBox/DialogoFonte
@onready var diario: PanelContainer = $Diario
@onready var lista_descobertas: ItemList = $Diario/VBox/ListaDescobertas
@onready var missoes_info: Label = $Diario/VBox/MissoesInfo

var _dialogo_aberto_para := ""


func _ready() -> void:
	Jogo.dialogo_solicitado.connect(_abrir_dialogo)
	Jogo.alternar_diario.connect(_alternar_diario)
	Jogo.descoberta_registrada.connect(_on_descoberta)
	Missoes.missao_concluida.connect(_on_missao)
	Missoes.missoes_atualizadas.connect(_atualizar_topo)
	dialogo.visible = false
	diario.visible = false
	_atualizar_topo()


func _abrir_dialogo(conteudo_id: String) -> void:
	var c: Dictionary = Jogo.obter_conteudo(conteudo_id)
	if c.is_empty():
		push_warning("HUD: conteudo '%s' nao encontrado." % conteudo_id)
		return
	_dialogo_aberto_para = conteudo_id
	dialogo_titulo.text = c.get("titulo", conteudo_id)
	dialogo_texto.text = c.get("texto", "")
	dialogo_fonte.text = "Fonte: " + str(c.get("fonte", ""))
	dialogo.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_entendi() -> void:
	dialogo.visible = false
	get_tree().paused = false
	Jogo.registrar_descoberta(_dialogo_aberto_para)
	_dialogo_aberto_para = ""


func _alternar_diario() -> void:
	diario.visible = not diario.visible
	if diario.visible:
		_preencher_diario()


func _on_botao_diario() -> void:
	_alternar_diario()


func _on_fechar_diario() -> void:
	diario.visible = false


func _on_voltar_menu() -> void:
	get_tree().paused = false
	SaveSystem.salvar()
	get_tree().change_scene_to_file("res://scenes/ui/menus/menu_inicial.tscn")


func _on_descoberta(_ponto_id: String) -> void:
	_atualizar_topo()
	if diario.visible:
		_preencher_diario()


func _on_missao(_missao_id: String) -> void:
	_atualizar_topo()
	if diario.visible:
		_preencher_diario()


func _atualizar_topo() -> void:
	var prox: Dictionary = Missoes.proxima_pendente()
	if prox.is_empty():
		objetivo.text = "Todas as missoes concluidas! Parabens!"
	else:
		objetivo.text = "Missao: %s — %s" % [prox.get("titulo", ""), prox.get("descricao", "")]
	descobertas_label.text = "Descobertas: %d/%d   Missoes: %d/%d" % [
		Jogo.total_descobertas(), Jogo.total_pontos(),
		Missoes.total_concluidas(), Missoes.total_missoes()
	]


func _preencher_diario() -> void:
	lista_descobertas.clear()
	var descobertas: Array = SaveSystem.dados.get("descobertas", [])
	if descobertas.is_empty():
		lista_descobertas.add_item("Nenhuma descoberta ainda. Explore as placas!")
	else:
		for ponto: String in descobertas:
			var c: Dictionary = Jogo.obter_conteudo(ponto)
			lista_descobertas.add_item(c.get("titulo", ponto))
	var linhas: Array = []
	for missao_id: String in Missoes.ordem:
		var m: Dictionary = Missoes.por_id[missao_id]
		var marca := "[x]" if Missoes.esta_concluida(missao_id) else "[ ]"
		linhas.append("%s %s" % [marca, m.get("titulo", missao_id)])
	missoes_info.text = "\n".join(linhas)
