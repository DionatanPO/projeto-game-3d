extends CanvasLayer
## HUD educativo. Continua recebendo entrada quando o jogo está pausado.

@onready var dialogo: PanelContainer = $Dialogo
@onready var dialogo_titulo: Label = $Dialogo/Inset/Conteudo/DialogoTitulo
@onready var dialogo_texto: Label = $Dialogo/Inset/Conteudo/DialogoTexto
@onready var dialogo_fonte: Label = $Dialogo/Inset/Conteudo/DialogoFonte
@onready var diario: PanelContainer = $Diario
@onready var lista_box: VBoxContainer = $Diario/Inset/Conteudo/Abas/Missão/Margem/Coluna/ListaBox
@onready var aviso_vazio: Label = $Diario/Inset/Conteudo/Abas/Missão/Margem/Coluna/AvisoVazio
@onready var missoes_info: Label = $Diario/Inset/Conteudo/Abas/Missão/Margem/Coluna/MissoesInfo
@onready var objetivo_missao: Label = $Diario/Inset/Conteudo/Abas/Missão/Margem/Coluna/Objetivo
@onready var slider_volume: HSlider = $Diario/Inset/Conteudo/Abas/Áudio/Margem/Coluna/VolumeGeral
@onready var check_mudo: CheckButton = $Diario/Inset/Conteudo/Abas/Áudio/Margem/Coluna/Mudo
@onready var check_tela: CheckButton = $Diario/Inset/Conteudo/Abas/Tela/Margem/Coluna/TelaCheia
@onready var abas: TabContainer = $Diario/Inset/Conteudo/Abas
@onready var btn_aba_missao: Button = $Diario/Inset/Conteudo/SeletorAbas/BtnMissao
@onready var btn_aba_controles: Button = $Diario/Inset/Conteudo/SeletorAbas/BtnControles
@onready var btn_aba_audio: Button = $Diario/Inset/Conteudo/SeletorAbas/BtnAudio
@onready var btn_aba_tela: Button = $Diario/Inset/Conteudo/SeletorAbas/BtnTela

var _dialogo_aberto_para := ""
var _botoes_abas: Array = []
@onready var scrim: ColorRect = $Scrim
@onready var popup_missao: PanelContainer = $MissaoCompleta
@onready var popup_texto: Label = $MissaoCompleta/Inset/Conteudo/Texto

const CENA_FASE_TESTE := "res://scenes/world/environment/fase_teste.tscn"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AgroUITheme.apply_to(dialogo)
	AgroUITheme.apply_to(diario)
	AgroUITheme.style_panel(dialogo, "glass")
	AgroUITheme.style_panel(diario, "glass")
	AgroUITheme.apply_to(popup_missao)
	AgroUITheme.style_panel(popup_missao, "glass")
	$MissaoCompleta/Inset/Conteudo/Titulo.add_theme_font_size_override("font_size", 20)
	_configurar_espacamento()
	dialogo_titulo.add_theme_font_size_override("font_size", 16)
	dialogo_texto.add_theme_font_size_override("font_size", 11)
	dialogo_fonte.add_theme_font_size_override("font_size", 9)
	$Diario/Inset/Conteudo/Titulo.add_theme_font_size_override("font_size", 15)
	missoes_info.add_theme_font_size_override("font_size", 12)
	aviso_vazio.add_theme_font_size_override("font_size", 12)
	aviso_vazio.add_theme_color_override("font_color", Color("#a16207"))
	objetivo_missao.add_theme_font_size_override("font_size", 14)
	$Diario/Inset/Conteudo/Abas/Controles/Margem/Coluna/TextoControles.add_theme_font_size_override("font_size", 12)
	$Diario/Inset/Conteudo/Subtitulo.add_theme_color_override("font_color", AgroUITheme.MUTED_INK)
	$Dialogo/Inset/Conteudo/BotaoEntendi.pressed.connect(_on_entendi)
	$Diario/Inset/Conteudo/Acoes/BotaoFechar.pressed.connect(_on_fechar_diario)
	$Diario/Inset/Conteudo/Acoes/BotaoVoltar.pressed.connect(_on_voltar_menu)
	$MissaoCompleta/Inset/Conteudo/BotaoNovaFase.pressed.connect(_on_ir_nova_fase)
	$MissaoCompleta/Inset/Conteudo/BotaoContinuar.pressed.connect(_on_continuar_explorando)
	AgroUITheme.style_primary_button($Dialogo/Inset/Conteudo/BotaoEntendi)
	AgroUITheme.style_secondary_button($Diario/Inset/Conteudo/Acoes/BotaoFechar)
	AgroUITheme.style_secondary_button($Diario/Inset/Conteudo/Acoes/BotaoVoltar)
	AgroUITheme.style_primary_button($MissaoCompleta/Inset/Conteudo/BotaoNovaFase)
	AgroUITheme.style_secondary_button($MissaoCompleta/Inset/Conteudo/BotaoContinuar)
	slider_volume.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0)
	check_mudo.set_pressed_no_signal(AudioServer.is_bus_mute(0))
	check_tela.set_pressed_no_signal(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	slider_volume.value_changed.connect(_on_volume_mudou)
	check_mudo.toggled.connect(_on_mudo)
	check_tela.toggled.connect(_on_tela_cheia)
	_botoes_abas = [btn_aba_missao, btn_aba_controles, btn_aba_audio, btn_aba_tela]
	for i in _botoes_abas.size():
		_botoes_abas[i].pressed.connect(_on_aba.bind(i))
	_on_aba(0)
	dialogo.hide()
	diario.hide()
	popup_missao.hide()
	scrim.hide()
	Jogo.dialogo_solicitado.connect(_abrir_dialogo)
	Jogo.alternar_diario.connect(_alternar_diario)
	Jogo.descoberta_registrada.connect(_on_descoberta)
	Missoes.missao_concluida.connect(_on_missao)

func _configurar_espacamento() -> void:
	for inset in [$Dialogo/Inset, $Diario/Inset]:
		inset.add_theme_constant_override("margin_left", 20)
		inset.add_theme_constant_override("margin_top", 17)
		inset.add_theme_constant_override("margin_right", 20)
		inset.add_theme_constant_override("margin_bottom", 17)
	$Dialogo/Inset/Conteudo.add_theme_constant_override("separation", 10)
	$Diario/Inset/Conteudo.add_theme_constant_override("separation", 8)

func _abrir_dialogo(conteudo_id: String) -> void:
	var c: Dictionary = Jogo.obter_conteudo(conteudo_id)
	if c.is_empty():
		push_warning("HUD: conteúdo '%s' não encontrado." % conteudo_id)
		return
	_dialogo_aberto_para = conteudo_id
	dialogo_titulo.text = str(c.get("titulo", conteudo_id))
	dialogo_texto.text = str(c.get("texto", ""))
	dialogo_fonte.text = "Fonte: " + str(c.get("fonte", ""))
	dialogo.show()
	scrim.show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Dialogo/Inset/Conteudo/BotaoEntendi.grab_focus()

func _on_entendi() -> void:
	dialogo.hide()
	scrim.hide()
	get_tree().paused = false
	if not _dialogo_aberto_para.is_empty():
		Jogo.registrar_descoberta(_dialogo_aberto_para)
	_dialogo_aberto_para = ""

func _alternar_diario() -> void:
	diario.visible = not diario.visible
	scrim.visible = diario.visible
	get_tree().paused = diario.visible
	if diario.visible:
		_preencher_diario()
		$Diario/Inset/Conteudo/Acoes/BotaoFechar.grab_focus()

func _on_fechar_diario() -> void:
	diario.hide()
	scrim.hide()
	get_tree().paused = false

func _unhandled_key_input(event: InputEvent) -> void:
	if diario.visible and (event.is_action_pressed("diario") or event.is_action_pressed("ui_cancel")):
		_on_fechar_diario()
		get_viewport().set_input_as_handled()

func _on_volume_mudou(valor: float) -> void:
	AudioServer.set_bus_mute(0, false)
	check_mudo.set_pressed_no_signal(false)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(valor / 100.0, 0.0001)))

