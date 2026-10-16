extends Node3D
## TutorialDrone: pista em zigue-zague de treino do drone agricola.
## 10 argolas alternando esquerda/direita e alto/baixo + timer de 90 s.
## Entrada: janela com as teclas -> [Comecar] liga o motor e inicia o timer.
## Esc abre pausa (Continuar / Sair). Fim: vitoria (tempo final) ou tempo
## esgotado (Tentar de novo / Voltar ao mapa). Na saida, o drone volta a
## posicao salva no mapa (o voo aqui nao contamina o save).

const CENA_MAPA := "res://scenes/world/mundo.tscn"
const TEMPO_LIMITE := 90.0
const QTD_ARGOLAS := 10
const Z_ARGOLA_INI := -18.0
const Z_ARGOLA_FIM := -170.0
# Distancia extra entre o arco de chegada e a planta de pulverizacao,
# para nao ficarem coladas no final do percurso.
const DIST_PLANTA_APOS_CHEGADA := 45.0
const ALTURAS := [5.0, 10.5, 5.5, 12.0, 4.5, 9.0, 6.0, 11.0, 5.0, 8.0]
const POS_X := [0.0, -6.0, 6.0, -9.0, 9.0, -6.0, 6.0, -9.0, 9.0, 0.0]
const SPAWN := Vector3(0.0, 1.0, 8.0)
const RAIO_ARGOLA := 4.5

enum Estado { ENTRADA, VOANDO, PAUSA, FIM }

var _estado := Estado.ENTRADA
var _tempo := 0.0
var _indice := 0
var _aneis: Array[Dictionary] = []
var _marcador: MeshInstance3D
var _drone: CharacterBody3D
var _mat_futura: StandardMaterial3D
var _mat_atual: StandardMaterial3D
var _mat_feita: StandardMaterial3D
var _som_argola: AudioStreamPlayer
var _som_vitoria: AudioStreamPlayer
var _som_musica: AudioStreamPlayer

var _ui: CanvasLayer
var _scrim: ColorRect
var _hud_tempo: Label
var _hud_argolas: Label
var _jan_entrada: CenterContainer
var _jan_pausa: CenterContainer
var _jan_fim: CenterContainer
var _fim_titulo: Label
var _fim_texto: Label

var _planta: MeshInstance3D
var _area_planta: Area3D
var _planta_pulverizada := false
var _progresso_pulverizacao := 0.0
var _lbl_pulverizar: Label
var _barra_pulverizar: ProgressBar
var _chegada_area: Area3D
var _chegada_liberada := false


