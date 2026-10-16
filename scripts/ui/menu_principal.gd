extends Control
## Menu principal minimalista: Novo jogo / Sair, centralizado e responsivo.

const CENA_MUNDO := "res://scenes/world/mundo.tscn"

@onready var botao_novo: Button = $Centro/Botoes/BotaoNovo
@onready var botao_sair: Button = $Centro/Botoes/BotaoSair

var _som_ui_click: AudioStreamPlayer
var _som_ui_hover: AudioStreamPlayer


func _ready() -> void:
	AgroUITheme.apply_to(self)
	AgroUITheme.style_primary_button(botao_novo)
	AgroUITheme.style_secondary_button(botao_sair)
	_configurar_sons_ui()
	botao_novo.pressed.connect(_on_novo_jogo)
	botao_sair.pressed.connect(_on_sair)
	botao_novo.grab_focus()


func _on_novo_jogo() -> void:
	SaveSystem.apagar()
	var erro := get_tree().change_scene_to_file(CENA_MUNDO)
	if erro != OK:
		push_error("MenuPrincipal: falha ao abrir a cena do mundo (%s)." % error_string(erro))


func _on_sair() -> void:
	get_tree().quit()


func _configurar_sons_ui() -> void:
	_som_ui_click = AudioStreamPlayer.new()
	_som_ui_click.stream = load("res://assets/audio/ui/click1.ogg")
	_som_ui_click.bus = "Efeitos"
	add_child(_som_ui_click)
	_som_ui_hover = AudioStreamPlayer.new()
	_som_ui_hover.stream = load("res://assets/audio/ui/rollover1.ogg")
	_som_ui_hover.bus = "Efeitos"
	_som_ui_hover.volume_db = -6.0
	add_child(_som_ui_hover)
	for b in [botao_novo, botao_sair]:
		b.pressed.connect(_tocar_click_ui)
		b.mouse_entered.connect(_tocar_hover_ui)


func _tocar_click_ui() -> void:
	if _som_ui_click != null and _som_ui_click.stream != null:
		_som_ui_click.play()


func _tocar_hover_ui() -> void:
	if _som_ui_hover != null and _som_ui_hover.stream != null:
		_som_ui_hover.play()
