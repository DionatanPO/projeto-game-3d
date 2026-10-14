extends Control
## Menu principal responsivo, com estados de save claros e foco de teclado.

const CENA_MUNDO := "res://scenes/world/mundo.tscn"

@onready var botao_novo: Button = $SafeArea/Columns/ActionPanel/Inset/Content/BotaoNovo
@onready var botao_continuar: Button = $SafeArea/Columns/ActionPanel/Inset/Content/BotaoContinuar
@onready var botao_sair: Button = $SafeArea/Columns/ActionPanel/Inset/Content/BotaoSair
@onready var status: Label = $SafeArea/Columns/ActionPanel/Inset/Content/Status
@onready var progresso: Label = $SafeArea/Columns/ActionPanel/Inset/Content/Progresso

func _ready() -> void:
	AgroUITheme.apply_to(self)
	AgroUITheme.style_panel($SafeArea/Columns/IntroPanel)
	AgroUITheme.style_panel($SafeArea/Columns/ActionPanel, "dark")
	AgroUITheme.style_primary_button(botao_novo)
	AgroUITheme.style_secondary_button(botao_continuar)
	AgroUITheme.style_secondary_button(botao_sair)
	_estilizar_textos()
	_configurar_espacamento()
	botao_novo.pressed.connect(_on_novo_jogo)
	botao_continuar.pressed.connect(_on_continuar)
	botao_sair.pressed.connect(_on_sair)
	botao_continuar.disabled = not _tem_progresso()
	botao_continuar.tooltip_text = "Continue sua jornada salva." if not botao_continuar.disabled else "Leia uma placa no jogo para habilitar o progresso salvo."
	_atualizar_progresso()
	status.text = "Escolha uma opção para começar."
	botao_novo.grab_focus()

func _estilizar_textos() -> void:
	var brand: Label = $SafeArea/Columns/IntroPanel/Inset/Content/BrandRow/BrandName
	brand.add_theme_font_size_override("font_size", 20)
	brand.add_theme_color_override("font_color", AgroUITheme.FIELD_GREEN)
	var eyebrow: Label = $SafeArea/Columns/IntroPanel/Inset/Content/Eyebrow
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", AgroUITheme.MUTED_INK)
	var titulo: Label = $SafeArea/Columns/IntroPanel/Inset/Content/Titulo
	titulo.add_theme_font_size_override("font_size", 44)
	titulo.add_theme_color_override("font_color", AgroUITheme.FIELD_GREEN)
	var descricao: Label = $SafeArea/Columns/IntroPanel/Inset/Content/Descricao
	descricao.add_theme_font_size_override("font_size", 19)
	descricao.add_theme_color_override("font_color", AgroUITheme.MUTED_INK)
	var destaques := {
		"SoloNumero": "Solo/SoloNumero", "CulturasNumero": "Culturas/CulturasNumero", "TecnologiaNumero": "Tecnologia/TecnologiaNumero",
		"SoloTexto": "Solo/SoloTexto", "CulturasTexto": "Culturas/CulturasTexto", "TecnologiaTexto": "Tecnologia/TecnologiaTexto"
	}
	for nome: String in destaques:
		var rotulo := get_node("SafeArea/Columns/IntroPanel/Inset/Content/Destaques/%s" % destaques[nome]) as Label
		var eh_numero := nome.ends_with("Numero")
		rotulo.add_theme_font_size_override("font_size", 21 if eh_numero else 12)
		rotulo.add_theme_color_override("font_color", AgroUITheme.FIELD_GREEN if eh_numero else AgroUITheme.MUTED_INK)
	$SafeArea/Columns/IntroPanel/Inset/Content/RodapeEditorial.add_theme_font_size_override("font_size", 11)
	AgroUITheme.set_label_color($SafeArea/Columns/ActionPanel/Inset/Content/TituloAcoes, AgroUITheme.CREAM)
	$SafeArea/Columns/ActionPanel/Inset/Content/TituloAcoes.add_theme_font_size_override("font_size", 31)
	AgroUITheme.set_label_color($SafeArea/Columns/ActionPanel/Inset/Content/Selo, AgroUITheme.ACCENT_HOVER)
	$SafeArea/Columns/ActionPanel/Inset/Content/Selo.add_theme_font_size_override("font_size", 12)
	AgroUITheme.set_label_color($SafeArea/Columns/ActionPanel/Inset/Content/DescricaoAcoes, AgroUITheme.CREAM)
	AgroUITheme.set_label_color(status, AgroUITheme.CREAM)
	AgroUITheme.set_label_color(progresso, AgroUITheme.CREAM)
	progresso.add_theme_font_size_override("font_size", 14)
	AgroUITheme.set_label_color($SafeArea/Columns/ActionPanel/Inset/Content/Rodape, AgroUITheme.CREAM)
	$SafeArea/Columns/ActionPanel/Inset/Content/Rodape.add_theme_font_size_override("font_size", 11)