func _ready() -> void:
	_montar_mundo()
	_criar_sons()
	_montar_ui()
	_configurar_musica()
	_drone = $DroneJogador as CharacterBody3D
	# Guarda a posicao do mapa para devolver na saida.
	if not SaveSystem.dados.has("posicao_drone_backup"):
		SaveSystem.dados["posicao_drone_backup"] = SaveSystem.dados.get("posicao_drone", [15.5, 1.0, 3.4])
	_drone.position = SPAWN
	_drone.velocity = Vector3.ZERO
	_drone.set("ligado", false)
	_jan_entrada.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
		if _estado == Estado.VOANDO:
			pausar()
		elif _estado == Estado.PAUSA:
			continuar()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _estado != Estado.VOANDO:
		return
	_tempo += delta
	_hud_tempo.text = _formatar_tempo(maxi(0, int(ceil(TEMPO_LIMITE - _tempo))))
	if _tempo >= TEMPO_LIMITE:
		_perder()
		return
	var t := Time.get_ticks_msec() / 1000.0
	for i in _aneis.size():
		var malha: MeshInstance3D = _aneis[i]["no"]
		if i == _indice:
			var s := 1.0 + 0.06 * sin(t * 5.0)
			malha.scale = Vector3(s, s, s)
		else:
			malha.scale = Vector3.ONE
	if _marcador != null and _indice < _aneis.size():
		var centro: Vector3 = _aneis[_indice]["centro"]
		_marcador.position = centro + Vector3(0.0, 5.6 + 0.4 * sin(t * 3.0), 0.0)

	# Ultima etapa: aguarda pulverizacao da planta apos todas as argolas.
	if _indice >= QTD_ARGOLAS and not _planta_pulverizada:
		if _drone != null and _area_planta != null:
			var distancia := _drone.position.distance_to(_area_planta.global_position)
			if distancia < 8.0:
				# Mostra instrucao de proximidade
				if _lbl_pulverizar != null:
					_lbl_pulverizar.visible = true
					if Input.is_action_pressed("pulverizar"):
						_lbl_pulverizar.text = "Pulverizando... %d%%" % int(_progresso_pulverizacao * 100)
						_lbl_pulverizar.add_theme_color_override("font_color", Color(0, 1, 0))
						# Efeito visual gradual: planta vai clareando enquanto e pulverizada
						_progresso_pulverizacao = minf(_progresso_pulverizacao + delta * 0.5, 1.0)
						if _planta != null:
							var mat := _planta.material_override
							if mat != null:
								# Interpola cor do verde escuro para verde claro
								var c := Color(0.2, 0.6, 0.2).lerp(Color(0.6, 1.0, 0.6), _progresso_pulverizacao)
								mat.albedo_color = c
								mat.emission = c
								mat.emission_energy_multiplier = 0.6 + 0.9 * _progresso_pulverizacao
						if _progresso_pulverizacao >= 1.0:
							_planta_pulverizada = true
							_chegada_liberada = true
							if _lbl_pulverizar != null:
								_lbl_pulverizar.text = "Planta pulverizada! Voe ate a linha de chegada."
								_lbl_pulverizar.add_theme_color_override("font_color", Color(0, 1, 0))
							if _barra_pulverizar != null:
								_barra_pulverizar.visible = false
							_som_vitoria.play()
							# Nao finaliza ainda: so apos atravessar a linha de chegada.
					else:
						_lbl_pulverizar.text = "Aproxime e aperte E para pulverizar"
						_lbl_pulverizar.add_theme_color_override("font_color", Color(1, 1, 0))
				if _barra_pulverizar != null:
					_barra_pulverizar.value = _progresso_pulverizacao
			elif Input.is_action_pressed("pulverizar"):
				# Sem label, ainda assim pulveriza
				_progresso_pulverizacao = minf(_progresso_pulverizacao + delta * 0.5, 1.0)
				if _planta != null:
					var mat := _planta.material_override
					if mat != null:
						var c := Color(0.2, 0.6, 0.2).lerp(Color(0.6, 1.0, 0.6), _progresso_pulverizacao)
						mat.albedo_color = c
						mat.emission = c
						mat.emission_energy_multiplier = 0.6 + 0.9 * _progresso_pulverizacao
				if _progresso_pulverizacao >= 1.0:
					_planta_pulverizada = true
					_chegada_liberada = true
					if _barra_pulverizar != null:
						_barra_pulverizar.visible = false
					_som_vitoria.play()
					# Nao finaliza ainda: so apos atravessar a linha de chegada.
				if _barra_pulverizar != null:
					_barra_pulverizar.value = _progresso_pulverizacao
			else:
				# Longe da planta, esconde instrucao
				if _lbl_pulverizar != null:
					_lbl_pulverizar.visible = false

	# apos pulverizar a planta, o drone deve voar ate a linha de chegada
	elif _planta_pulverizada and _chegada_liberada:
		if _drone != null and _chegada_area != null:
			var distancia_chegada := _drone.position.distance_to(_chegada_area.global_position)
			if distancia_chegada < 12.0:
				if _lbl_pulverizar != null:
					_lbl_pulverizar.visible = true
					_lbl_pulverizar.text = "Atravesse a linha de chegada para finalizar!"
					_lbl_pulverizar.add_theme_color_override("font_color", Color(0, 1, 0))
			else:
				if _lbl_pulverizar != null:
					_lbl_pulverizar.visible = true
					_lbl_pulverizar.text = "Voe ate a linha de chegada (CHEGADA)"
					_lbl_pulverizar.add_theme_color_override("font_color", Color(1, 1, 0))


# ------------------------------------------------------------------
# Fluxo (metodos publicos para botoes e teste).

func comecar() -> void:
	if _estado != Estado.ENTRADA:
		return
	_jan_entrada.visible = false
	_scrim.visible = false
	_drone.set("ligado", true)
	_estado = Estado.VOANDO
	if _som_musica != null and not _som_musica.playing:
		_som_musica.play()


func pausar() -> void:
	if _estado != Estado.VOANDO:
		return
	_estado = Estado.PAUSA
	_congelar_drone(true)
	_jan_pausa.visible = true
	_scrim.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func continuar() -> void:
	if _estado != Estado.PAUSA:
		return
	_jan_pausa.visible = false
	_scrim.visible = false
	_congelar_drone(false)
	_estado = Estado.VOANDO


