extends Node
## Autoload `SaveSystem`: salvamento local do progresso (user://savegame.json).

signal progresso_salvo
signal progresso_carregado(dados: Dictionary)

const CAMINHO_SAVE := "user://savegame.json"

var dados: Dictionary = {}


func _ready() -> void:
	carregar()


func tem_save() -> bool:
	return FileAccess.file_exists(CAMINHO_SAVE)


func carregar() -> Dictionary:
	if not tem_save():
		dados = _dados_padrao()
		return dados
	var arq := FileAccess.open(CAMINHO_SAVE, FileAccess.READ)
	if arq == null:
		push_error("SaveSystem: nao foi possivel ler o save.")
		dados = _dados_padrao()
		return dados
	var parsed: Variant = JSON.parse_string(arq.get_as_text())
	if parsed is Dictionary:
		dados = parsed
	else:
		push_error("SaveSystem: save corrompido, usando padrao.")
		dados = _dados_padrao()
	progresso_carregado.emit(dados)
	return dados


func salvar() -> void:
	dados["versao"] = 1
	var arq := FileAccess.open(CAMINHO_SAVE, FileAccess.WRITE)
	if arq == null:
		push_error("SaveSystem: nao foi possivel escrever o save.")
		return
	arq.store_string(JSON.stringify(dados, "\t"))
	progresso_salvo.emit()


func apagar() -> void:
	if tem_save():
		DirAccess.remove_absolute(CAMINHO_SAVE)
	dados = _dados_padrao()


func _dados_padrao() -> Dictionary:
	return {
		"versao": 1,
		"descobertas": [],
		"missoes_concluidas": [],
		"posicao_jogador": [-96.79012, 1.5, 0.73486805],
		"posicao_drone": [-2.0, 1.0, -50.0],
		"veiculo": "jogador",
		"tempo_jogado_seg": 0.0,
	}