func _configurar_espacamento() -> void:
	$SafeArea.add_theme_constant_override("margin_left", 34)
	$SafeArea.add_theme_constant_override("margin_top", 30)
	$SafeArea.add_theme_constant_override("margin_right", 34)
	$SafeArea.add_theme_constant_override("margin_bottom", 30)
	$SafeArea/Columns.add_theme_constant_override("separation", 22)
	$SafeArea/Columns/IntroPanel/Inset.add_theme_constant_override("margin_left", 38)
	$SafeArea/Columns/IntroPanel/Inset.add_theme_constant_override("margin_top", 34)
	$SafeArea/Columns/IntroPanel/Inset.add_theme_constant_override("margin_right", 38)
	$SafeArea/Columns/IntroPanel/Inset.add_theme_constant_override("margin_bottom", 32)
	$SafeArea/Columns/IntroPanel/Inset/Content.add_theme_constant_override("separation", 16)
	$SafeArea/Columns/ActionPanel/Inset.add_theme_constant_override("margin_left", 34)
	$SafeArea/Columns/ActionPanel/Inset.add_theme_constant_override("margin_top", 34)
	$SafeArea/Columns/ActionPanel/Inset.add_theme_constant_override("margin_right", 34)
	$SafeArea/Columns/ActionPanel/Inset.add_theme_constant_override("margin_bottom", 30)
	$SafeArea/Columns/ActionPanel/Inset/Content.add_theme_constant_override("separation", 14)

func _tem_progresso() -> bool:
	if not SaveSystem.tem_save():
		return false
	var descobertas: Variant = SaveSystem.dados.get("descobertas", [])
	return descobertas is Array and not descobertas.is_empty()

func _atualizar_progresso() -> void:
	progresso.text = "PROGRESSO LOCAL\n%d descoberta(s)   •   %d/%d missões" % [Jogo.total_descobertas(), Missoes.total_concluidas(), Missoes.total_missoes()]

func _on_novo_jogo() -> void:
	_abrir_mundo(false)

func _on_continuar() -> void:
	if not _tem_progresso():
		botao_continuar.disabled = true
		status.text = "Nenhum progresso disponível. Comece uma nova jornada."
		return
	_abrir_mundo(true)

func _abrir_mundo(continuar: bool) -> void:
	if not ResourceLoader.exists(CENA_MUNDO):
		status.text = "O menu está pronto. A cena do mundo ainda está sendo preparada."
		return
	if not continuar:
		SaveSystem.apagar()
	var erro := get_tree().change_scene_to_file(CENA_MUNDO)
	if erro != OK:
		status.text = "Não foi possível abrir o jogo. Tente novamente."
		push_error("MenuPrincipal: falha ao abrir a cena do mundo (%s)." % error_string(erro))

func _on_sair() -> void:
	get_tree().quit()
