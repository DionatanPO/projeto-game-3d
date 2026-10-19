extends Control
## Spinner de carregamento: fundo branco com arco verde girando suavemente.
## Gira sozinho no desenho, independente do progresso da cena.

var angulo := 0.0
var velocidade := 2.0
var cor_fundo := Color(1, 1, 1, 1)
var cor_frente := Color(0.18, 0.49, 0.29)
var espessura := 10.0


func _process(_delta: float) -> void:
	angulo = fmod(angulo + _delta * velocidade, TAU)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var raio := minf(size.x, size.y) * 0.5 - espessura * 0.5 - 2.0
	if raio <= 0.0:
		return
	# Fundo branco (circulo completo).
	draw_arc(c, raio, 0.0, TAU, 64, cor_fundo, espessura, true)
	# Frente verde girando.
	var inicio := -PI * 0.5 + angulo
	var fim := inicio + TAU * 0.75
	draw_arc(c, raio, inicio, fim, 64, cor_frente, espessura, true)


## Mantido por compatibilidade; o spinner gira sozinho e nao reflete progresso.
func definir(_v: float) -> void:
	pass