func tentar_de_novo() -> void:
	_jan_fim.visible = false
	_scrim.visible = false
	_tempo = 0.0
	_indice = 0
	_planta_pulverizada = false
	_chegada_liberada = false
	_chegada_area = null
	_progresso_pulverizacao = 0.0
	if _planta != null:
		var mat := _planta.material_override
		if mat != null:
			mat.albedo_color = Color(0.2, 0.6, 0.2)
			mat.emission = Color(0.2, 0.6, 0.2)
			mat.emission_energy_multiplier = 0.6
	if _lbl_pulverizar != null:
		_lbl_pulverizar.visible = false
	if _barra_pulverizar != null:
		_barra_pulverizar.visible = false
		_barra_pulverizar.value = 0.0
	for i in _aneis.size():
		var malha: MeshInstance3D = _aneis[i]["no"]
		malha.material_override = _mat_atual if i == 0 else _mat_futura
		malha.scale = Vector3.ONE
	_hud_argolas.text = "Argolas 0/%d" % QTD_ARGOLAS
	_hud_tempo.text = _formatar_tempo(int(TEMPO_LIMITE))
	_drone.position = SPAWN
	_drone.velocity = Vector3.ZERO
	_drone.set("ligado", true)
	_congelar_drone(false)
	_estado = Estado.VOANDO


func sair_tutorial() -> void:
	SaveSystem.dados["posicao_drone"] = SaveSystem.dados.get("posicao_drone_backup", [15.5, 1.0, 3.4])
	SaveSystem.dados.erase("posicao_drone_backup")
	SaveSystem.salvar()
	get_tree().change_scene_to_file(CENA_MAPA)


# ------------------------------------------------------------------
# Regras.

func _ao_atravessar(corpo: Node3D, i: int) -> void:
	if _estado != Estado.VOANDO:
		return
	if i != _indice:
		return
	if not corpo.is_in_group("drone_jogador"):
		return
	var malha: MeshInstance3D = _aneis[i]["no"]
	malha.material_override = _mat_feita
	malha.scale = Vector3.ONE
	_indice += 1
	_hud_argolas.text = "Argolas %d/%d" % [mini(_indice, QTD_ARGOLAS), QTD_ARGOLAS]
	if _indice >= QTD_ARGOLAS:
		if _som_vitoria != null:
			_som_vitoria.play()
		_exigir_pulverizacao()
	else:
		if _som_argola != null:
			_som_argola.play()
		var prox: MeshInstance3D = _aneis[_indice]["no"]
		prox.material_override = _mat_atual


func _ao_atravessar_chegada(corpo: Node3D) -> void:
	if _estado != Estado.VOANDO:
		return
	if not _chegada_liberada:
		return
	if not corpo.is_in_group("drone_jogador"):
		return
	# So finaliza apos pulverizar a planta e atravessar a linha de chegada.
	_vencer()


