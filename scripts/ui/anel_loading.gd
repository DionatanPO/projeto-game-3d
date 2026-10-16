extends Control
## Anel de progresso circular desenhado em codigo (sem textura).
## Use `definir(valor01)` para atualizar.

var valor := 0.0
var cor_fundo := Color(1, 1, 1, 0.15)
var cor_frente := Color(0.18, 0.49, 0.29)
var espessura := 12.0


func definir(v: float) -> void:
	valor = clampf(v, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var raio := minf(size.x, size.y) * 0.5 - espessura * 0.5 - 2.0
	if raio <= 0.0:
		return
	draw_arc(c, raio, 0.0, TAU, 48, cor_fundo, espessura, true)
	var fim := -PI * 0.5 + valor * TAU
	draw_arc(c, raio, -PI * 0.5, fim, 48, cor_frente, espessura, true)
