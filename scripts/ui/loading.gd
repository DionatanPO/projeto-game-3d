class_name Loading
extends Control
## Tela de loading reutilizavel com spinner circular.
## Uso: `Loading.proxima_cena = "res://..."` e
## `get_tree().change_scene_to_file("res://scenes/ui/menus/loading.tscn")`.
## Ela carrega a proxima cena em thread e mostra o spinner girando.

static var proxima_cena := ""
static var titulo_carga := "Carregando..."

const CENA_SEGURA := "res://scenes/world/mundo.tscn"
# Tempo minimo (em segundos) que a tela de loading fica visível, para nao
# piscar quando o carregamento termina muito rapido (em cache).
const TEMPO_MINIMO := 1.2

@onready var anel: Control = $Rodape/Linha/ColunaAnel/Anel
@onready var rotulo: Label = $Rodape/Linha/Rotulo

var _carregou := false
var _tempo_passado := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	AgroUITheme.apply_to(self)
	if proxima_cena.is_empty():
		proxima_cena = CENA_SEGURA
	rotulo.text = titulo_carga
	ResourceLoader.load_threaded_request(proxima_cena)
	set_process(true)


func _process(_delta: float) -> void:
	_tempo_passado += _delta
	var pronto_visualmente := _tempo_passado >= TEMPO_MINIMO

	var estado := ResourceLoader.load_threaded_get_status(proxima_cena)
	match estado:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# O anel gira sozinho via _process; nao precisa refletir progresso.
			pass
		ResourceLoader.THREAD_LOAD_LOADED:
			# So transiciona apos o tempo minimo de exibicao.
			if not pronto_visualmente:
				return
			var empacotada := ResourceLoader.load_threaded_get(proxima_cena) as PackedScene
			if empacotada == null:
				rotulo.text = "Falha ao carregar. Voltando..."
				await get_tree().create_timer(1.0).timeout
				proxima_cena = ""
				get_tree().change_scene_to_file(CENA_SEGURA)
				return
			var destino := proxima_cena
			proxima_cena = ""
			set_process(false)
			get_tree().change_scene_to_file(destino)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			rotulo.text = "Erro ao carregar o mapa."
			set_process(false)