func _vencer() -> void:
	_estado = Estado.FIM
	SaveSystem.dados["tutorial_drone_concluido"] = true
	SaveSystem.dados["tutorial_drone_visto"] = true
	SaveSystem.salvar()
	_congelar_drone(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fim_titulo.text = "Tutorial concluido!"
	_fim_texto.text = "Voce cruzou as %d argolas em %s." % [QTD_ARGOLAS, _formatar_tempo(int(_tempo))]
	_jan_fim.visible = true
	_scrim.visible = true


func _perder() -> void:
	_estado = Estado.FIM
	_congelar_drone(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fim_titulo.text = "Tempo esgotado!"
	_fim_texto.text = "Voce cruzou %d de %d argolas. Tente de novo." % [mini(_indice, QTD_ARGOLAS), QTD_ARGOLAS]
	_jan_fim.visible = true
	_scrim.visible = true


func _congelar_drone(congelar: bool) -> void:
	if _drone == null:
		return
	_drone.set_physics_process(not congelar)
	_drone.set_process_unhandled_input(not congelar)
	if congelar:
		_drone.velocity = Vector3.ZERO


func _formatar_tempo(seg: int) -> String:
	return "%02d:%02d" % [seg / 60, seg % 60]


# ------------------------------------------------------------------
# Cenario procedural.

func _montar_mundo() -> void:
	_mat_futura = _mat_argola(Color(0.55, 0.42, 0.10), Color(1.0, 0.75, 0.15), 0.4)
	_mat_atual = _mat_argola(Color(0.05, 0.45, 0.55), Color(0.2, 0.95, 1.0), 1.6)
	_mat_feita = _mat_argola(Color(0.08, 0.45, 0.12), Color(0.25, 1.0, 0.35), 1.2)
	_ceu_e_sol()
	_chao()
	_pista()
	for i in QTD_ARGOLAS:
		var z := lerpf(Z_ARGOLA_INI, Z_ARGOLA_FIM, float(i) / float(QTD_ARGOLAS - 1))
		_argola(i, Vector3(POS_X[i % POS_X.size()], ALTURAS[i % ALTURAS.size()], z))
	_arco_chegada()
	_montar_planta()
	_marcador = MeshInstance3D.new()
	var es := SphereMesh.new()
	es.radius = 0.5
	es.height = 1.0
	_marcador.mesh = es
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color(1, 1, 1)
	mmat.emission_enabled = true
	mmat.emission = Color(0.4, 1.0, 1.0)
	mmat.emission_energy_multiplier = 2.0
	mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marcador.material_override = mmat
	_marcador.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marcador)


func _mat_argola(albedo: Color, emissao: Color, energia: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.emission_enabled = true
	m.emission = emissao
	m.emission_energy_multiplier = energia
	return m


## Sons de confirmacao 100% procedurais (sem arquivo externo).
## Argola normal: bipe duplo curto (880 -> 1318 Hz).
## Ultima argola: jingle de vitoria (660 -> 880 -> 1320 Hz).
func _criar_sons() -> void:
	_som_argola = AudioStreamPlayer.new()
	_som_argola.name = "SomArgola"
	_som_argola.stream = _gerar_sequencia([[880.0, 0.12], [1318.5, 0.20]])
	_som_argola.volume_db = -6.0
	if AudioServer.get_bus_index("Efeitos") >= 0:
		_som_argola.bus = "Efeitos"
	add_child(_som_argola)
	_som_vitoria = AudioStreamPlayer.new()
	_som_vitoria.name = "SomVitoria"
	_som_vitoria.stream = _gerar_sequencia([[659.3, 0.14], [880.0, 0.14], [1318.5, 0.30]])
	_som_vitoria.volume_db = -4.0
	if AudioServer.get_bus_index("Efeitos") >= 0:
		_som_vitoria.bus = "Efeitos"
	add_child(_som_vitoria)


## Gera um WAV com notas senoidais em sequencia.
## notas: Array de [frequencia_hz, duracao_seg]. Aplica fade in/out
## curto em cada nota para evitar estalos.
func _gerar_sequencia(notas: Array) -> AudioStreamWAV:
	var taxa := 22050
	var dados := PackedByteArray()
	for nota in notas:
		var freq := float(nota[0])
		var dur := float(nota[1])
		var n := int(taxa * dur)
		var inicio := dados.size()
		dados.resize(inicio + n * 2)
		var fade := mini(400, n / 4)
		for i in n:
			var t := float(i) / float(taxa)
			var env := 1.0
			if i < fade:
				env = float(i) / float(fade)
			elif i >= n - fade:
				env = float(n - 1 - i) / float(fade)
			# Fundamental + harmonico suave para soar como "confirmacao".
			var s := 0.7 * sin(TAU * freq * t) + 0.3 * sin(TAU * freq * 2.0 * t)
			dados.encode_s16(inicio + i * 2, int(clampf(s * env * 0.6, -1.0, 1.0) * 32760.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = taxa
	wav.stereo = false
	wav.data = dados
	return wav


func _configurar_musica() -> void:
	_som_musica = AudioStreamPlayer.new()
	_som_musica.name = "SomMusica"
	_som_musica.stream = load("res://assets/audio/musicas/Engineered_Ascent.mp3")
	_som_musica.finished.connect(_reiniciar_musica)
	if AudioServer.get_bus_index("Musica") >= 0:
		_som_musica.bus = "Musica"
	# Volume control now handled by AudioConfig bus volume
	_som_musica.volume_db = 0.0  # No additional attenuation from player
	add_child(_som_musica)


func _reiniciar_musica() -> void:
	_som_musica.seek(0)
	_som_musica.play()


func _ceu_e_sol() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var ceu := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.25, 0.5, 0.9)
	mat.sky_horizon_color = Color(0.65, 0.8, 0.95)
	mat.ground_bottom_color = Color(0.2, 0.3, 0.2)
	mat.ground_horizon_color = Color(0.65, 0.8, 0.9)
	ceu.sky_material = mat
	env.sky = ceu
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_depth_begin = 150.0
	env.fog_depth_end = 450.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation = Vector3(-0.9, -0.6, 0.0)
	sol.light_energy = 1.1
	sol.shadow_enabled = true
	add_child(sol)


func _chao() -> void:
	var corpo := StaticBody3D.new()
	corpo.name = "ChaoTutorial"
	add_child(corpo)
	var plano := MeshInstance3D.new()
	var malha := PlaneMesh.new()
	malha.size = Vector2(600, 600)
	plano.mesh = malha
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.46, 0.22)
	plano.material_override = m
	plano.position = Vector3(0, -0.3, -70)
	corpo.add_child(plano)
	var col := CollisionShape3D.new()
	var limite := WorldBoundaryShape3D.new()
	limite.plane = Plane(Vector3.UP, -0.2)
	col.shape = limite
	corpo.add_child(col)


func _caixa(pai: Node3D, nome: String, tamanho: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nome
	var caixa := BoxMesh.new()
	caixa.size = tamanho
	mi.mesh = caixa
	mi.material_override = mat
	mi.position = pos
	pai.add_child(mi)
	return mi


func _pista() -> void:
	var raiz := Node3D.new()
	raiz.name = "Pista"
	add_child(raiz)
	# Pista acompanha o tamanho do percurso (argolas + espaco da chegada + planta).
	var z_ini := 12.0
	var z_fim := Z_ARGOLA_FIM - DIST_PLANTA_APOS_CHEGADA - 20.0
	var comp := z_ini - z_fim
	var z_centro := (z_ini + z_fim) * 0.5
	var asfalto := StandardMaterial3D.new()
	asfalto.albedo_color = Color(0.16, 0.17, 0.2)
	_caixa(raiz, "Base", Vector3(24, 0.4, comp), Vector3(0, -0.2, z_centro), asfalto)
	var corpo := StaticBody3D.new()
	corpo.name = "ColisaoPista"
	raiz.add_child(corpo)
	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(24, 0.4, comp)
	col.shape = forma
	col.position = Vector3(0, -0.2, z_centro)
	corpo.add_child(col)
	var borda := StandardMaterial3D.new()
	borda.albedo_color = Color(0.1, 0.8, 0.9)
	borda.emission_enabled = true
	borda.emission = Color(0.1, 0.8, 0.9)
	borda.emission_energy_multiplier = 1.5
	_caixa(raiz, "BordaEsq", Vector3(0.3, 0.08, comp), Vector3(-11.7, 0.04, z_centro), borda)
	_caixa(raiz, "BordaDir", Vector3(0.3, 0.08, comp), Vector3(11.7, 0.04, z_centro), borda)
	var faixa := StandardMaterial3D.new()
	faixa.albedo_color = Color(0.9, 0.8, 0.2)
	faixa.emission_enabled = true
	faixa.emission = Color(0.9, 0.8, 0.2)
	faixa.emission_energy_multiplier = 0.6
	var z := 8.0
	while z > z_fim + 4.0:
		_caixa(raiz, "Faixa", Vector3(0.5, 0.06, 3.0), Vector3(0, 0.03, z), faixa)
		z -= 8.0
	var largada := StandardMaterial3D.new()
	largada.albedo_color = Color(0.1, 0.6, 0.2)
	largada.emission_enabled = true
	largada.emission = Color(0.1, 0.7, 0.25)
	largada.emission_energy_multiplier = 0.8
	_caixa(raiz, "Largada", Vector3(9, 0.1, 8), Vector3(0, 0.05, 8), largada)
	var rotulo := Label3D.new()
	rotulo.text = "INICIO"
	rotulo.font_size = 128
	rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rotulo.position = Vector3(0, 3.0, 11.5)
	raiz.add_child(rotulo)


func _argola(i: int, centro: Vector3) -> void:
	var raiz := Node3D.new()
	raiz.name = "Argola%d" % (i + 1)
	raiz.position = centro
	add_child(raiz)
	var toro := TorusMesh.new()
	toro.inner_radius = 3.6
	toro.outer_radius = 4.2
	toro.rings = 48
	toro.ring_segments = 12
	var malha := MeshInstance3D.new()
	malha.name = "Anel"
	malha.mesh = toro
	malha.rotation.x = PI * 0.5
	malha.material_override = _mat_atual if i == 0 else _mat_futura
	raiz.add_child(malha)
	var poste_mat := StandardMaterial3D.new()
	poste_mat.albedo_color = Color(0.2, 0.2, 0.22)
	for lado in [-4.5, 4.5]:
		var poste := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = 0.15
		cil.bottom_radius = 0.15
		cil.height = centro.y
		poste.mesh = cil
		poste.material_override = poste_mat
		poste.position = Vector3(lado, -centro.y * 0.5, 0)
		raiz.add_child(poste)
	var area := Area3D.new()
	area.name = "Alvo"
	var col := CollisionShape3D.new()
	var esf := SphereShape3D.new()
	esf.radius = RAIO_ARGOLA
	col.shape = esf
	area.add_child(col)
	raiz.add_child(area)
	area.body_entered.connect(_ao_atravessar.bind(i))
	_aneis.append({"no": malha, "area": area, "centro": centro})


func _arco_chegada() -> void:
	var raiz := Node3D.new()
	raiz.name = "Chegada"
	# A linha de chegada fica APOS a planta de pulverizacao.
	# O so pode finalizar apos pulverizar a planta e atravessar esse arco.
	raiz.position = Vector3(0, 0, Z_ARGOLA_FIM - DIST_PLANTA_APOS_CHEGADA - 25.0)
	add_child(raiz)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.92, 0.92)
	mat.emission_enabled = true
	mat.emission = Color(1, 1, 1)
	mat.emission_energy_multiplier = 0.7
	_caixa(raiz, "ColEsq", Vector3(0.6, 9, 0.6), Vector3(-5, 4.5, 0), mat)
	_caixa(raiz, "ColDir", Vector3(0.6, 9, 0.6), Vector3(5, 4.5, 0), mat)
	_caixa(raiz, "Topo", Vector3(11, 0.8, 0.8), Vector3(0, 9.2, 0), mat)
	var rotulo := Label3D.new()
	rotulo.text = "CHEGADA"
	rotulo.font_size = 128
	rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rotulo.position = Vector3(0, 11.0, 0)
	raiz.add_child(rotulo)

	# Pista xadrez estilo Mario Kart no chao da linha de chegada
	var quad_sz := 1.2
	var col_preto := StandardMaterial3D.new()
	col_preto.albedo_color = Color(0.15, 0.15, 0.15)
	var col_branco := StandardMaterial3D.new()
	col_branco.albedo_color = Color(0.95, 0.95, 0.95)
	var grid := 6  # quantidade de quadradinhos de cada lado
	var inicio := -grid * quad_sz * 0.5
	for x in range(grid):
		for z in range(grid):
			var eh_preto := (x + z) % 2 == 0
			var quad_mat := col_preto if eh_preto else col_branco
			var q := _caixa(raiz, "Quad%d_%d" % [x, z], Vector3(quad_sz, 0.1, quad_sz), Vector3(inicio + x * quad_sz + quad_sz * 0.5, 0.05, z * quad_sz + quad_sz * 0.5 - grid * quad_sz * 0.5 + quad_sz * 0.5), quad_mat)

	# Area de deteccao da linha de chegada (so funciona apos pulverizar a planta)
	var area := Area3D.new()
	area.name = "AlvoChegada"
	var col := CollisionShape3D.new()
	var esf := SphereShape3D.new()
	esf.radius = 12.0
	col.shape = esf
	area.add_child(col)
	raiz.add_child(area)
	area.body_entered.connect(_ao_atravessar_chegada)
	_chegada_area = area


func _montar_planta() -> void:
	# Planta no ponto de chegada, apos a ultima argola. O drone deve
	# pulverizar para concluir o tutorial.
	var raiz := Node3D.new()
	raiz.name = "Planta"
	raiz.position = Vector3(0, 0, Z_ARGOLA_FIM - DIST_PLANTA_APOS_CHEGADA)
	add_child(raiz)

	# Tronco
	var mat_tronco := StandardMaterial3D.new()
	mat_tronco.albedo_color = Color(0.45, 0.3, 0.2)
	_caixa(raiz, "Tronco", Vector3(0.6, 2.2, 0.6), Vector3(0, 1.1, 0), mat_tronco)

	# Folhagem
	var mat_folhas := StandardMaterial3D.new()
	mat_folhas.albedo_color = Color(0.2, 0.6, 0.2)
	mat_folhas.emission_enabled = true
	mat_folhas.emission = Color(0.2, 0.6, 0.2)
	mat_folhas.emission_energy_multiplier = 0.6
	_planta = MeshInstance3D.new()
	_planta.name = "Folhagem"
	_planta.mesh = SphereMesh.new()
	(_planta.mesh as SphereMesh).radius = 1.8
	_planta.material_override = mat_folhas
	_planta.position = Vector3(0, 3.2, 0)
	raiz.add_child(_planta)

	# Area de deteccao de pulverizacao
	_area_planta = Area3D.new()
	_area_planta.name = "AreaPulverizacao"
	var col := CollisionShape3D.new()
	var esf := SphereShape3D.new()
	esf.radius = 6.0
	col.shape = esf
	_area_planta.add_child(col)
	raiz.add_child(_area_planta)

	# Milho decorativo em cima da area de pulverizacao (no chao)
	var cena_milho := load("res://assets/models/Corn_2.fbx")
	if cena_milho != null:
		var milho: Node = cena_milho.instantiate()
		milho.name = "Milho"
		milho.position = Vector3(0, 0.0, 0)
		raiz.add_child(milho)


func _exigir_pulverizacao() -> void:
	# Mostra instrucao na tela para pulverizar a planta.
	if _lbl_pulverizar == null:
		_lbl_pulverizar = Label.new()
		_lbl_pulverizar.name = "InstrucaoPulverizar"
		_lbl_pulverizar.text = "Pulverize a planta! (E)"
		_lbl_pulverizar.add_theme_font_size_override("font_size", 18)
		_lbl_pulverizar.add_theme_color_override("font_color", Color(1, 1, 0))
		_lbl_pulverizar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lbl_pulverizar.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_lbl_pulverizar.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_lbl_pulverizar.position = Vector2(0, 100)
		_ui.add_child(_lbl_pulverizar)
	_lbl_pulverizar.visible = true

	# Barrinha de progresso da pulverizacao
	if _barra_pulverizar == null:
		_barra_pulverizar = ProgressBar.new()
		_barra_pulverizar.name = "BarraPulverizacao"
		_barra_pulverizar.min_value = 0.0
		_barra_pulverizar.max_value = 1.0
		_barra_pulverizar.value = 0.0
		_barra_pulverizar.custom_minimum_size = Vector2(300, 24)
		_barra_pulverizar.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_barra_pulverizar.position = Vector2(0, 140)
		_ui.add_child(_barra_pulverizar)
	_barra_pulverizar.visible = true
	_barra_pulverizar.value = _progresso_pulverizacao

func _montar_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "UITutorial"
	_ui.layer = 5
	add_child(_ui)
	# Fundo escurecido igual ao do Diario (Tab) / Dialogo do HUD.
	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.color = Color(0.04, 0.07, 0.05, 0.76)
	_ui.add_child(_scrim)
	# Pílulas do topo (tempo + argolas) no padrão AgroUITheme.
	var topo := HBoxContainer.new()
	topo.name = "Topo"
	topo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	topo.position = Vector2(-170, 12)
	topo.custom_minimum_size = Vector2(340, 0)
	topo.alignment = BoxContainer.ALIGNMENT_CENTER
	topo.add_theme_constant_override("separation", 10)
	_ui.add_child(topo)
	_hud_tempo = Label.new()
	_hud_tempo.name = "Tempo"
	var pil_tempo := _pildora_hud(_hud_tempo, 30)
	topo.add_child(pil_tempo)
	_hud_argolas = Label.new()
	_hud_argolas.name = "Argolas"
	var pil_argolas := _pildora_hud(_hud_argolas, 15)
	topo.add_child(pil_argolas)
	_hud_argolas.text = "Argolas 0/%d" % QTD_ARGOLAS
	_hud_tempo.text = _formatar_tempo(int(TEMPO_LIMITE))
	_jan_entrada = _janela("Tutorial do Drone", "TREINAMENTO  •  DRONE AGRICOLA")
	_jan_entrada.name = "JanEntrada"
	(_jan_entrada.get_node("Painel/Inset/Conteudo/Texto") as Label).text = _texto_controles()
	(_jan_entrada.get_node("Painel/Inset/Conteudo/Comecar") as Button).pressed.connect(comecar)
	_jan_pausa = _janela("Pausado", "PAUSADO")
	_jan_pausa.name = "JanPausa"
	(_jan_pausa.get_node("Painel/Inset/Conteudo/Texto") as Label).text = "Respire! O cronometro esta parado."
	(_jan_pausa.get_node("Painel/Inset/Conteudo/Comecar") as Button).text = "Continuar"
	(_jan_pausa.get_node("Painel/Inset/Conteudo/Comecar") as Button).pressed.connect(continuar)
	var sair2 := Button.new()
	sair2.name = "SairTutorial"
	sair2.text = "Sair do tutorial"
	sair2.custom_minimum_size = Vector2(0, 48)
	sair2.pressed.connect(sair_tutorial)
	(_jan_pausa.get_node("Painel/Inset/Conteudo") as VBoxContainer).add_child(sair2)
	AgroUITheme.style_secondary_button(sair2)
	_jan_fim = _janela("Fim", "RESULTADO")
	_jan_fim.name = "JanFim"
	_fim_titulo = (_jan_fim.get_node("Painel/Inset/Conteudo/Titulo") as Label)
	_fim_texto = (_jan_fim.get_node("Painel/Inset/Conteudo/Texto") as Label)
	(_jan_fim.get_node("Painel/Inset/Conteudo/Comecar") as Button).text = "Tentar de novo"
	(_jan_fim.get_node("Painel/Inset/Conteudo/Comecar") as Button).pressed.connect(tentar_de_novo)
	var voltar := Button.new()
	voltar.name = "VoltarMapa"
	voltar.text = "Voltar ao mapa"
	voltar.custom_minimum_size = Vector2(0, 48)
	voltar.pressed.connect(sair_tutorial)
	(_jan_fim.get_node("Painel/Inset/Conteudo") as VBoxContainer).add_child(voltar)
	AgroUITheme.style_secondary_button(voltar)


## Pílula do HUD (tempo / argolas): PanelContainer branco do AgroUITheme.
func _pildora_hud(rotulo: Label, fonte: int) -> PanelContainer:
	var pil := PanelContainer.new()
	AgroUITheme.style_panel(pil)
	rotulo.add_theme_font_size_override("font_size", fonte)
	rotulo.add_theme_color_override("font_color", AgroUITheme.INK)
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pil.add_child(rotulo)
	return pil


func _texto_controles() -> String:
	return "Atravesse as %d argolas em ordem antes do tempo acabar!\n\nW / S — frente e re   •   A / D — lados\nEspaco — subir   •   C — descer\nShift — turbo   •   L — liga/desliga o motor\nMouse — olhar (clique captura a mira)" % QTD_ARGOLAS


## Janela no mesmo padrao do Diario/Dialogo do HUD:
## Scrim + PanelContainer do AgroUITheme, selo pequeno, titulo e
## botao principal verde (secundarios saem brancos via style_*).
func _janela(titulo: String, selo: String) -> CenterContainer:
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.visible = false
	_ui.add_child(centro)
	AgroUITheme.apply_to(centro)
	var painel := PanelContainer.new()
	painel.name = "Painel"
	painel.custom_minimum_size = Vector2(420, 0)
	AgroUITheme.style_panel(painel)
	centro.add_child(painel)
	var margem := MarginContainer.new()
	margem.name = "Inset"
	margem.add_theme_constant_override("margin_left", 20)
	margem.add_theme_constant_override("margin_right", 20)
	margem.add_theme_constant_override("margin_top", 17)
	margem.add_theme_constant_override("margin_bottom", 17)
	painel.add_child(margem)
	var coluna := VBoxContainer.new()
	coluna.name = "Conteudo"
	coluna.add_theme_constant_override("separation", 10)
	margem.add_child(coluna)
	var selo_lbl := Label.new()
	selo_lbl.name = "Selo"
	selo_lbl.text = selo
	selo_lbl.add_theme_font_size_override("font_size", 11)
	selo_lbl.add_theme_color_override("font_color", AgroUITheme.MUTED_INK)
	selo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(selo_lbl)
	var tit := Label.new()
	tit.name = "Titulo"
	tit.text = titulo
	tit.add_theme_font_size_override("font_size", 20)
	tit.add_theme_color_override("font_color", AgroUITheme.INK)
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(tit)
	var texto := Label.new()
	texto.name = "Texto"
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.add_theme_font_size_override("font_size", 13)
	texto.add_theme_color_override("font_color", AgroUITheme.INK)
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(texto)
	var btn := Button.new()
	btn.name = "Comecar"
	btn.text = "Comecar"
	btn.custom_minimum_size = Vector2(0, 54)
	coluna.add_child(btn)
	AgroUITheme.style_primary_button(btn)
	return centro
