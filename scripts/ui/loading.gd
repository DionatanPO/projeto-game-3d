class_name Loading
extends Control
## Tela de loading reutilizavel com progresso circular.
## Uso: `Loading.proxima_cena = "res://..."` e
## `get_tree().change_scene_to_file("res://scenes/ui/menus/loading.tscn")`.
## Ela carrega a proxima cena em thread e mostra o progresso real.

static var proxima_cena := ""
static var titulo_carga := "Carregando..."

const CENA_SEGURA := "res://scenes/world/mundo.tscn"

@onready var anel: Control = $Centro/Coluna/Anel
@onready var rotulo: Label = $Centro/Coluna/Rotulo
@onready var porcentagem: Label = $Centro/Coluna/Porcentagem

var _progresso := [0.0]


func _ready() -> void:
	AgroUITheme.apply_to(self)
	if proxima_cena.is_empty():
		proxima_cena = CENA_SEGURA
	rotulo.text = titulo_carga
	porcentagem.text = "0%"
	anel.definir(0.0)
	ResourceLoader.load_threaded_request(proxima_cena)
	set_process(true)


func _process(_delta: float) -> void:
	var estado := ResourceLoader.load_threaded_get_status(proxima_cena, _progresso)
	match estado:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var p := clampf(float(_progresso[0]), 0.0, 1.0)
			anel.definir(p)
			porcentagem.text = "%d%%" % int(round(p * 100.0))
		ResourceLoader.THREAD_LOAD_LOADED:
			anel.definir(1.0)
			porcentagem.text = "100%"
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