func _on_mudo(ativado: bool) -> void:
	AudioServer.set_bus_mute(0, ativado)

func _on_tela_cheia(ativado: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if ativado else DisplayServer.WINDOW_MODE_WINDOWED)

func _on_aba(indice: int) -> void:
	abas.current_tab = indice
	for i in _botoes_abas.size():
		var b: Button = _botoes_abas[i]
		b.set_pressed_no_signal(i == indice)
		if i == indice:
			AgroUITheme.style_primary_button(b)
		else:
			AgroUITheme.style_secondary_button(b)

func _on_ir_nova_fase() -> void:
	get_tree().paused = false
	SaveSystem.salvar()
	get_tree().change_scene_to_file(CENA_FASE_TESTE)

func _on_continuar_explorando() -> void:
	popup_missao.hide()
	if not diario.visible and not dialogo.visible:
		scrim.hide()
		get_tree().paused = false

func _on_voltar_menu() -> void:
	get_tree().paused = false
	SaveSystem.salvar()
	get_tree().change_scene_to_file("res://scenes/ui/menus/menu_inicial.tscn")

func _on_descoberta(_ponto_id: String) -> void:
	if diario.visible:
		_preencher_diario()

func _on_missao(missao_id: String) -> void:
	if diario.visible:
		_preencher_diario()
	var m: Dictionary = Missoes.por_id.get(missao_id, {})
	popup_texto.text = str(m.get("titulo", missao_id))
	popup_missao.show()
	scrim.show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$MissaoCompleta/Inset/Conteudo/BotaoNovaFase.grab_focus()

func _preencher_diario() -> void:
	var prox: Dictionary = Missoes.proxima_pendente()
	if prox.is_empty():
		objetivo_missao.text = "Todas as missões concluídas! Parabéns!"
	else:
		objetivo_missao.text = "OBJETIVO  •  %s — %s" % [prox.get("titulo", ""), prox.get("descricao", "")]
	var descobertas: Variant = SaveSystem.dados.get("descobertas", [])
	var vazio: bool = not (descobertas is Array) or descobertas.is_empty()
	aviso_vazio.visible = vazio
	lista_box.visible = not vazio
	for f in lista_box.get_children():
		lista_box.remove_child(f)
		f.free()
	if not vazio:
		for ponto: Variant in descobertas:
			var c: Dictionary = Jogo.obter_conteudo(str(ponto))
			var item := Label.new()
			item.text = "•  " + str(c.get("titulo", ponto))
			item.add_theme_font_size_override("font_size", 12)
			lista_box.add_child(item)
	var linhas: Array[String] = []
	for missao_id: String in Missoes.ordem:
		var m: Dictionary = Missoes.por_id.get(missao_id, {})
		var marca := "✓" if Missoes.esta_concluida(missao_id) else "○"
		linhas.append("%s  %s" % [marca, m.get("titulo", missao_id)])
	missoes_info.text = "\n".join(linhas)
