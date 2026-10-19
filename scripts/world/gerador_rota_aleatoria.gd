@tool
class_name GeradorRotaAleatoria
extends Node3D
## GeradorRotaAleatoria: instancia um CaminhoRota com N pontos
## espalhados aleatoriamente pelo mapa. O CaminhoRota cuida de
## interpolar os pontos, gerar a malha da estrada e limpar a
## vegetacao ao longo do trajeto.
##
## Coloque este nos como filho do Mundo (ou de qualquer Node3D)
## e ative "Gerar Em Ready" para criar a rota automaticamente ao
## iniciar o jogo.

@export_group("Rota")
@export var qtd_pontos := 4
@export var raio_min := 30.0
@export var raio_max := 180.0
@export var distancia_min_entre_pontos := 40.0
@export var tentativas_max := 200
@export var gerar_em_ready := true

@export_group("Aparencia da Estrada")
@export var largura := 6.0
@export var borda_suave := 1.5
@export var altura_offset := 0.07
@export var suavidade := 0.85
@export var resolucao := 0.6
@export var cor_terra := Color(0.44, 0.32, 0.21)

@export_group("Limpeza")
@export var limpar_vegetacao := true
@export var remover_pedras := true

var _rota: CaminhoRota = null

func _ready() -> void:
	if gerar_em_ready:
		gerar_rota_aleatoria()

## Gera (ou regenera) uma rota com pontos aleatorios dentro do mapa.
func gerar_rota_aleatoria() -> void:
	# Remove rota anterior, se houver.
	if _rota != null and is_instance_valid(_rota):
		_rota.queue_free()
		_rota = null

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var rota := CaminhoRota.new()
	rota.name = "CaminhoRotaAleatorio"
	rota.largura = largura
	rota.borda_suave = borda_suave
	rota.altura_offset = altura_offset
	rota.suavidade = suavidade
	rota.resolucao = resolucao
	rota.cor_terra = cor_terra
	rota.limpar_vegetacao = limpar_vegetacao
	rota.remover_pedras = remover_pedras

	# Tenta colocar pontos aleatorios com distancia minima entre eles.
	var pontos: Array[Vector3] = []
	var tentativas := 0
	while pontos.size() < qtd_pontos and tentativas < tentativas_max:
		tentativas += 1
		var angulo := rng.randf_range(0.0, TAU)
		var raio := rng.randf_range(raio_min, raio_max)
		var x := cos(angulo) * raio
		var z := sin(angulo) * raio
		var pos := Vector3(x, 0.0, z)

		# Verifica distancia minima para os pontos ja colocados.
		var muito_proximo := false
		for p in pontos:
			if pos.distance_to(p) < distancia_min_entre_pontos:
				muito_proximo = true
				break
		if muito_proximo:
			continue

		pontos.append(pos)

	if pontos.is_empty():
		push_warning("GeradorRotaAleatoria: Nao foi possivel colocar pontos no mapa.")
		return

	for i in pontos.size():
		var marcador := Marker3D.new()
		marcador.name = "Ponto%d" % (i + 1)
		marcador.position = pontos[i]
		marcador.gizmo_extents = 0.6
		rota.add_child(marcador)

	add_child(rota)
	_rota = rota

	# Forca a geracao imediata da malha (em editor e em tempo de execucao).
	rota.regerar_agora()

	print("GeradorRotaAleatoria: Rota criada com %d pontos." % pontos.size())

## Remove a rota gerada (util para regenerar manualmente).
func remover_rota() -> void:
	if _rota != null and is_instance_valid(_rota):
		_rota.queue_free()
		_rota = null
