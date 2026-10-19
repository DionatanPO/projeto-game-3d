extends Control
## Menu principal moderno em layout lateral no estilo Tomb Raider / AAA.
## Itens tipográficos sem caixa/fundo, foco elegante com slide e barra esmeralda.

const CENA_MUNDO := "res://scenes/world/mundo.tscn"
const CENA_LOADING := "res://scenes/ui/menus/loading.tscn"

@onready var backdrop: TextureRect = get_node_or_null("Backdrop") as TextureRect
@onready var menu_lateral: Control = get_node_or_null("MenuLateral") as Control
@onready var botao_novo: Button = find_child("BotaoNovo", true, false) as Button
@onready var botao_sair: Button = find_child("BotaoSair", true, false) as Button
@onready var barra_novo: ColorRect = get_node_or_null("MenuLateral/Coluna/Botoes/ItemNovo/Barra") as ColorRect
@onready var barra_sair: ColorRect = get_node_or_null("MenuLateral/Coluna/Botoes/ItemSair/Barra") as ColorRect
@onready var fade_rect: ColorRect = get_node_or_null("FadeRect") as ColorRect

var _som_ui_click: AudioStreamPlayer
var _som_ui_hover: AudioStreamPlayer
var _transicao_em_andamento := false


func _ready() -> void:
	# Garante que a cor de limpeza entre transições de tela seja sempre preta (evita piscar azul)
	RenderingServer.set_default_clear_color(Color.BLACK)

	# O menu ocupa toda a área disponível.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Ajusta o fundo para cobrir proporcionalmente sem distorcer ou cortar
	if backdrop:
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	# Valida a estrutura da cena antes de continuar.
	if not _validar_nos():
		return

	# Configura a camada de fade.
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.color = Color.BLACK
	fade_rect.modulate.a = 0.0
	fade_rect.z_index = 100

	# Ajusta texto conforme progresso salvo
	if SaveSystem.tem_save():
		botao_novo.text = "CONTINUAR JORNADA"
	else:
		botao_novo.text = "COMEÇAR JORNADA"

	# Configura áudio da UI
	_configurar_sons_ui()

	# Aplica estilo tipográfico e microinterações Tomb Raider
	_configurar_item_menu(botao_novo, barra_novo)
	_configurar_item_menu(botao_sair, barra_sair)

	if not botao_novo.pressed.is_connected(_on_novo_jogo):
		botao_novo.pressed.connect(_on_novo_jogo)

	if not botao_sair.pressed.is_connected(_on_sair):
		botao_sair.pressed.connect(_on_sair)

	# Animação cinematográfica suave de entrada
	modulate.a = 0.0
	var entrada := create_tween()
	entrada.set_trans(Tween.TRANS_CUBIC)
	entrada.set_ease(Tween.EASE_OUT)
	entrada.tween_property(self, "modulate:a", 1.0, 0.7)

	botao_novo.grab_focus()


func _validar_nos() -> bool:
	var valido := true

	if menu_lateral == null:
		push_error("Menu: não foi encontrado o nó 'MenuLateral'.")
		valido = false

	if botao_novo == null:
		push_error("Menu: não foi encontrado 'BotaoNovo'.")
		valido = false

	if botao_sair == null:
		push_error("Menu: não foi encontrado 'BotaoSair'.")
		valido = false

	if fade_rect == null:
		push_error("Menu: não foi encontrado o nó 'FadeRect'.")
		valido = false

	return valido


func _configurar_item_menu(botao: Button, barra: ColorRect) -> void:
	if botao == null:
		return

	# Aplica o estilo de texto puro sem caixa de fundo
	AgroUITheme.style_text_menu_button(botao)

	if barra != null:
		barra.modulate.a = 0.0

	var on_enter := func() -> void:
		_tocar_hover_ui()
		var tw := create_tween().set_parallel(true)
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(botao, "position:x", 16.0, 0.18)
		if barra != null:
			tw.tween_property(barra, "modulate:a", 1.0, 0.18)

	var on_exit := func() -> void:
		var tw := create_tween().set_parallel(true)
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(botao, "position:x", 0.0, 0.18)
		if barra != null:
			tw.tween_property(barra, "modulate:a", 0.0, 0.18)

	if not botao.mouse_entered.is_connected(on_enter):
		botao.mouse_entered.connect(on_enter)
	if not botao.focus_entered.is_connected(on_enter):
		botao.focus_entered.connect(on_enter)

	if not botao.mouse_exited.is_connected(on_exit):
		botao.mouse_exited.connect(on_exit)
	if not botao.focus_exited.is_connected(on_exit):
		botao.focus_exited.connect(on_exit)


func _on_novo_jogo() -> void:
	if _transicao_em_andamento:
		return

	_transicao_em_andamento = true
	botao_novo.disabled = true
	botao_sair.disabled = true

	if not SaveSystem.tem_save():
		SaveSystem.apagar()

	Loading.proxima_cena = CENA_MUNDO
	Loading.titulo_carga = "Carregando a fazenda..."

	# Fade para preto antes de mudar de cena
	var transicao := create_tween()
	transicao.set_trans(Tween.TRANS_CUBIC)
	transicao.set_ease(Tween.EASE_IN_OUT)

	transicao.tween_property(fade_rect, "modulate:a", 1.0, 1.2)
	transicao.tween_callback(func() -> void:
		get_tree().change_scene_to_file(CENA_LOADING)
	)


func _on_sair() -> void:
	if _transicao_em_andamento:
		return

	_transicao_em_andamento = true
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

	for botao: Button in [botao_novo, botao_sair]:
		if botao != null and not botao.pressed.is_connected(_tocar_click_ui):
			botao.pressed.connect(_tocar_click_ui)


func _tocar_click_ui() -> void:
	if _som_ui_click != null and _som_ui_click.stream != null:
		_som_ui_click.play()


func _tocar_hover_ui() -> void:
	if _som_ui_hover != null and _som_ui_hover.stream != null:
		_som_ui_hover.play()
